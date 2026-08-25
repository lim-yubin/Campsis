"""평가셋 로딩 및 검증.

평가셋 품질이 곧 결정 품질이다. 라벨 오류를 조용히 넘기면 잘못된 모델을
고르게 되므로, 로딩 시점에 검증한다.
"""

import json
from pathlib import Path

DATA_DIR = Path(__file__).resolve().parent.parent / "data"
DOCUMENTS = DATA_DIR / "documents.jsonl"
QUERIES = DATA_DIR / "queries.jsonl"

# PRD §9.1 Source.type
VALID_TYPES = {"selected_text", "screenshot", "note", "voice", "file"}


def _read_jsonl(path: Path) -> list[dict]:
    if not path.exists():
        raise SystemExit(f"평가셋 파일이 없다: {path}")

    rows = []
    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("//"):
            continue
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError as exc:
            raise SystemExit(f"{path.name}:{lineno} JSON 파싱 실패: {exc}") from exc
    return rows


def load() -> tuple[list[dict], list[dict]]:
    docs = _read_jsonl(DOCUMENTS)
    queries = _read_jsonl(QUERIES)

    doc_ids = [d["id"] for d in docs]
    duplicates = {i for i in doc_ids if doc_ids.count(i) > 1}
    if duplicates:
        raise SystemExit(f"documents.jsonl 중복 id: {sorted(duplicates)}")

    known = set(doc_ids)
    problems: list[str] = []

    # 순환 참조를 피하려고 지연 임포트한다.
    from . import searchable

    all_fields = searchable.COMPOSITIONS["all"]

    for doc in docs:
        if doc.get("type") not in VALID_TYPES:
            problems.append(f"{doc['id']}: 잘못된 type={doc.get('type')!r}")
        # 모든 필드를 넣어도 비면 본문이 아예 없는 문서다. 검색 대상이 될 수
        # 없으므로 자료 오류로 처리한다.
        if searchable.build(doc, all_fields) is None:
            problems.append(f"{doc['id']}: 본문이 없다 (모든 필드가 비었음)")

    for query in queries:
        relevant = query.get("relevant") or []
        if not relevant:
            problems.append(f"{query['id']}: relevant가 비어 있다")
        missing = [r for r in relevant if r not in known]
        if missing:
            problems.append(f"{query['id']}: 존재하지 않는 문서 참조 {missing}")

    if problems:
        raise SystemExit("평가셋 검증 실패:\n  - " + "\n  - ".join(problems))

    return docs, queries


def gold_map(queries: list[dict]) -> dict[str, set[str]]:
    return {q["id"]: set(q["relevant"]) for q in queries}


def summarize(docs: list[dict], queries: list[dict]) -> str:
    by_type: dict[str, int] = {}
    for doc in docs:
        by_type[doc["type"]] = by_type.get(doc["type"], 0) + 1

    note_count = sum(1 for d in docs if d.get("user_note"))
    spread = ", ".join(f"{k}={v}" for k, v in sorted(by_type.items()))
    return (
        f"documents={len(docs)} ({spread}), user_note 보유={note_count}, "
        f"queries={len(queries)}"
    )
