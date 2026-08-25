"""평가셋 수집 도구.

JSONL을 손으로 편집하면 느리고 틀리기 쉽다. 앱이 아직 없어서(Phase 1에서
Capture를 만든다) 자료를 수동으로 모아야 하므로, 이 과정을 짧게 만든다.

사용:
  # 클립보드 내용을 문서로 추가
  uv run python -m src.collect doc --type selected_text --note "왜 저장했는지"

  # 질문 추가 (어휘 중복을 즉시 경고한다)
  uv run python -m src.collect query "며칠 뒤 떠올릴 말투로" --relevant doc-013

  # 현재 평가셋 상태 점검
  uv run python -m src.collect status
"""

import argparse
import json
import subprocess
import sys
from datetime import datetime, timezone

from . import dataset, quality, searchable


def _clipboard() -> str:
    try:
        out = subprocess.run(
            ["pbpaste"], capture_output=True, text=True, timeout=5, check=True
        )
        return out.stdout
    except (subprocess.SubprocessError, OSError) as exc:
        raise SystemExit(f"클립보드를 읽지 못했다: {exc}") from exc


def _frontmost_app() -> str | None:
    """맨 앞 앱 이름. 권한이 없으면 조용히 None."""
    script = 'tell application "System Events" to get name of first process whose frontmost is true'
    try:
        out = subprocess.run(
            ["osascript", "-e", script],
            capture_output=True,
            text=True,
            timeout=5,
        )
        name = out.stdout.strip()
        return name or None
    except (subprocess.SubprocessError, OSError):
        return None


def _next_id(existing: list[dict], prefix: str) -> str:
    nums = []
    for row in existing:
        rid = row.get("id", "")
        if rid.startswith(prefix):
            tail = rid[len(prefix) :]
            if tail.isdigit():
                nums.append(int(tail))
    return f"{prefix}{max(nums, default=0) + 1:03d}"


def _append(path, record: dict) -> None:
    line = json.dumps(record, ensure_ascii=False)
    with path.open("a", encoding="utf-8") as fh:
        fh.write(line + "\n")


def _now() -> str:
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


BODY_FIELD = {
    "selected_text": "content",
    "note": "content",
    "file": "content",
    "screenshot": "ocr_text",
    "voice": "transcript",
}


def add_doc(args: argparse.Namespace) -> int:
    body = _clipboard() if args.text is None else args.text
    body = body.strip()
    if not body:
        raise SystemExit("본문이 비었다. 클립보드를 확인할 것.")

    docs, _ = dataset.load()
    record = {
        "id": _next_id(docs, "doc-"),
        "type": args.type,
        "content": None,
        "user_note": args.note,
        "application": args.app or (_frontmost_app() if args.auto_app else None),
        "window_title": args.window,
        "url": args.url,
        "captured_at": _now(),
        "summary": None,
        "topics": [],
    }
    record[BODY_FIELD[args.type]] = body

    if args.type == "screenshot":
        print(
            "주의: ocr_text는 Apple Vision이 뽑은 결과를 그대로 넣어야 한다.\n"
            "      손으로 다듬으면 실제보다 성적이 좋게 나온다."
        )

    _append(dataset.DOCUMENTS, record)
    print(f"추가: {record['id']} ({args.type}, {len(body)}자)")

    # 저장 직후 전체를 다시 검증한다. 깨진 줄을 나중에 발견하면 원인 찾기 어렵다.
    docs, queries = dataset.load()
    print(dataset.summarize(docs, queries))
    return 0


def add_query(args: argparse.Namespace) -> int:
    docs, queries = dataset.load()
    known = {d["id"] for d in docs}
    missing = [r for r in args.relevant if r not in known]
    if missing:
        raise SystemExit(f"존재하지 않는 문서: {missing}")

    record = {
        "id": _next_id(queries, "q-"),
        "query": args.query,
        "relevant": args.relevant,
        "note": args.note,
    }

    # 저장하기 전에 어휘 중복을 알려준다. 규칙 위반을 나중에 발견하면
    # 이미 그 질문으로 측정을 돌린 뒤가 된다.
    comp = searchable.COMPOSITIONS["all"]
    text_by_id = {d["id"]: searchable.build(d, comp) or "" for d in docs}
    worst = 0.0
    worst_shared: list[str] = []
    for doc_id in args.relevant:
        ratio, shared = quality.overlap(args.query, text_by_id[doc_id])
        if ratio > worst:
            worst, worst_shared = ratio, shared

    print(f"어휘 중복: {worst:.0%}")
    if worst_shared:
        print(f"겹치는 단어: {', '.join(worst_shared)}")
    if worst >= quality.OVERLAP_WARN:
        print(
            f"\n경고: 중복이 {quality.OVERLAP_WARN:.0%} 이상이다. 이 질문은 단어\n"
            "검색으로도 찾히므로 임베딩 후보를 구분하지 못한다."
        )
        if not args.force:
            print("그대로 추가하려면 --force. 겹치는 단어를 바꾸는 편이 낫다.")
            return 1

    _append(dataset.QUERIES, record)
    print(f"추가: {record['id']}")
    docs, queries = dataset.load()
    print(dataset.summarize(docs, queries))
    return 0


def status(args: argparse.Namespace) -> int:
    docs, queries = dataset.load()
    print(dataset.summarize(docs, queries))

    by_type: dict[str, int] = {}
    for doc in docs:
        by_type[doc["type"]] = by_type.get(doc["type"], 0) + 1

    # README의 종류별 최소 권장치.
    target = {
        "selected_text": 10,
        "screenshot": 5,
        "note": 5,
        "voice": 3,
        "file": 3,
    }
    print(f"\n{'type':<16}{'현재':>6}{'권장':>6}  상태")
    print("-" * 44)
    for name, want in target.items():
        have = by_type.get(name, 0)
        mark = "충족" if have >= want else f"{want - have}건 부족"
        print(f"{name:<16}{have:>6}{want:>6}  {mark}")

    n_q = len(queries)
    print(f"\n질문{n_q:>13}{30:>6}  " + ("충족" if n_q >= 30 else f"{30 - n_q}개 부족"))

    multi = sum(1 for q in queries if len(q["relevant"]) > 1)
    print(f"정답 2개 이상 질문: {multi}개 (근거 수집 능력 측정용, 5개 이상 권장)")

    flagged = quality.check_queries(docs, queries, searchable.COMPOSITIONS["all"])
    print(f"어휘 중복 경고 질문: {len(flagged)}개")

    # 주제가 겹치는 문서가 있어야 모델 차이가 드러난다.
    print(
        "\n참고: 서로 다른 주제의 문서만 모으면 어떤 모델이든 구분해내므로\n"
        "지표가 포화된다. 비슷한 주제의 문서를 여러 건 넣어야 후보 간 차이가\n"
        "드러난다. 헷갈릴 만한 것끼리 모으는 게 핵심이다."
    )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Phase 0 평가셋 수집")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_doc = sub.add_parser("doc", help="클립보드 내용을 문서로 추가")
    p_doc.add_argument(
        "--type", required=True, choices=sorted(dataset.VALID_TYPES)
    )
    p_doc.add_argument("--note", default=None, help="User Note (왜 저장했는지)")
    p_doc.add_argument("--app", default=None)
    p_doc.add_argument("--window", default=None)
    p_doc.add_argument("--url", default=None)
    p_doc.add_argument(
        "--auto-app", action="store_true", help="맨 앞 앱 이름 자동 기록"
    )
    p_doc.add_argument("--text", default=None, help="클립보드 대신 직접 입력")
    p_doc.set_defaults(func=add_doc)

    p_q = sub.add_parser("query", help="질문 추가")
    p_q.add_argument("query")
    p_q.add_argument("--relevant", nargs="+", required=True)
    p_q.add_argument("--note", default=None)
    p_q.add_argument("--force", action="store_true", help="중복 경고 무시")
    p_q.set_defaults(func=add_query)

    p_s = sub.add_parser("status", help="평가셋 진행 상황")
    p_s.set_defaults(func=status)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
