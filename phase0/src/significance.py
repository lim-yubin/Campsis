"""차이가 진짜인지 판정한다.

Phase 0의 핵심 위험은 "평가셋이 작은데 수치 차이를 보고 모델을 확정하는
것"이다. 임베딩은 교체 시 전체 재색인을 유발하므로(PRD §9.5) 잘못 고르면
비용이 크다.

여기서는 두 가지를 계산한다.

1. **신뢰구간** --- 지표의 불확실성 폭. 질문을 재표집(bootstrap)해서 얻는다.
2. **짝지은 비교** --- 두 후보의 차이가 0을 포함하는지. 포함하면 "우열을
   가릴 수 없다"가 정답이며, 순위표 1위를 채택하면 안 된다.

질문마다 같은 문서 집합을 검색하므로 두 모델의 성적은 상관된다. 따라서
독립 표본 검정이 아니라 **짝지은 재표집**을 쓴다. 질문을 뽑을 때 두 모델의
해당 질문 점수를 함께 가져오면 상관이 자동으로 반영된다.
"""

import numpy as np

CONFIDENCE = 0.95
N_BOOT = 10000
# 재현 가능해야 한다. 같은 자료로 두 번 돌렸을 때 결론이 바뀌면 신뢰할 수 없다.
SEED = 20260825

# 통계적으로 검출 가능한 차이와 사용자가 체감하는 차이는 다르다. NDCG
# 0.01 미만의 격차는 표본을 늘려 유의하게 만들 수 있어도 실제 검색 품질
# 차이로 이어지지 않는다. 이 경우 성적이 아닌 다른 기준으로 결정해야 한다.
MEANINGFUL_GAP = 0.01


def _resample_indices(n: int, n_boot: int, rng: np.random.Generator) -> np.ndarray:
    return rng.integers(0, n, size=(n_boot, n))


def confidence_interval(
    values: list[float], n_boot: int = N_BOOT
) -> tuple[float, float, float]:
    """평균과 신뢰구간을 반환한다: (평균, 하한, 상한)."""
    arr = np.asarray(values, dtype=float)
    if arr.size == 0:
        raise ValueError("values가 비어 있다")

    rng = np.random.default_rng(SEED)
    idx = _resample_indices(arr.size, n_boot, rng)
    means = arr[idx].mean(axis=1)
    alpha = (1.0 - CONFIDENCE) / 2.0
    lo, hi = np.quantile(means, [alpha, 1.0 - alpha])
    return float(arr.mean()), float(lo), float(hi)


def paired_compare(
    a_values: list[float], b_values: list[float], n_boot: int = N_BOOT
) -> dict:
    """A와 B의 차이를 짝지어 비교한다.

    a_values[i]와 b_values[i]는 같은 질문의 점수여야 한다.

    반환하는 `p_value`는 "차이의 방향이 뒤집히는 재표집 비율"의 양측
    근사다. 엄밀한 순열검정은 아니지만, 표본이 작을 때 결론을 과신하지
    않게 하는 목적에는 충분하다.
    """
    a = np.asarray(a_values, dtype=float)
    b = np.asarray(b_values, dtype=float)
    if a.shape != b.shape:
        raise ValueError("두 후보의 질문 수가 다르다")

    diff = a - b
    rng = np.random.default_rng(SEED)
    idx = _resample_indices(diff.size, n_boot, rng)
    boot = diff[idx].mean(axis=1)

    alpha = (1.0 - CONFIDENCE) / 2.0
    lo, hi = np.quantile(boot, [alpha, 1.0 - alpha])
    observed = float(diff.mean())

    # 관측된 방향과 반대이거나 정확히 0인 재표집 비율.
    if observed > 0:
        tail = float((boot <= 0).mean())
    elif observed < 0:
        tail = float((boot >= 0).mean())
    else:
        tail = 1.0
    p_value = min(1.0, 2.0 * tail)

    return {
        "diff": observed,
        "lo": float(lo),
        "hi": float(hi),
        # 신뢰구간이 0을 걸치면 우열을 가릴 수 없다.
        "significant": bool(lo > 0 or hi < 0),
        "p_value": p_value,
    }


def queries_to_detect(a_values: list[float], b_values: list[float]) -> int | None:
    """관측된 두 후보의 차이를 유의하게 만들려면 질문이 몇 개 필요한지.

    개별 모델의 신뢰구간 폭이 아니라 **차이**를 기준으로 계산한다. Phase 0의
    결정은 "A가 B보다 나은가"이므로 이쪽이 실제 판단 기준이다. 점수가 1.0
    근처에 포화되면 개별 신뢰구간은 좁아지지만 차이는 여전히 구분되지 않는데,
    개별 폭만 보면 그 함정에 빠진다.

    관측 차이가 유지된다고 가정할 때 신뢰구간이 0을 벗어나는 최소 n이다.
    None은 차이가 0이라 어떤 표본으로도 구분할 수 없다는 뜻이다.
    """
    diff = np.asarray(a_values, dtype=float) - np.asarray(b_values, dtype=float)
    if diff.size < 2:
        return None

    mean = abs(diff.mean())
    sd = diff.std(ddof=1)
    if mean == 0:
        return None
    if sd == 0:
        # 모든 질문에서 일관되게 차이가 난다. 현재 표본으로 충분하다.
        return diff.size
    return int(np.ceil((1.96 * sd / mean) ** 2))


def report(results: dict, queries: list[dict], metric: str = "ndcg@10") -> None:
    """순위표 상위 후보들이 통계적으로 구분되는지 출력한다."""
    import itertools

    from . import metrics as m

    qids = [q["id"] for q in queries]
    gold = {q["id"]: set(q["relevant"]) for q in queries}

    # (모델, 조합)별 질문 단위 점수
    series: dict[tuple[str, str], list[float]] = {}
    for key, payload in results.items():
        pq = m.per_query(payload["rankings"], gold)
        series[key] = [pq[qid][metric] for qid in qids]

    print("\n" + "=" * 78)
    print(f"통계적 타당성 --- {metric}, 부트스트랩 {N_BOOT}회, {int(CONFIDENCE * 100)}% 신뢰구간")
    print("=" * 78)

    print(f"\n{'model / composition':<34}{'평균':>8}{'95% 신뢰구간':>22}{'폭':>8}")
    print("-" * 78)
    ordered = sorted(series.items(), key=lambda kv: -np.mean(kv[1]))
    for (model_key, comp), values in ordered:
        mean, lo, hi = confidence_interval(values)
        label = f"{model_key} / {comp}"
        print(f"{label:<34}{mean:>8.3f}   [{lo:>6.3f}, {hi:>6.3f}]{hi - lo:>10.3f}")

    print(
        f"\n신뢰구간이 넓으면 평균 차이를 믿을 수 없다. 질문 {len(qids)}개 기준이다."
    )

    # 상위 후보끼리 짝지은 비교. 전부 비교하면 읽을 수 없으니 상위 4개만.
    top = [key for key, _ in ordered[:4]]
    if len(top) < 2:
        return

    print(f"\n상위 {len(top)}개 짝지은 비교 (같은 질문끼리 비교)")
    print("-" * 78)
    verdicts: list[bool] = []
    for a_key, b_key in itertools.combinations(top, 2):
        res = paired_compare(series[a_key], series[b_key])
        verdicts.append(res["significant"])
        a_label = f"{a_key[0]}/{a_key[1]}"
        b_label = f"{b_key[0]}/{b_key[1]}"
        mark = "유의" if res["significant"] else "구분 불가"
        print(
            f"{a_label:<26} vs {b_label:<26} "
            f"차이={res['diff']:>+7.3f}  [{res['lo']:>+6.3f}, {res['hi']:>+6.3f}]  "
            f"p={res['p_value']:.3f}  {mark}"
        )

    print("\n" + "-" * 78)
    if not any(verdicts):
        print(
            "상위 후보 중 어느 쌍도 통계적으로 구분되지 않는다.\n"
            "→ 순위표 1위를 채택할 근거가 없다."
        )
    else:
        print("일부 쌍이 구분된다. 아래 필요 질문 수를 함께 확인할 것.")

    # 1위와 2위를 가르는 데 필요한 표본. 이게 실제 결정 기준이다.
    n_now = len(qids)
    print(f"\n1·2위를 가르는 데 필요한 질문 수 (현재 {n_now}개)")
    print("-" * 78)
    first, second = ordered[0][0], ordered[1][0]
    need = queries_to_detect(series[first], series[second])
    gap = float(np.mean(series[first]) - np.mean(series[second]))
    label = f"{first[0]}/{first[1]} vs {second[0]}/{second[1]}"

    if need is None:
        print(f"{label}: 차이가 정확히 0이다. 표본을 늘려도 구분되지 않는다.")
    elif need > 1000:
        print(f"{label}: 차이 {gap:+.3f}를 검출하려면 질문 약 {need:,}개가 필요하다.")
    elif need <= n_now:
        print(f"{label}: 현재 표본으로 검출 가능하다 (추정 {need}개).")
    else:
        print(
            f"{label}: 차이 {gap:+.3f}를 검출하려면 질문 약 {need}개가 필요하다 "
            f"({need - n_now}개 추가)."
        )

    # 검출 가능성과 실질적 의미는 별개다. 이걸 구분하지 않으면 무의미한
    # 격차를 쫓아 표본만 늘리게 된다.
    if abs(gap) < MEANINGFUL_GAP:
        print(
            f"\n다만 격차 {gap:+.3f}는 실질적으로 무의미한 수준이다"
            f"(기준 {MEANINGFUL_GAP:.2f}).\n"
            "표본을 늘려 통계적으로 유의하게 만들 수는 있어도 사용자가\n"
            "체감하는 검색 품질 차이로는 이어지지 않는다.\n"
            "→ 성적이 아닌 다른 기준으로 결정한다: Core ML/ANE 변환 가능성\n"
            "  (PRD §11.5 관문 3), License, 모델 크기, 벡터 차원."
        )
