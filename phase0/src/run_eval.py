"""Phase 0 임베딩 후보 평가 (PRD §25 Phase 0).

목적은 순위표를 만드는 게 아니라 "내 자료에서 어느 모델이 나은가"를 수치로
확인하는 것이다. 공개 벤치마크 성적과 결과가 다르면 내 평가셋을 믿는다.

사용 예:
  uv run python -m src.run_eval
  uv run python -m src.run_eval --models bge-m3 qwen3-emb-0.6b arctic-l-v2
  uv run python -m src.run_eval --compositions all no-note note-x3
  uv run python -m src.run_eval --rerank --top-n 30
"""

import argparse
import sys
import time

import numpy as np

from . import candidates, dataset, metrics, searchable


def _device() -> str:
    import torch

    if torch.backends.mps.is_available():
        return "mps"
    return "cpu"


def _check_prompt(model, cand: candidates.Candidate) -> None:
    """후보가 지정한 prompt가 모델에 실제로 존재하는지 확인한다.

    없는 이름을 넘기면 접두어가 조용히 누락되고 성적만 낮게 나온다. 원인을
    찾기 어려운 종류의 오류라 미리 막는다.
    """
    declared = getattr(model, "prompts", None) or {}
    for name in (cand.query_prompt, cand.doc_prompt):
        if name and name not in declared:
            raise SystemExit(
                f"{cand.key}: 모델에 '{name}' prompt가 없다. "
                f"선언된 prompt: {sorted(declared)}"
            )
    if cand.query_prompt:
        print(f"  query prompt: {declared[cand.query_prompt]!r}", flush=True)
    else:
        print("  query prompt: 없음 (접두어 미사용)", flush=True)


def _encode(
    model, texts: list[str], prompt_name: str | None, is_query: bool
) -> np.ndarray:
    """정규화된 벡터를 반환한다.

    정규화하면 내적이 코사인 유사도와 같아져서 검색이 단순해진다.
    """
    return model.encode(
        texts,
        prompt_name=prompt_name,
        batch_size=8 if is_query else 4,
        normalize_embeddings=True,
        show_progress_bar=False,
        convert_to_numpy=True,
    )


def _rank(query_vecs: np.ndarray, doc_vecs: np.ndarray, doc_ids: list[str], limit: int):
    """질문별로 유사도 내림차순 문서 id 목록을 만든다."""
    scores = query_vecs @ doc_vecs.T
    # argsort는 오름차순이므로 부호를 뒤집는다.
    order = np.argsort(-scores, axis=1)[:, :limit]
    return scores, [[doc_ids[i] for i in row] for row in order]


def evaluate_candidate(
    cand: candidates.Candidate,
    docs: list[dict],
    queries: list[dict],
    comps: list[searchable.Composition],
    device: str,
) -> dict[tuple[str, str], dict]:
    from sentence_transformers import SentenceTransformer

    print(f"\n[{cand.key}] {cand.model_id} 적재 중 (device={device}) ...", flush=True)
    started = time.time()
    model = SentenceTransformer(cand.model_id, device=device, trust_remote_code=True)
    print(f"  적재 {time.time() - started:.1f}s", flush=True)
    _check_prompt(model, cand)

    gold = dataset.gold_map(queries)
    query_texts = [q["query"] for q in queries]
    query_vecs = _encode(model, query_texts, cand.query_prompt, is_query=True)

    results: dict[tuple[str, str], dict] = {}
    for comp in comps:
        doc_ids, doc_texts, excluded = searchable.build_index(docs, comp)
        if not doc_ids:
            print(f"  {comp.name:<14} 색인할 문서가 없다. 건너뛴다.", flush=True)
            continue

        started = time.time()
        doc_vecs = _encode(model, doc_texts, cand.doc_prompt, is_query=False)
        elapsed = time.time() - started

        _, ranked = _rank(query_vecs, doc_vecs, doc_ids, limit=max(metrics.K_VALUES))
        rankings = {q["id"]: r for q, r in zip(queries, ranked)}
        scores = metrics.evaluate_all(rankings, gold)
        scores["_index_sec_per_doc"] = elapsed / len(doc_ids)
        scores["_dim"] = float(doc_vecs.shape[1])
        results[(cand.key, comp.name)] = {
            "scores": scores,
            "rankings": rankings,
            "excluded": excluded,
        }

        line = f"  {comp.name:<14} " + "  ".join(
            f"{m}={scores[m]:.3f}" for m in metrics.HEADLINE
        )
        if excluded:
            # 제외된 문서가 정답이면 그 질문은 애초에 맞힐 수 없다.
            # 수치를 잘못 읽지 않도록 밝혀 둔다.
            line += f"   (문서 {len(excluded)}개 제외)"
        print(line, flush=True)

    del model
    return results


def _print_table(results: dict[tuple[str, str], dict]) -> None:
    print("\n" + "=" * 78)
    print("결과 (높을수록 좋음)")
    print("=" * 78)
    header = f"{'model':<18}{'composition':<14}" + "".join(
        f"{m:>10}" for m in metrics.HEADLINE
    )
    print(header)
    print("-" * 78)

    ordered = sorted(
        results.items(), key=lambda kv: kv[1]["scores"]["ndcg@10"], reverse=True
    )
    for (model_key, comp_name), payload in ordered:
        row = f"{model_key:<18}{comp_name:<14}"
        row += "".join(f"{payload['scores'][m]:>10.3f}" for m in metrics.HEADLINE)
        print(row)

    best_key, best = ordered[0]
    print("-" * 78)
    print(f"최고: {best_key[0]} / {best_key[1]} (ndcg@10={best['scores']['ndcg@10']:.3f})")


def _print_failures(results: dict[tuple[str, str], dict], queries: list[dict]) -> None:
    """최고 조합이 놓친 질문을 보여준다.

    수치보다 이쪽이 유용하다. 모델이 나쁜 건지 평가셋 라벨이 잘못된 건지
    여기서 갈린다.
    """
    best_key = max(results, key=lambda k: results[k]["scores"]["ndcg@10"])
    rankings = results[best_key]["rankings"]
    excluded = set(results[best_key].get("excluded", []))
    by_id = {q["id"]: q for q in queries}

    misses = [
        (qid, ranked)
        for qid, ranked in rankings.items()
        if not metrics.hit_at_k(ranked, set(by_id[qid]["relevant"]), 5)
    ]
    if not misses:
        print(f"\n{best_key[0]}/{best_key[1]}: 상위 5개 안에서 놓친 질문 없음")
        return

    print(f"\n{best_key[0]}/{best_key[1]}가 상위 5개에서 놓친 질문 {len(misses)}개:")
    for qid, ranked in misses:
        query = by_id[qid]
        print(f"  {qid} \"{query['query']}\"")
        print(f"    정답: {query['relevant']}")
        print(f"    실제 상위 5: {ranked[:5]}")
        unreachable = [r for r in query["relevant"] if r in excluded]
        if unreachable:
            print(f"    참고: {unreachable}는 이 조합에서 색인 제외됨 (모델 탓 아님)")


def main() -> int:
    parser = argparse.ArgumentParser(description="Phase 0 임베딩 후보 평가")
    parser.add_argument(
        "--models",
        nargs="+",
        default=candidates.DEFAULT_KEYS,
        help=f"기본값: {' '.join(candidates.DEFAULT_KEYS)}",
    )
    parser.add_argument("--compositions", nargs="+", default=["all"])
    parser.add_argument("--list", action="store_true", help="후보 목록만 출력")
    parser.add_argument("--rerank", action="store_true", help="Reranker 단계 추가")
    parser.add_argument("--top-n", type=int, default=30, help="Reranker 입력 후보 수")
    args = parser.parse_args()

    if args.list:
        print(f"{'key':<18}{'model_id':<45}{'license':<14}관문 3 예상")
        print("-" * 100)
        for cand in candidates.EMBEDDING_CANDIDATES:
            flag = "" if cand.adoptable else "  [채택 불가: License]"
            print(
                f"{cand.key:<18}{cand.model_id:<45}{cand.license:<14}"
                f"{cand.runtime}{flag}"
            )
        print(f"\nReranker: {candidates.RERANKER_MODEL_ID}")
        return 0

    docs, queries = dataset.load()
    print(dataset.summarize(docs, queries))
    if len(queries) < 30:
        print(
            f"\n경고: 질문이 {len(queries)}개뿐이다. 이 수치로 모델을 확정하지 말 것.\n"
            "질문 1개 차이로 지표가 크게 흔들린다. 30개 이상 모은 뒤 판단한다."
        )

    unknown_comps = [c for c in args.compositions if c not in searchable.COMPOSITIONS]
    if unknown_comps:
        print(f"알 수 없는 composition: {unknown_comps}", file=sys.stderr)
        print(f"사용 가능: {sorted(searchable.COMPOSITIONS)}", file=sys.stderr)
        return 2

    cands = candidates.resolve(args.models)
    comps = [searchable.COMPOSITIONS[c] for c in args.compositions]
    device = _device()

    from . import quality

    quality.report(docs, queries, comps[0])

    results: dict[tuple[str, str], dict] = {}

    # BM25 기준선. 임베딩이 이걸 크게 앞서지 못하면 평가셋이 너무 쉽거나
    # 어휘 중복이 많다는 뜻이다. 모델을 고르기 전에 확인해야 한다.
    gold = dataset.gold_map(queries)
    for comp in comps:
        ranked = quality.bm25_rankings(
            docs, queries, comp, limit=max(metrics.K_VALUES)
        )
        _, _, excluded = searchable.build_index(docs, comp)
        results[("bm25", comp.name)] = {
            "scores": metrics.evaluate_all(ranked, gold),
            "rankings": ranked,
            "excluded": excluded,
        }

    for cand in cands:
        if not cand.adoptable:
            print(f"\n참고: {cand.key}는 License 미확인이라 채택 불가. 측정만 한다.")
        results.update(evaluate_candidate(cand, docs, queries, comps, device))

    if not results:
        print("측정된 조합이 없다.", file=sys.stderr)
        return 1

    _print_table(results)
    _print_failures(results, queries)

    if len(results) > 1 or len(queries) >= 2:
        from . import significance

        significance.report(results, queries)

    if args.rerank:
        from .rerank import run_rerank

        run_rerank(results, docs, queries, args.top_n, device)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
