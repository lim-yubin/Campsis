"""Embedding / Reranker 후보 등록부.

PRD §11.5 참조. 각 후보는 3개 관문을 통과해야 채택 가능하다.
  1. 자체 평가셋 성적
  2. 상업 재배포 가능 License
  3. Core ML 또는 MLX Swift 실행 가능

License는 2026-08-25 HuggingFace API로 전수 확인했다(전부 통과). 3번은 이
Python 코드로 검증되지 않는다. `runtime` 필드에 예상 경로를 적어 두되,
성적 1위를 정한 뒤 Swift 트랙에서 실제 변환을 시도해야 확정이다.

프롬프트 관례는 하드코딩하지 않는다. 모델이 `config_sentence_transformers.json`
에 선언한 prompt를 `prompt_name`으로 참조한다. 이걸 틀리면 성적이 부당하게
낮게 나오는데, 모델이 프롬프트를 바꿔도 자동으로 따라가게 하는 편이 안전하다.
"""

from dataclasses import dataclass


@dataclass(frozen=True)
class Candidate:
    key: str
    model_id: str
    license: str
    # 모델이 선언한 prompt 이름. sentence-transformers가 실제 문자열로
    # 치환한다. None이면 접두어 없이 인코딩한다(bge 계열).
    query_prompt: str | None = None
    doc_prompt: str | None = None
    # 관문 3 예상 경로. 실제 변환은 Swift 트랙에서 검증한다.
    runtime: str = ""
    # License가 확인되지 않은 모델은 참고용으로만 측정한다.
    adoptable: bool = True
    notes: str = ""


# 인코더 계열은 Core ML 변환이 현실적이고 ANE에서 돌 수 있다. 임베딩은 모든
# 캡처마다 실행되므로(PRD §11.10 Capture 경로) 배터리에 직접 영향을 준다.
# 디코더 계열은 ANE에 올리기 어려워 MLX/GPU 경로가 된다.
ENCODER = "Core ML / ANE 유망 (인코더)"
DECODER = "MLX 경로 (디코더, ANE 어려움)"


EMBEDDING_CANDIDATES: list[Candidate] = [
    Candidate(
        key="pixie-rune",
        model_id="telepix/PIXIE-Rune-v1.5",
        license="Apache-2.0",
        query_prompt="query",
        runtime=ENCODER,
        notes=(
            "한국어 리트리벌 상위. XLM-RoBERTa 24층/1024dim/6144ctx로 bge-m3 "
            "파생(MIT 기반이라 License 사슬 문제 없음). matryoshka 256 지원."
        ),
    ),
    Candidate(
        key="pixie-spell",
        model_id="telepix/PIXIE-Spell-v1.5-0.6B",
        license="Apache-2.0",
        query_prompt="query",
        runtime=DECODER,
        notes=(
            "공개 성적은 Rune보다 높지만 Qwen3 디코더 28층/40960ctx다. "
            "Core ML/ANE 어려움. 성적 이득이 크면 재검토."
        ),
    ),
    Candidate(
        key="bge-m3",
        model_id="BAAI/bge-m3",
        license="MIT",
        runtime=ENCODER,
        notes="기준선. 접두어 없음. 1024dim, 8192ctx.",
    ),
    Candidate(
        key="bge-m3-ko",
        model_id="dragonkue/BGE-m3-ko",
        license="Apache-2.0",
        runtime=ENCODER,
        notes="bge-m3 한국어 파인튜닝. 접두어 없음.",
    ),
    Candidate(
        key="qwen3-emb-0.6b",
        model_id="Qwen/Qwen3-Embedding-0.6B",
        license="Apache-2.0",
        query_prompt="query",
        runtime=DECODER,
        notes="instruction-aware 대조군. 공개 한국어 성적은 bge-m3보다 낮음.",
    ),
    Candidate(
        key="arctic-l-v2",
        model_id="Snowflake/snowflake-arctic-embed-l-v2.0",
        license="Apache-2.0",
        query_prompt="query",
        runtime=ENCODER,
        notes="다국어 대조군.",
    ),
]


BY_KEY = {c.key: c for c in EMBEDDING_CANDIDATES}

# 기본 실행 대상. 인코더 계열 상위 후보 + 기준선.
# pixie-spell은 아키텍처 제약이 있어 명시적으로 지정할 때만 측정한다.
DEFAULT_KEYS = ["pixie-rune", "bge-m3-ko", "bge-m3"]

RERANKER_MODEL_ID = "Qwen/Qwen3-Reranker-0.6B"  # Apache-2.0
RERANKER_INSTRUCTION = (
    "Given the user's question about their own saved memories, judge whether "
    "the document is relevant."
)


def resolve(keys: list[str]) -> list[Candidate]:
    unknown = [k for k in keys if k not in BY_KEY]
    if unknown:
        raise SystemExit(f"알 수 없는 후보: {unknown}\n사용 가능: {sorted(BY_KEY)}")
    return [BY_KEY[k] for k in keys]
