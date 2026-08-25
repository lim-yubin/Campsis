# Phase 0 --- 검색 모델 선정

PRD §25 Phase 0의 Python 트랙이다. **이 코드는 앱에 들어가지 않는다.**
임베딩 모델을 고르기 위한 일회용 측정 도구다. 결정이 끝나면 결과만 PRD
§28 Decision Log에 남기고 이 디렉터리는 보관용으로 둔다.

## 왜 필요한가

임베딩 모델은 한 번 고르면 되돌리기 어렵다. 바꾸면 저장된 모든 자료의
벡터를 다시 만들어야 하고(PRD §9.5), 사용자 자료가 쌓인 뒤에는 몇 시간이
걸리는 작업이 된다. Generation 모델은 나중에 갈아치울 수 있지만 임베딩은
사실상 한 번의 결정이다.

공개 벤치마크는 참고만 한다. 벤치마크 문서는 위키·뉴스처럼 잘 다듬어진
글이지만, 이 앱이 다루는 건 OCR 오류가 섞인 화면 캡처, 문장 부호 없는
음성 전사문, 한두 줄짜리 메모다. 성격이 다르므로 **내 자료로 직접
측정해야 한다.**

## 실행

```bash
cd phase0
uv sync

# 기본 후보 비교
uv run python -m src.run_eval

# 후보 목록 확인
uv run python -m src.run_eval --list

# 여러 모델, 여러 조합 비교
uv run python -m src.run_eval \
  --models bge-m3 qwen3-emb-0.6b arctic-l-v2 \
  --compositions all no-note note-x3

# Reranker 효과 측정
uv run python -m src.run_eval --rerank --top-n 30
```

평가셋을 모을 때는 이렇게 쓴다.

```bash
# 진행 상황 (종류별 부족분, 질문 수, 어휘 중복 경고)
uv run python -m src.collect status

# 클립보드 내용을 문서로 추가
uv run python -m src.collect doc --type selected_text \
  --note "왜 저장했는지" --auto-app

# 질문 추가 (어휘 중복이 높으면 거부한다)
uv run python -m src.collect query "며칠 뒤 떠올릴 말투로" --relevant doc-013
```

관문 3(Core ML 변환)은 별도로 확인한다.

```bash
uv pip install "coremltools>=9.0"
uv run python -m src.coreml_check --models bge-m3 pixie-rune
uv run python -m src.coreml_check --models bge-m3 --quantize 8
```

첫 실행은 모델을 내려받는다. bge-m3가 약 2.2GB, Qwen3-Embedding-0.6B가
약 1.2GB다. `~/.cache/huggingface`에 쌓이므로 두 번째 실행부터는 빠르다.

Python은 3.13을 쓴다. 3.14.7이 최신 안정 버전이지만
sentence-transformers가 3.14 지원을 아직 명시하지 않았다. 올리려면
`pyproject.toml`의 `requires-python`과 `.python-version`을 바꾸면 된다.

## 가장 중요한 작업: 평가셋 채우기

`data/`에 시드 12건과 질문 13건이 들어 있다. **이 숫자로는 아무것도
결정할 수 없다.** 질문 하나가 맞고 틀리는 것만으로 지표가 0.08씩 움직인다.

목표는 **문서 30~50건, 질문 30건 이상**이다. 며칠에 걸쳐 실제로 쓰면서
모으는 게 맞다. 앉아서 상상으로 만들면 실제 사용 패턴과 어긋난다.

### 헷갈릴 만한 문서를 넣어야 한다

시드 평가셋에서 실제로 확인된 함정이다. 문서 12건이 서로 완전히 다른
주제였더니 어떤 후보든 전부 맞혀서 지표가 1.000에 붙었고, 모델을 구분할
수 없었다.

**서로 비슷한 문서가 여러 건 있어야 후보 간 차이가 드러난다.** 같은 주제를
다룬 문서 3~4건, 같은 앱에서 저장한 문서 여러 건, 비슷한 시기에 저장한
문서를 의도적으로 넣는다. 검색이 어려운 이유는 자료가 많아서가 아니라
비슷한 것들 사이에서 골라야 해서다.

### documents.jsonl 규칙

실제로 저장할 만한 것만 넣는다. 종류를 골고루 섞어야 한다.

| type | 최소 권장 | 왜 필요한가 |
|---|---|---|
| `selected_text` | 10건 | 가장 흔한 경로 |
| `screenshot` | 5건 | `ocr_text`에 오류를 그대로 둘 것 |
| `note` | 5건 | 짧은 글에서 신호가 부족한 경우 |
| `voice` | 3건 | 문장 부호 없는 구어체 |
| `file` | 3건 | 긴 문서 |

`ocr_text`는 **Apple Vision이 실제로 뽑은 결과를 그대로** 넣는다.
`l`을 `I`로 잘못 읽은 것까지 살려둬야 한다. 깨끗하게 손질하면 실제
서비스보다 성적이 좋게 나오고, 그 수치를 믿고 고른 모델이 실제로는 더
나쁠 수 있다.

`summary`와 `topics`는 비워 둔다. Phase 2에서 Apple Foundation Models가
채우는 필드다. 지금 사람이 손으로 채우면 실제보다 좋은 조건이 된다.

### queries.jsonl 규칙

**문서와 겹치는 단어를 되도록 쓰지 않는다.** 이게 핵심이다. 질문에
문서의 단어가 그대로 들어가면 BM25 같은 단어 검색으로도 찾히므로,
임베딩 모델 사이의 차이를 구분하지 못한다.

```
나쁨:  "Accessibility API 샌드박스 제약"     → 단어가 그대로 겹친다
좋음:  "스토어에 못 올리기로 한 까닭이 뭐였지"  → 뜻으로만 찾아야 한다
```

며칠 지난 뒤 실제로 떠올릴 말투로 쓴다. 정확한 표현은 기억나지 않고
"그거 뭐였지" 수준으로 물어보는 게 현실이다. 한국어와 영어를 섞어 쓰는
질문도 반드시 넣는다. PRD §11.8에서 지적한 것처럼 실제 사용에서는 섞여
나온다.

정답이 여러 개인 질문(`q-013` 같은)도 넣는다. 근거를 모아오는 능력은
하나만 찾는 능력과 다르게 측정된다.

## 결과 읽는 법

세 지표를 본다.

- **hit@1** --- 첫 결과가 정답인 비율. 사용자 체감에 가장 가깝다
- **hit@5** --- 상위 5개 안에 정답이 있는 비율. Reranker 도입 여지를 판단
- **ndcg@10** --- 순위 품질 종합. 모델 간 비교용

`hit@5`는 높은데 `hit@1`이 낮으면 임베딩이 후보는 잘 모으지만 순서를
못 잡는 상태다. **Reranker를 넣을 근거가 된다**(PRD §11.6).

**순위표 1위를 그대로 믿지 않는다.** 실행 끝에 나오는 통계 절을 먼저 본다.

- **신뢰구간** --- 질문을 재표집해서 얻은 지표의 불확실성 폭
- **짝지은 비교** --- 두 후보의 차이가 0을 걸치면 "구분 불가"다. 이때
  순위표 1위를 채택할 근거가 없다
- **필요 질문 수** --- 1·2위를 가르려면 몇 개가 더 필요한지

여기서 두 가지를 구분해야 한다. 표본을 늘리면 아주 작은 차이도 통계적으로
유의하게 만들 수 있지만, NDCG 0.01 미만의 격차는 사용자가 체감하지
못한다. 그런 경우 성적으로 결정하지 말고 다른 기준(모델 크기, 양자화
내구성, License)으로 골라야 한다.

**BM25 행이 자동으로 함께 나온다.** 임베딩이 BM25를 크게 앞서지 못하면
평가셋이 너무 쉽거나 어휘 중복이 많다는 뜻이다. 모델을 비교하기 전에 이걸
확인한다. 한국어는 조사 때문에 어절 단위로 자르면 BM25가 부당하게 약해
보이므로 문자 바이그램을 쓴다.

수치보다 중요한 건 **놓친 질문 목록**이다. 놓친 질문을 하나씩 보면 두
가지 중 하나다.

1. 모델이 정말 못 찾는 경우 → 다른 후보를 시도
2. 라벨이 잘못된 경우 → 평가셋을 고친다

2번이 생각보다 많다. 지표를 보고 모델을 바꾸기 전에 반드시 확인한다.

## Composition 실험

같은 자료로 Searchable Text를 어떻게 조립하느냐에 따라 성적이 달라진다.
`--compositions`로 비교한다.

- `all` --- 기준선
- `no-note` --- User Note를 뺀다. `all`보다 많이 떨어지면 사용자 메모가
  강한 신호라는 뜻이고, Capture UI에서 메모 입력을 더 권해야 한다
- `no-context` --- 앱 이름·창 제목·URL을 뺀다. **올라가면** 이 필드들이
  노이즈라는 뜻이다
- `note-only` --- 메모만. 사용자 의도만으로 얼마나 찾히는지 확인
- `note-x3` --- 메모를 3번 반복해 가중치를 준다

여기서 정한 조합은 `embedding_version`에 묶인다(PRD §9.5). 나중에 바꾸면
재색인이 필요하므로 지금 확정해야 한다.

## 후보와 License

`--list`로 확인한다. 후보는 **세 관문을 모두** 통과해야 채택할 수 있다.

1. 내 평가셋 성적
2. 상업 재배포 가능 License
3. Core ML 또는 MLX Swift로 변환 가능

**관문 2는 통과했다.** 2026-08-25에 후보 6종을 HuggingFace API로 전수
확인했고 전부 Apache 2.0 또는 MIT다. PIXIE 계열도 Apache 2.0이며, Rune은
bge-m3(MIT) 파생, Spell은 Qwen3-Embedding(Apache 2.0) 파생이라 라이선스
사슬에 문제가 없다.

**관문 3이 남았고, 이게 성적 1위와 어긋날 수 있다.** `--list`의 마지막
열이 예상 경로다. 인코더 계열은 Core ML 변환이 현실적이라 ANE에서 돌 수
있지만, 디코더 계열(pixie-spell, qwen3-emb-0.6b)은 어렵다. 임베딩은 모든
캡처마다 실행되므로 ANE 실행 여부가 배터리에 직결된다. 공개 성적 1위인
PIXIE-Spell이 여기 걸린다.

관문 3은 이 Python 코드로 검증되지 않는다. 성적 1위를 정한 뒤 Swift
트랙에서 변환을 시도해야 최종 확정이다. 변환이 막히면 2순위로 내려간다.

## 결정 후

`--rerank`까지 돌려 Reranker 이득과 지연을 확인한 뒤, PRD §28의
`O1`(임베딩 모델), `O13`(필드 조합), `O14`(int8 양자화)를 갱신한다. 측정한
수치와 날짜를 함께 남긴다.

관문 2(License)와 관문 3(Core ML 변환)은 이미 통과했다. 인코더 후보 4종이
모두 변환되고 PyTorch와 코사인 일치 0.9998 이상이며, 크기·지연이 사실상
동일하다(PRD §28.3.2). 따라서 최종 결정은 성적이 아니라 **양자화
내구성**에서 갈릴 가능성이 높다. fp16은 1081MB, int8은 542MB인데 int8의
일치가 0.986으로 떨어진다. 이 격차가 검색 품질에 영향을 주는지가 실제
평가셋으로 답해야 할 마지막 질문이다.

## 구조

```
phase0/
├── data/
│   ├── documents.jsonl   저장된 캡처 (PRD §9.1 축약)
│   └── queries.jsonl     질문과 정답 라벨
└── src/
    ├── candidates.py     모델 후보 + 프롬프트 관례 + 관문 3 예상
    ├── dataset.py        로딩 및 라벨 검증
    ├── searchable.py     Searchable Text 조립 (PRD §10)
    ├── metrics.py        hit@k / recall@k / ndcg / mrr
    ├── significance.py   부트스트랩 신뢰구간, 짝지은 비교, 필요 표본
    ├── quality.py        어휘 중복 검사 + BM25 기준선
    ├── collect.py        평가셋 수집 (문서/질문 추가, 진행 상황)
    ├── rerank.py         Qwen3-Reranker 단계
    ├── coreml_check.py   관문 3 --- Core ML 변환·수치 일치·지연
    └── run_eval.py       실행 진입점
```

모델별로 질문 접두어 관례가 다르고, 틀리면 성적이 부당하게 낮게 나온다.
bge 계열은 접두어가 없고, PIXIE-Rune과 arctic은 `query: `, Qwen3 계열과
PIXIE-Spell은 instruction 문장을 쓴다.

접두어를 하드코딩하지 않는다. 모델이 `config_sentence_transformers.json`에
선언한 이름을 `query_prompt`로 참조하면 sentence-transformers가 실제
문자열로 치환한다. 모델이 프롬프트를 바꿔도 따라간다. 선언되지 않은 이름을
넘기면 실행 시점에 오류로 잡히고, 실행 로그에 적용된 접두어가 출력되므로
누락 여부를 눈으로 확인할 수 있다.

후보를 추가할 때는 이렇게 확인한다.

```bash
curl -sL "https://huggingface.co/<model_id>/raw/main/config_sentence_transformers.json"
```
