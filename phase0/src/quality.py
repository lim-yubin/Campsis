"""평가셋 품질 검사.

README의 가장 중요한 규칙을 자동으로 확인한다. 질문에 정답 문서의 단어가
그대로 들어가면 단어 검색으로도 찾히므로 임베딩 후보 간 차이를 구분하지
못한다. 사람이 규칙을 지키려 해도 놓치기 쉬우니 수치로 잡는다.

BM25 기준선도 함께 낸다. 임베딩 후보가 BM25를 크게 앞서지 못하면 평가셋이
너무 쉽다는 신호다.
"""

import math
import re
from collections import Counter

TOKEN = re.compile(r"[0-9A-Za-z_]+|[가-힣]+")
HANGUL = re.compile(r"[가-힣]")

# 검색 신호가 없는 흔한 말. 중복 계산에서 뺀다.
STOPWORDS = {
    "그", "이", "저", "것", "수", "때", "게", "거", "뭐", "뭐였지", "왜",
    "어떻게", "무엇", "누가", "언제", "어디", "했지", "하는", "했던", "한",
    "the", "a", "an", "of", "to", "in", "is", "for", "on", "and", "or",
}


def tokenize(text: str) -> list[str]:
    """한글은 문자 바이그램, 영문/숫자는 어절 단위로 자른다.

    한국어는 조사가 붙어서 어절 단위로만 자르면 "공증"과 "공증만"이 다른
    토큰이 된다. 형태소 분석기 없이 이걸 흡수하는 표준 기법이 문자
    바이그램이다(CJK bigram).

    이 선택이 두 곳에 영향을 준다.
      - 어휘 중복 검사: 조사 차이로 중복을 놓치지 않는다. 과소 추정하면
        경고해야 할 질문을 통과시키므로 위험한 방향이다.
      - BM25 기준선: 어절 단위로만 자르면 BM25가 부당하게 약해지고,
        "임베딩이 BM25를 크게 앞선다"는 결론이 과장된다.
    """
    out: list[str] = []
    for raw in TOKEN.findall(text or ""):
        token = raw.lower()
        if token in STOPWORDS or len(token) < 2:
            continue
        if HANGUL.match(token):
            out.extend(token[i : i + 2] for i in range(len(token) - 1))
        else:
            out.append(token)
    return out


def overlap(query: str, doc_text: str) -> tuple[float, list[str]]:
    """질문 토큰 중 정답 문서에도 나타나는 비율과 그 토큰들.

    비율이 높으면 뜻이 아니라 단어로 찾히는 질문이다.
    """
    q_tokens = set(tokenize(query))
    if not q_tokens:
        return 0.0, []
    d_tokens = set(tokenize(doc_text))
    shared = sorted(q_tokens & d_tokens)
    return len(shared) / len(q_tokens), shared


class BM25:
    """평가셋 난이도 기준선.

    임베딩이 BM25를 못 이기면 그 평가셋으로는 모델을 고를 수 없다.
    """

    def __init__(self, docs: list[list[str]], k1: float = 1.5, b: float = 0.75):
        self.k1 = k1
        self.b = b
        self.docs = docs
        self.n = len(docs)
        self.lengths = [len(d) for d in docs]
        self.avg_len = sum(self.lengths) / self.n if self.n else 0.0
        self.freqs = [Counter(d) for d in docs]

        df: Counter[str] = Counter()
        for doc in docs:
            df.update(set(doc))
        self.idf = {
            term: math.log(1 + (self.n - count + 0.5) / (count + 0.5))
            for term, count in df.items()
        }

    def scores(self, query: list[str]) -> list[float]:
        out = []
        for freq, length in zip(self.freqs, self.lengths):
            score = 0.0
            for term in query:
                if term not in freq:
                    continue
                tf = freq[term]
                denom = tf + self.k1 * (
                    1 - self.b + self.b * length / (self.avg_len or 1)
                )
                score += self.idf.get(term, 0.0) * tf * (self.k1 + 1) / denom
            out.append(score)
        return out


# 이 비율을 넘으면 단어만으로 찾히는 질문으로 본다.
OVERLAP_WARN = 0.5


def check_queries(
    docs: list[dict], queries: list[dict], comp
) -> list[tuple[str, float, list[str]]]:
    """어휘 중복이 높은 질문을 찾는다."""
    from . import searchable

    text_by_id = {
        d["id"]: searchable.build(d, comp) or "" for d in docs
    }

    flagged = []
    for query in queries:
        worst = 0.0
        worst_shared: list[str] = []
        for doc_id in query["relevant"]:
            ratio, shared = overlap(query["query"], text_by_id.get(doc_id, ""))
            if ratio > worst:
                worst, worst_shared = ratio, shared
        if worst >= OVERLAP_WARN:
            flagged.append((query["id"], worst, worst_shared))
    return flagged


def bm25_rankings(
    docs: list[dict], queries: list[dict], comp, limit: int
) -> dict[str, list[str]]:
    from . import searchable

    doc_ids, texts, _ = searchable.build_index(docs, comp)
    engine = BM25([tokenize(t) for t in texts])

    out = {}
    for query in queries:
        scores = engine.scores(tokenize(query["query"]))
        order = sorted(range(len(doc_ids)), key=lambda i: -scores[i])[:limit]
        out[query["id"]] = [doc_ids[i] for i in order]
    return out


def report(docs: list[dict], queries: list[dict], comp) -> None:
    print("\n" + "=" * 78)
    print("평가셋 품질 검사")
    print("=" * 78)

    flagged = check_queries(docs, queries, comp)
    if flagged:
        print(
            f"\n어휘 중복이 높은 질문 {len(flagged)}개 "
            f"(정답 문서와 {int(OVERLAP_WARN * 100)}% 이상 단어 공유)"
        )
        by_id = {q["id"]: q for q in queries}
        for qid, ratio, shared in flagged:
            print(f"  {qid} ({ratio:.0%}) \"{by_id[qid]['query']}\"")
            print(f"    겹치는 단어: {', '.join(shared)}")
        print(
            "\n이런 질문은 단어 검색으로도 찾히므로 임베딩 후보 간 차이를\n"
            "구분하지 못한다. 겹치는 단어를 다른 표현으로 바꿀 것."
        )
    else:
        print(f"\n어휘 중복 {int(OVERLAP_WARN * 100)}% 이상인 질문 없음")
