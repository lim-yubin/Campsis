"""Searchable Text 구성 (PRD §10).

각 필드를 논리적으로 분리해서 저장하고, 조합 방식을 실험으로 조절할 수
있게 한다. User Note는 사용자의 의도를 직접 표현하므로 별도로 다룬다.

`Composition`을 바꿔가며 평가를 재실행하면 어떤 필드가 검색에 실제로
기여하는지 수치로 확인할 수 있다. 이 조합 규칙이 바뀌면 PRD §9.5에 따라
`embedding_version`을 올려야 한다.
"""

from dataclasses import dataclass


@dataclass(frozen=True)
class Composition:
    """Searchable Text에 어떤 필드를 넣을지 결정한다."""

    name: str
    user_note: bool = True
    summary: bool = True
    content: bool = True
    context: bool = True
    # User Note를 반복해 넣어 가중치를 올리는 단순 기법.
    # 임베딩 단계에서 필드별 가중치를 직접 주기 어려울 때의 대안.
    user_note_repeat: int = 1


COMPOSITIONS: dict[str, Composition] = {
    "all": Composition(name="all"),
    # User Note가 정말 강한 신호인지 검증한다.
    "no-note": Composition(name="no-note", user_note=False),
    "note-only": Composition(
        name="note-only", summary=False, content=False, context=False
    ),
    # Context(앱/윈도우/URL)가 신호인지 노이즈인지 검증한다.
    "no-context": Composition(name="no-context", context=False),
    "content-only": Composition(
        name="content-only", user_note=False, summary=False, context=False
    ),
    "note-x3": Composition(name="note-x3", user_note_repeat=3),
}


def _context_lines(doc: dict) -> list[str]:
    parts = [doc.get("application"), doc.get("window_title"), doc.get("url")]
    return [p for p in parts if p]


def _body(doc: dict) -> str | None:
    """본문에 해당하는 필드를 고른다.

    PRD §5.1: Selection이 존재하면 Screenshot/OCR보다 Selected Text를
    우선한다. 여기서도 content가 있으면 content를, 없으면 OCR/전사를 쓴다.
    """
    for key in ("content", "ocr_text", "transcript"):
        value = doc.get(key)
        if value:
            return value
    return None


def build(doc: dict, comp: Composition) -> str | None:
    """Searchable Text를 만든다. 해당 조합으로 만들 게 없으면 None.

    None은 오류가 아니다. 예를 들어 `note-only`는 User Note만 남기지만
    `note`/`voice` 타입은 사용자가 쓴 글 자체가 본문이므로 별도 주석이
    없다. 그런 문서는 이 조합에서 색인 대상에서 빠지고, 그 문서를 정답으로
    갖는 질문은 못 맞히게 된다. 그게 해당 조합의 정직한 손해다.

    문서에 아무 본문도 없는 진짜 자료 오류는 `dataset.load`가 잡는다.
    """
    blocks: list[str] = []

    if comp.user_note and doc.get("user_note"):
        for _ in range(max(1, comp.user_note_repeat)):
            blocks.append(f"[User Note]\n{doc['user_note']}")

    if comp.summary and doc.get("summary"):
        blocks.append(f"[Summary]\n{doc['summary']}")

    if comp.summary and doc.get("topics"):
        blocks.append("[Topics]\n" + ", ".join(doc["topics"]))

    if comp.content:
        body = _body(doc)
        if body:
            blocks.append(f"[Content]\n{body}")

    if comp.context:
        lines = _context_lines(doc)
        if lines:
            blocks.append("[Context]\n" + "\n".join(lines))

    if not blocks:
        return None

    return "\n\n".join(blocks)


def build_index(
    docs: list[dict], comp: Composition
) -> tuple[list[str], list[str], list[str]]:
    """조합을 적용해 색인 대상만 남긴다.

    반환: (문서 id, searchable text, 제외된 문서 id)
    """
    ids: list[str] = []
    texts: list[str] = []
    excluded: list[str] = []

    for doc in docs:
        text = build(doc, comp)
        if text is None:
            excluded.append(doc["id"])
        else:
            ids.append(doc["id"])
            texts.append(text)

    return ids, texts, excluded
