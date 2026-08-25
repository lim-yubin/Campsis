"""Reranker 단계 (PRD §11.6).

임베딩이 뽑아온 Top-N을 교차 인코더가 다시 줄 세운다. 임베딩은 질문과
문서를 따로 보지만 Reranker는 둘을 같이 보므로 정밀도가 높다. 대신 후보
개수만큼 추론해야 해서 느리다. 그래서 Top-N에만 적용한다.

Qwen3-Reranker는 yes/no 토큰의 로그 확률로 점수를 낸다. 일반적인
AutoModelForSequenceClassification 방식이 아니므로 구현이 다르다.
"""

import time

import torch

from . import candidates, dataset, metrics, searchable

PREFIX = (
    "<|im_start|>system\nJudge whether the Document meets the requirements based "
    "on the Query and the Instruct provided. Note that the answer can only be "
    '"yes" or "no".<|im_end|>\n<|im_start|>user\n'
)
SUFFIX = (
    "<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n\n"
)
MAX_LENGTH = 2048


def _build_pair(query: str, doc: str) -> str:
    return (
        f"<Instruct>: {candidates.RERANKER_INSTRUCTION}\n"
        f"<Query>: {query}\n"
        f"<Document>: {doc}"
    )


@torch.no_grad()
def _score_pairs(model, tokenizer, pairs: list[str], yes_id: int, no_id: int, device):
    prefix_ids = tokenizer.encode(PREFIX, add_special_tokens=False)
    suffix_ids = tokenizer.encode(SUFFIX, add_special_tokens=False)
    budget = MAX_LENGTH - len(prefix_ids) - len(suffix_ids)

    encoded = tokenizer(
        pairs, truncation=True, max_length=budget, return_attention_mask=False
    )
    inputs = [prefix_ids + ids + suffix_ids for ids in encoded["input_ids"]]

    scores: list[float] = []
    # 배치를 작게 유지한다. 통합 메모리를 다른 모델과 나눠 쓴다.
    for start in range(0, len(inputs), 4):
        chunk = inputs[start : start + 4]
        padded = tokenizer.pad(
            {"input_ids": chunk}, padding=True, return_tensors="pt"
        ).to(device)
        logits = model(**padded).logits[:, -1, :]
        pair_logits = torch.stack([logits[:, no_id], logits[:, yes_id]], dim=1)
        # yes 확률을 점수로 쓴다.
        probs = torch.nn.functional.log_softmax(pair_logits.float(), dim=1)
        scores.extend(probs[:, 1].exp().tolist())
    return scores


def run_rerank(
    results: dict[tuple[str, str], dict],
    docs: list[dict],
    queries: list[dict],
    top_n: int,
    device: str,
) -> None:
    from transformers import AutoModelForCausalLM, AutoTokenizer

    best_key = max(results, key=lambda k: results[k]["scores"]["ndcg@10"])
    base_rankings = results[best_key]["rankings"]
    comp = searchable.COMPOSITIONS[best_key[1]]

    print("\n" + "=" * 78)
    print(f"Reranker: {candidates.RERANKER_MODEL_ID}")
    print(f"입력: {best_key[0]} / {best_key[1]} 상위 {top_n}개")
    print("=" * 78)

    # 임베딩 단계와 같은 색인을 써야 비교가 성립한다.
    indexed_ids, indexed_texts, _ = searchable.build_index(docs, comp)
    doc_text = dict(zip(indexed_ids, indexed_texts))

    if top_n > len(indexed_ids):
        print(f"참고: 색인 문서가 {len(indexed_ids)}개뿐이라 top-n을 줄인다.")
        top_n = len(indexed_ids)

    tokenizer = AutoTokenizer.from_pretrained(
        candidates.RERANKER_MODEL_ID, padding_side="left"
    )
    model = AutoModelForCausalLM.from_pretrained(
        candidates.RERANKER_MODEL_ID, dtype=torch.float16
    ).to(device).eval()

    yes_id = tokenizer.convert_tokens_to_ids("yes")
    no_id = tokenizer.convert_tokens_to_ids("no")

    reranked: dict[str, list[str]] = {}
    started = time.time()

    for query in queries:
        # base_rankings는 K_VALUES 최대치까지만 담고 있다. top_n이 그보다
        # 크면 색인된 나머지 문서로 채운다.
        pool = base_rankings[query["id"]][:top_n]
        if len(pool) < top_n:
            seen = set(pool)
            pool = pool + [i for i in indexed_ids if i not in seen][
                : top_n - len(pool)
            ]

        pairs = [_build_pair(query["query"], doc_text[doc_id]) for doc_id in pool]
        scores = _score_pairs(model, tokenizer, pairs, yes_id, no_id, device)
        ranked = [
            doc_id
            for doc_id, _ in sorted(zip(pool, scores), key=lambda p: -p[1])
        ]
        reranked[query["id"]] = ranked

    elapsed = time.time() - started
    gold = dataset.gold_map(queries)
    after = metrics.evaluate_all(reranked, gold)
    before = results[best_key]["scores"]

    print(f"\n{'지표':<12}{'임베딩만':>12}{'+Reranker':>12}{'차이':>10}")
    print("-" * 46)
    for name in metrics.HEADLINE:
        delta = after[name] - before[name]
        print(
            f"{name:<12}{before[name]:>12.3f}{after[name]:>12.3f}{delta:>+10.3f}"
        )

    per_query = elapsed / len(queries)
    per_pair = per_query / top_n
    print(f"\n질문당 {per_query * 1000:.0f}ms (후보 {top_n}개, device={device})")
    print(f"후보 1개당 {per_pair * 1000:.0f}ms → 후보 50개면 {per_pair * 50:.1f}s")
    print(
        "PRD §21 목표는 Recall 첫 응답 3초 이내다. 이 수치는 PyTorch/MPS "
        "기준이라 Swift 구현보다 느리지만, 후보 수를 늘릴 때의 비용을 보여준다."
    )
