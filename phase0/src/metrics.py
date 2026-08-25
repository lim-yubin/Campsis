"""검색 품질 지표.

관련성은 이진(relevant / not relevant)으로 다룬다. 평가셋 라벨링 비용을
낮추기 위한 선택이며, 등급 라벨이 필요해지면 gains를 확장한다.
"""

import math


def recall_at_k(ranked_ids: list[str], relevant: set[str], k: int) -> float:
    """상위 k개 안에 들어온 정답의 비율.

    정답이 여러 개인 질문을 고려해 hit 개수를 정답 총수로 나눈다.
    """
    if not relevant:
        return 0.0
    hits = sum(1 for doc_id in ranked_ids[:k] if doc_id in relevant)
    return hits / min(len(relevant), k)


def hit_at_k(ranked_ids: list[str], relevant: set[str], k: int) -> float:
    """상위 k개 안에 정답이 하나라도 있으면 1.

    "사용자가 원하는 걸 찾았는가"에 가장 가까운 지표다.
    """
    return 1.0 if any(doc_id in relevant for doc_id in ranked_ids[:k]) else 0.0


def reciprocal_rank(ranked_ids: list[str], relevant: set[str]) -> float:
    for idx, doc_id in enumerate(ranked_ids, start=1):
        if doc_id in relevant:
            return 1.0 / idx
    return 0.0


def ndcg_at_k(ranked_ids: list[str], relevant: set[str], k: int) -> float:
    dcg = 0.0
    for idx, doc_id in enumerate(ranked_ids[:k], start=1):
        if doc_id in relevant:
            dcg += 1.0 / math.log2(idx + 1)

    ideal_hits = min(len(relevant), k)
    idcg = sum(1.0 / math.log2(i + 1) for i in range(1, ideal_hits + 1))
    return dcg / idcg if idcg else 0.0


K_VALUES = (1, 3, 5, 10)


def per_query(
    rankings: dict[str, list[str]], gold: dict[str, set[str]]
) -> dict[str, dict[str, float]]:
    """질문별 지표를 그대로 남긴다.

    평균만 내면 부트스트랩 재표집을 할 수 없다. 질문 단위 값을 보존해야
    "이 차이가 우연인지"를 계산할 수 있다.
    """
    if not gold:
        raise ValueError("gold가 비어 있다")

    out: dict[str, dict[str, float]] = {}
    for qid, relevant in gold.items():
        ranked = rankings.get(qid, [])
        scores: dict[str, float] = {}
        for k in K_VALUES:
            scores[f"hit@{k}"] = hit_at_k(ranked, relevant, k)
            scores[f"recall@{k}"] = recall_at_k(ranked, relevant, k)
            scores[f"ndcg@{k}"] = ndcg_at_k(ranked, relevant, k)
        scores["mrr"] = reciprocal_rank(ranked, relevant)
        out[qid] = scores
    return out


def evaluate_all(
    rankings: dict[str, list[str]], gold: dict[str, set[str]]
) -> dict[str, float]:
    """질문별 랭킹을 받아 전체 평균 지표를 낸다."""
    scores = per_query(rankings, gold)
    names = next(iter(scores.values())).keys()
    n = len(scores)
    return {
        name: sum(s[name] for s in scores.values()) / n for name in names
    }


# 리포트에 노출할 핵심 지표. 전체를 보면 판단이 흐려진다.
HEADLINE = ("hit@1", "hit@5", "ndcg@10", "mrr")
