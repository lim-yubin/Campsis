# Personal Memory Mac MVP --- PRD

> **Document status:** MVP Draft --- Rev. 2 (2026-08-25)\
> **Platform:** macOS 26+ / Apple Silicon (MacBook-only assumption)\
> **Product direction:** Local-first Personal Context / Memory Layer\
> **Primary UX:** Capture → Remember → Recall\
> **Distribution:** Direct download --- Developer ID + Notarization (not Mac
> App Store)\
> **App Sandbox:** Disabled (see §19)

> **Rev. 2 변경 요약**\
> 단일 Qwen 모델 가정을 5개 Model Role로 분리(§11), Retrieval에 Reranker
> 단계 추가(§11.6, §12.1), Embedding 모델 교체 불가 제약과 재색인 정책
> 명시(§9.5), Platform/Runtime/Distribution 절 신설(§19), 확정·미결 사항을
> Decision Log로 분리(§28).

---

## 1. Product Summary

### 1.1 One-line definition

**Mac에서 보고 있거나 생각하고 있는 정보를 빠르게 저장하고, 나중에
자연어로 질문하여 원본 근거와 함께 다시 찾을 수 있는 Local-first AI
Personal Memory 앱.**

### 1.2 Problem

사용자는 업무와 개인 생활에서 매일 많은 정보를 접하지만 모두 기억할 수
없다.

대표적인 상황:

- Slack, 웹페이지, 문서에서 나중에 참고하고 싶은 내용을 발견한다.
- Cursor/IDE, Terminal, GitHub 등에서 중요한 코드·에러·기술 정보를
  본다.
- 화면에 있는 정보를 나중에 다시 찾고 싶지만 어디에서 봤는지 기억하지
  못한다.
- 업무/개인 아이디어가 떠올랐지만 별도로 정리하기 번거롭다.
- 오프라인 대화 직후 기억해둘 내용을 짧게 기록하고 싶다.
- PDF 등의 기존 자료를 넣어두고 나중에 자연어로 질문하고 싶다.

현재 정보는 앱, 파일, 브라우저 기록, 메모 등에 파편화되어 있으며
사용자는 결국 "어디서 봤더라?"를 반복한다.

### 1.3 MVP hypothesis

> 사용자는 나중에 필요할 정보를 단축키로 저장하고, 시간이 지난 후 자연어
> 질문으로 실제로 다시 찾아 활용할 것이다.

MVP는 이 가설 하나를 검증한다.

---

## 2. Product Principles

### 2.1 Capture must be frictionless

사용자가 저장 시점에 폴더, 태그, 프로젝트, Memory Type 등을 일일이
선택하게 하지 않는다.

핵심 mental model:

- **Remember Current Context:** 지금 보고 있는 것을 기억
- **Quick Memory:** 지금 생각하고 있는 것을 기억
- **File Import:** 이미 존재하는 자료를 기억

### 2.2 Local-first

MVP의 기본 데이터와 AI 처리는 **사용자의 Mac 내부에서** 수행한다.

- OpenAI API Key 불필요
- Claude API Key 불필요
- 기본 Cloud LLM 없음
- 원본 Source는 로컬 저장
- 로컬 LLM 사용 (§11.7)
- 로컬 Embedding 사용 (§11.5)

**추론 서버는 존재하지 않는다.** 모델은 각 사용자 기기에서 실행되며, 서버
측 GPU 인스턴스를 두지 않는다. Cloud는 모델 가중치를 배포하는 **정적
CDN** 역할만 담당한다(§19.4).

이 구조의 결과:

- 사용자 Context가 기기를 떠나지 않는다 (제품의 핵심 방어선)
- 사용자당 한계비용이 0에 가깝다 --- 캡처마다 추론이 자동 실행되는
  제품 특성상 서버 추론 모델은 비용 구조가 성립하기 어렵다

### 2.3 Raw source and AI interpretation are separate

원본을 AI 결과로 대체하지 않는다.

예:

```text
Source
├── selected text / screenshot / note / voice / file
├── metadata
└── user note

AI-derived
├── OCR text
├── summary
├── topics
└── embedding
```

AI 분석이 잘못되어도 원본을 다시 확인하거나 재처리할 수 있어야 한다.

### 2.4 Answers require evidence

자연어 답변에는 가능한 한 Source를 함께 표시한다.

사용자는 답변에서 실제 저장한 원문, Screenshot, 파일 등의 근거로 이동할
수 있어야 한다.

### 2.5 Work and personal are not separate products

MVP에서는 회사/개인용 앱을 나누지 않는다. 하나의 사용자가 가진 Personal
Memory로 취급한다.

단, 향후 MCP/외부 앱 연동 시 Context별 접근 권한을 분리할 수 있도록 확장
가능성을 고려한다.

---

## 3. Target User

### 3.1 MVP target

- MacBook을 주 컴퓨터로 사용하는 사용자
- 하루 대부분의 디지털 활동을 Mac에서 수행
- 웹, 메신저, IDE, 문서, PDF 등을 자주 사용
- 나중에 다시 찾아볼 정보가 많음
- AI 기반 자연어 검색에 익숙하거나 관심이 있음

### 3.2 MVP environment assumption

**사용자는 우선 MacBook 한 대만 사용한다고 가정한다.**

MVP에서 제외:

- iPhone 동기화
- Apple Watch
- Android
- Windows
- 여러 Mac 간 동기화
- Cloud account sync

---

## 4. Core User Journey

### Journey A --- Selected Text

1.  사용자가 Chrome/Slack/Cursor/Terminal/PDF 등에서 텍스트를 선택한다.
2.  `Remember Current Context` 단축키를 누른다.
3.  앱이 선택된 텍스트를 감지한다.
4.  앱/Window/URL/시간 등의 Context를 수집한다.
5.  Capture Popup을 표시한다.
6.  사용자는 필요하면 메모를 추가한다.
7.  Remember를 누른다.
8.  Source를 로컬에 저장한다.
9.  Local LLM이 Summary/Topics를 생성한다.
10. Embedding을 생성하고 검색 인덱스에 반영한다.

### Journey B --- Screenshot

1.  사용자가 어떤 화면을 보고 있다.
2.  선택된 텍스트 없이 `Remember Current Context` 단축키를 누른다.
3.  현재 화면을 캡처한다.
4.  Capture Popup에 Screenshot Preview를 표시한다.
5.  사용자는 선택적으로 메모를 입력한다.
6.  Remember를 누른다.
7.  Screenshot 원본을 로컬에 저장한다.
8.  Apple Vision OCR로 텍스트를 추출한다.
9.  Local LLM이 OCR + User Note + Context를 이용해 Summary/Topics를
    생성한다.
10. Embedding을 생성한다.

### Journey C --- Quick Memory

1.  사용자가 `Quick Memory` 단축키를 누른다.
2.  작은 입력창이 표시된다.
3.  사용자가 직접 내용을 작성하거나 Voice Memo를 사용한다.
4.  저장한다.
5.  Local LLM 분석 및 Embedding을 수행한다.

예:

> 방금 민수님과 이야기했는데 목요일까지 API 명세를 전달하기로 했다.

### Journey D --- File Import

1.  사용자가 앱으로 파일을 Drag & Drop하거나 파일 선택을 한다.
2.  원본 파일을 Source로 등록한다.
3.  텍스트를 추출한다.
4.  긴 문서는 Chunking한다.
5.  각 검색 단위의 Embedding을 생성한다.
6.  파일에 대한 Summary/Topics를 생성한다.
7.  이후 자연어 검색 대상에 포함한다.

### Journey E --- Recall

1.  사용자가 앱의 Chat/Search 화면을 연다.
2.  자연어로 질문한다.
3.  질문 Embedding을 생성한다.
4.  Vector Search로 관련 Source/Chunk 후보를 회수한다.
5.  Reranker가 후보를 정밀 재정렬한다.
6.  관련 Context를 Local LLM에 전달한다.
7.  Local LLM이 검색된 근거를 기반으로 답한다.
8.  Source를 함께 표시한다.
9.  사용자가 Source 상세를 열어 원본을 확인한다.

---

## 5. Capture Sources

MVP에서는 다음 5개만 지원한다.

### 5.1 Selected Text

저장 대상:

- 선택된 Text
- Application
- Window Title
- URL (가능한 경우)
- Timestamp
- User Note

Selection이 존재하면 Screenshot/OCR보다 Selected Text를 우선한다.

### 5.2 Screenshot

Selection이 없을 때 `Remember Current Context`를 누르면 현재 화면을
캡처한다.

저장:

- Screenshot 원본
- OCR Text
- Application
- Window Title
- URL
- Timestamp
- User Note

MVP에서는 VLM을 사용하지 않는다.

따라서:

```text
Screenshot
→ Apple Vision OCR
→ Text
→ Local LLM
```

방식으로 처리한다.

### 5.3 Quick Note

사용자가 직접 입력하는 Text Memory.

예:

- 아이디어
- 할 일 메모
- 방금 있었던 대화 요약
- 조사할 내용
- 개인적인 참고 사항

### 5.4 Voice Memo

Quick Memory 화면에서 짧은 음성을 기록할 수 있다.

목적:

- 생각을 타이핑하기 어려운 상황
- 방금 있었던 현실 대화를 빠르게 기록
- 짧은 아이디어 기록

처리:

```text
Audio
→ STT
→ Transcript
→ Local LLM
→ Summary / Topics
→ Embedding
```

**장시간 Meeting Recording은 Voice Memo와 별도 기능이며 MVP에서
제외한다.**

### 5.5 File Upload

MVP 지원 후보:

- PDF
- TXT
- Markdown
- PNG
- JPG

우선순위:

1.  PDF
2.  TXT/Markdown
3.  PNG/JPG

긴 문서는 Chunking 후 검색한다.

---

## 6. Shortcut UX

### 6.1 Default shortcuts

기본값 예시:

Action Default

---

Remember Current Context `⌥ Space`
Quick Memory `⌥ ⇧ Space`

실제 배포 시 macOS/주요 앱과의 충돌 여부를 확인하여 기본값을 최종
결정한다.

### 6.2 Customizable Global Shortcuts

**MVP에 포함한다.**

사용자는 Settings에서 두 Global Shortcut을 직접 변경할 수 있다.

```text
Settings > Shortcuts

Remember Current Context
[ ⌥ Space ]     [Change]

Quick Memory
[ ⌥ ⇧ Space ]   [Change]

[Restore Defaults]
```

요구사항:

- 단축키 입력 UI 제공
- 변경 즉시 Global Hotkey 재등록
- 앱 재시작 후 유지
- Mac 재부팅 후 유지
- 중복 Shortcut 방지
- 시스템/앱 충돌 가능성 안내
- modifier 없는 단일 문자 등록 제한
- Restore Defaults 지원

### 6.3 Remember Current Context behavior

```text
Shortcut
   ↓
Selection 존재?
   ├─ YES → Selected Text Capture
   └─ NO  → Screenshot Capture
```

사용자는 Text/Screenshot 모드를 직접 선택하지 않아도 된다.

### 6.4 Quick Memory behavior

```text
Shortcut
   ↓
Quick Memory Popup
   ├─ Text 입력
   └─ Voice Memo
```

---

## 7. Capture Popup

Selected Text/Screenshot Capture 이후 작은 Popup을 표시한다.

예:

```text
┌─────────────────────────────────────────┐
│ ✦ Remember                              │
│                                         │
│ [Selected Text / Screenshot Preview]    │
│                                         │
│ Chrome · GitHub                         │
│                                         │
│ Memo (optional)                         │
│ ┌─────────────────────────────────────┐ │
│ │ 인증 서버 구현할 때 참고           │ │
│ └─────────────────────────────────────┘ │
│                                         │
│                   Cancel   Remember ↵   │
└─────────────────────────────────────────┘
```

### Requirements

- Capture Preview
- Source App 표시
- User Note 입력
- User Note는 선택사항
- Enter로 빠르게 저장
- Esc로 취소
- Capture 실패 시 명확한 오류 표시

저장을 최대한 방해하지 않는 것이 핵심이다.

---

## 8. User Note

`user_note`는 모든 Source에 선택적으로 붙일 수 있다.

가능 대상:

- Selected Text
- Screenshot
- File
- Voice
- Quick Note

개념:

```text
Raw Context
= 내가 무엇을 봤는가

User Context
= 왜 이것을 기억하려는가
```

예:

```text
OCR:
"Refresh Token Family invalidation ..."

User Note:
"인증 서버 구현할 때 참고"
```

검색 시 User Note는 강한 의미 신호로 활용한다.

---

## 9. Data Model

MVP에서는 복잡한 Knowledge Graph를 만들지 않는다.

### 9.1 Source

예시 스키마:

```text
Source
- id
- type
- content
- screenshot_path
- file_path
- audio_path
- ocr_text
- transcript
- user_note
- application
- window_title
- url
- captured_at
- created_at
- processing_status
```

`type`:

```text
selected_text
screenshot
note
voice
file
```

### 9.2 AI Metadata

```text
SourceAIData
- source_id
- summary
- topics[]
- model
- processed_at
- processing_version
```

### 9.3 Chunk

파일처럼 긴 Source용.

```text
Chunk
- id
- source_id
- sequence
- content
- start_metadata
- end_metadata
```

PDF의 경우 page 정보를 metadata로 유지하는 것을 권장한다.

### 9.4 Embedding

Selected Text/Screenshot/Note/Voice처럼 짧은 Source:

```text
Source → Searchable Text → Embedding
```

긴 File:

```text
File → Chunks → Embedding per Chunk
```

Embedding은 Chunk/Source에 인라인으로 두지 않고 별도 레코드로 분리한다.
모델 교체 시 벡터만 재생성하고 원본을 보존해야 하기 때문이다.

```text
Embedding
- id
- target_type        (source | chunk)
- target_id
- vector
- embedding_model    (예: bge-m3)
- embedding_version  (모델 리비전 + 전처리 규칙 버전)
- dimensions
- created_at
```

### 9.5 Embedding Model Identity (재색인 정책)

**Embedding 모델은 MVP에서 되돌리기 가장 어려운 결정이다.**

이유:

- 서로 다른 임베딩 모델이 생성한 벡터는 **비교 자체가 불가능하다**
- 따라서 기기 성능에 따라 다른 임베딩 모델을 쓰는 구성은 성립하지
  않는다 --- Embedding은 **모든 배포 티어에서 동일해야 한다**(§11.9)
- 모델을 교체하면 저장된 **모든 Source/Chunk를 재색인**해야 한다

요구사항:

- 모든 Embedding 레코드에 `embedding_model`과 `embedding_version`을
  기록한다
- Searchable Text 구성 규칙(§10)이 바뀌면 `embedding_version`을
  올린다 --- 같은 모델이라도 입력 구성이 달라지면 벡터가 달라진다
- 검색 시 현재 활성 모델과 다른 버전의 벡터는 결과에서 제외한다
- 재색인은 **백그라운드 재개 가능한 작업**으로 구현한다. 수천 개
  Source를 가진 사용자에게 앱이 멈춘 것처럼 보이지 않아야 한다
- 재색인 진행률을 사용자에게 표시한다

이 정책이 없으면 모델 업그레이드가 곧 데이터 손실이 된다.

---

## 10. Searchable Text Construction

Embedding 전에 Source별 검색용 Text를 구성한다.

예:

```text
[User Note]
인증 서버 구현할 때 참고

[Summary]
Refresh Token Rotation 구현 방식

[Content]
Refresh Token Family ...

[Context]
Chrome
GitHub
auth-service
```

단, 각 필드의 검색 가중치를 향후 조절할 수 있도록 논리적으로 분리해서
저장한다.

특히 User Note는 사용자의 의도를 직접 표현하므로 높은 가치가 있다.

---

## 11. AI Architecture

### 11.1 Model Roles

**단일 모델이 모든 것을 처리하지 않는다.** 요구사항이 서로 다른 5개
역할로 분리하고, 각 역할의 모델을 독립적으로 교체할 수 있도록 설계한다.

| Role                  | 목적                    | 실행 시점        | 지연 민감도 | 교체 난이도   |
| --------------------- | ----------------------- | ---------------- | ----------- | ------------- |
| OCR                   | Screenshot/Image → Text | Capture          | 낮음        | 낮음          |
| Embedding             | 검색 인덱스 생성        | Capture + Query  | 낮음        | **매우 높음** |
| Reranker              | 검색 후보 재정렬        | Query            | 높음        | 낮음          |
| Generation (Analysis) | Summary / Topics        | Capture (비동기) | 없음        | 낮음          |
| Generation (Answer)   | 근거 기반 답변 생성     | Query            | 높음        | 낮음          |
| STT                   | Voice → Transcript      | Capture          | 중간        | 낮음          |

Embedding만 사실상 되돌릴 수 없다(§9.5). 나머지는 언제든 교체 가능하므로
MVP에서 완벽한 선택을 강요하지 않는다.

### 11.2 Local-first pipeline

```text
Mac
 │
 ├── Apple Vision          → Screenshot / Image OCR
 │
 ├── Embedding Model       → Searchable Text → Vector
 │
 ├── Reranker              → Top-N 후보 정밀 재정렬
 │
 ├── Generation LLM        → Summary / Topics / Answer
 │
 ├── STT                   → Voice Memo Transcript
 │
 └── SQLite + Local Files  → Source / Chunk / Embedding
```

### 11.3 Runtime

**Swift 네이티브로 구현한다. Python 런타임을 앱에 번들하지 않는다.**

근거:

- PyInstaller 등이 생성하는 `Python.framework`는 표준 번들 구조가
  아니어서 `codesign`이 거부한다("bundle format is ambiguous").
  프레임워크 구조를 수동 복구해야 서명이 통과하며, 이 취약한 단계를
  매 릴리스마다 통과해야 한다(§19.3)
- Python 런타임 번들은 앱 크기를 수십 MB에서 수백 MB로 키운다
- 서브프로세스 + IPC 구조는 상주형 메뉴바 앱에서 프로세스 수명과
  메모리를 추적하기 어렵게 만든다

역할별 런타임:

| Role       | Runtime                                      |
| ---------- | -------------------------------------------- |
| OCR        | Apple Vision (native)                        |
| Embedding  | Core ML (ANE 우선) --- 변환 가능성 검증 필요 |
| Reranker   | Core ML 또는 MLX Swift                       |
| Generation | Apple Foundation Models / MLX Swift          |
| STT        | WhisperKit (Core ML)                         |

Python은 **출하되지 않는 평가·실험 스크립트에만** 사용한다(§25 Phase 0).

#### Generation 백엔드 추상화 --- 자체 프로토콜 사용

Apple이 WWDC26에서 `LanguageModel` 프로토콜과 `MLXLanguageModel`을
공개했으나, 이를 이용해 MLX를 `LanguageModelSession`으로 통합하는
`MLXFoundationModels`는 **macOS 27.0 SDK를 요구한다.**

| 기능                                           | macOS 26 | macOS 27 SDK |
| ---------------------------------------------- | -------- | ------------ |
| Apple FM (`SystemLanguageModel`, `@Generable`) | **가능** | 가능         |
| MLX 직접 사용 (`MLXLLM` / `MLXLMCommon`)       | **가능** | 가능         |
| 둘을 `LanguageModelSession`으로 통합           | 불가     | 가능         |

**결정: Apple의 통합 추상화를 사용하지 않고 자체 프로토콜을 정의한다.**

```swift
protocol TextGenerator {
    func analyze(_ text: String) async throws -> Analysis   // Summary + Topics
    func answer(question: String, sources: [Source]) async throws -> String
}

struct AppleFMGenerator: TextGenerator { /* SystemLanguageModel */ }
struct MLXGenerator: TextGenerator     { /* MLXLLM */ }
```

근거:

- Deployment Target을 macOS 26으로 유지할 수 있다. 27을 요구하면 출시
  시점의 사용 가능 기기가 크게 줄어든다
- 구현 비용이 낮다 (프로토콜 + 2개 구현체)
- 추후 타겟을 27로 올리면 Apple 추상화로 이전할 수 있다 --- 이전하지
  않아도 무방하다

#### MLX Swift 의존성

```swift
.package(url: "https://github.com/ml-explore/mlx-swift-lm", .upToNextMajor(from: "3.31.3")),
.package(url: "https://github.com/huggingface/swift-huggingface", from: "0.9.0"),
.package(url: "https://github.com/huggingface/swift-transformers", from: "1.3.0"),
```

연결 products: `MLXLLM`, `MLXLMCommon`, `MLXHuggingFace`

**주의:** 이 패키지의 API는 버전 간 변경이 잦다(모듈명·로드 함수 시그니처
등). 인터넷 예제를 그대로 사용하지 말고 **핀으로 고정한 버전의 README를
기준**으로 삼는다.

간편 로드 API 대신 `LLMModelFactory` + `MLXLMCommon.generate` 스트리밍
경로를 사용한다. 모델 로드/해제 시점을 직접 제어해야 하기
때문이다(§11.10).

### 11.4 OCR --- Apple Vision

Apple Vision의 역할은 **OCR**이다.

```text
Screenshot → OCR Text
```

화면 전체의 의미/레이아웃/이미지 관계를 이해하는 VLM 역할로 사용하지
않는다.

### 11.5 Embedding Model

검색 품질의 상한선을 결정하는 부품이다. 검색이 실패하면 Generation
모델이 아무리 좋아도 복구할 수 없다.

**요구사항**

- Local execution (Apple Silicon)
- 한국어/영어 혼합 검색 성능
- 작은 모델 크기 (상시 상주 가능)
- **상업 재배포 가능한 License** (§19 직접 배포 전제)
- **Core ML 또는 MLX Swift에서 실행 가능** (§11.3)

**후보 및 한국어 리트리벌 성능**

출처: telepix 모델 카드 (NDCG@10, Korean-MTEB-Retrieval-Evaluators 코드베이스).
License는 2026-08-25 HuggingFace API로 전수 확인했다.

| 모델                          | 크기 | 아키텍처     | STELLA(XL) | MTEB(ko) | License    |
| ----------------------------- | ---- | ------------ | ---------- | -------- | ---------- |
| telepix/PIXIE-Spell-v1.5-0.6B | 0.6B | Qwen3 디코더 | 0.6731     | 0.7717   | Apache 2.0 |
| telepix/PIXIE-Rune-v1.5       | 0.5B | XLM-R 인코더 | 0.6559     | 0.7651   | Apache 2.0 |
| BAAI/bge-m3                   | 0.5B | XLM-R 인코더 | 0.5056     | 0.7483   | MIT        |
| Snowflake/arctic-embed-l-v2.0 | 0.5B | XLM-R 인코더 | 0.5448     | 0.7390   | Apache 2.0 |
| Qwen/Qwen3-Embedding-0.6B     | 0.6B | Qwen3 디코더 | 0.4707     | 0.7017   | Apache 2.0 |
| openai/text-embedding-3-large | API  | ---          | N/A        | 0.6646   | 상용 API   |

`dragonkue/BGE-m3-ko`(Apache 2.0)는 위 표에 없으나 후보로 유지한다.

**판단 근거**

- **모든 후보의 License가 확보됐다.** PIXIE 계열도 Apache 2.0이다.
  Rune은 XLM-RoBERTa 24층/1024dim 구성으로 bge-m3(MIT) 파생이고, Spell은
  Qwen3-Embedding(Apache 2.0) 파생이다. 두 사슬 모두 재배포에 문제가 없다
- **벤치마크에 따라 격차가 크게 다르다.** STELLA에서는 PIXIE-Rune이
  bge-m3를 0.15 앞서지만 MTEB(ko)에서는 0.017 차이다. 단일 순위표로
  판단할 수 없다는 뜻이므로 게이트 1이 더 중요해진다
- **성적 1위와 아키텍처 적합성이 어긋난다.** Spell이 성적은 높지만 Qwen3
  디코더(28층, 40960 ctx)라 Core ML/ANE 변환이 어렵다. 임베딩은 모든
  캡처마다 실행되므로(§11.10 Capture 경로) ANE 실행 여부가 배터리에 직접
  영향을 준다. 인코더 계열(Rune, bge-m3, bge-m3-ko, arctic)이 게이트 3에서
  유리하다
- "Qwen으로 통일"은 임베딩에서는 오답이다. Qwen3-Embedding의 8B는
  MTEB 다국어 최상위지만, 0.6B로 내려오면 한국어에서 bge-m3보다
  떨어진다
- OpenAI 최상급 임베딩이 오픈웨이트 0.5B보다 한국어에서 밀린다 ---
  로컬 선택이 품질 타협이 아님을 뒷받침한다

**프롬프트 관례 주의** --- 모델마다 질문 접두어가 다르고 틀리면 성적이
부당하게 낮게 나온다. bge 계열은 접두어가 없고, PIXIE-Rune과 arctic은
`query: `, Qwen3 계열과 PIXIE-Spell은 instruction 문장을 쓴다. 하드코딩하지
말고 모델이 `config_sentence_transformers.json`에 선언한 값을 참조한다.

**확정 절차 (3개 게이트 전부 통과 필요)**

1.  자체 평가셋 성적 (§25 Phase 0) --- 공개 벤치마크는 깨끗한 문서
    기준이며, 본 제품의 데이터는 OCR 노이즈 + 문맥 없는 조각 + 한영
    혼용이다. 성격이 다르다
2.  상업 재배포 가능 License
3.  Core ML 또는 MLX Swift 실행 가능

게이트 3을 평가 단계에 반드시 포함한다. 성적이 좋은 모델을 선택한 뒤에
실행 불가를 발견하면 손실이 크다.

**게이트 2·3은 이미 통과했다**(D16, D18). 인코더 후보 4종이 모두 Core ML로
변환되고 PyTorch와 코사인 일치 0.9998 이상이며, License도 전부 확보됐다.
측정 결과는 §28.3.2다. 남은 것은 게이트 1이며, 그마저도 후보 간 격차가
실질적으로 무의미한 수준으로 나오고 있어 **최종 결정은 성적이 아니라 모델
크기와 양자화 내구성으로 갈릴 가능성이 높다**(O14).

### 11.6 Reranker

**PRD Rev. 1에 없던 부품. 투입 대비 검색 품질 개선이 가장 크다.**

근거: 본 제품의 저장 데이터는 OCR 노이즈, 문맥이 잘린 텍스트 조각, 한영
혼용 기술 용어가 뒤섞여 있어 순수 벡터 유사도만으로는 오탐이 많다.

```text
Embedding으로 Top-N (50~100) 넉넉히 회수
        ↓
Cross-encoder로 정밀 재정렬
        ↓
Top-K (5~10)만 Generation에 전달
```

**후보: Qwen/Qwen3-Reranker-0.6B**

- Context 32K
- 한국어 포함 다국어 지원
- Apache 2.0 (재배포 가능)
- Q6_K 양자화 약 472MB --- 상주 부담 낮음
- MTEB-R 65.80 (동급 BGE-reranker-v2-m3는 57.03)

Reranker는 모든 배포 티어에서 동일하게 적용한다. 교체가 자유로우므로
Embedding과 달리 부담 없이 실험할 수 있다.

### 11.7 Generation

두 역할의 요구사항이 다르므로 분리한다.

#### 11.7.1 Analysis (Summary / Topics)

성격: 캡처마다 백그라운드로 대량 실행, 출력이 구조화 데이터, 지연에 관대.

**1순위: Apple Foundation Models (`SystemLanguageModel`)**

- `@Generable` 매크로로 **출력 타입이 보장된다.** Topics 배열 추출에서
  JSON 파싱 실패가 원천 차단된다 --- 소형 로컬 모델로 구조화 출력을
  뽑을 때 가장 큰 실패 요인이 제거된다
- 모델 다운로드 없음 → 앱 크기 영향 없음, 첫 실행 즉시 동작
- OS가 모델을 전 앱과 공유·관리 → **앱의 상주 메모리 부담 없음**
- 무료, API Key 불필요 → §2.2와 일치

**제약 및 폴백 요건**

- Context 8,192 토큰 → 긴 OCR/Chunk는 분할 필요
- 약 3B 제너럴리스트 → 복잡한 종합 추론에는 부적합
- **가드레일 오탐** --- 임의의 웹 컨텐츠를 저장하는 제품 특성상 요약을
  거부당하는 케이스가 발생할 수 있다. 발생률 실측이 필요하며, 거부 시
  MLX 백엔드로 폴백해야 한다
- Apple Intelligence 지원 기기 필요

#### 11.7.2 Answer Generation

성격: 사용자가 대기 중, 복수 근거 종합, 한국어 자연성, 근거 부족 시 거절
규율(§12.2) 필요.

**1순위: Qwen 3.5 계열 (MLX Swift)**

- 201개 언어 지원, CJK 강점 → **한국어에서 Gemma 4보다 우위**
- Apache 2.0 (재배포 가능)

**대안 검토 대상: Gemma 4 E4B** --- 소형 모델 중 환각률이 가장 낮다.
§12.2의 "근거 없으면 답하지 않기" 정책이 Qwen에서 잘 지켜지지 않을 경우
검토한다.

### 11.8 STT (Voice Memo)

**후보: Whisper large-v3-turbo (WhisperKit / Core ML)**

| 모델                          | 한국어 CER | 속도(RTFx) | 비고                     |
| ----------------------------- | ---------- | ---------- | ------------------------ |
| Whisper large-v3-turbo (809M) | 5.59%      | 13~14×     | 101개 언어, 정확도 우위  |
| SenseVoice Small              | 8.28%      | 52~118×    | CJK 특화, 15× 빠름       |
| Parakeet V3                   | **미지원** | 103~161×   | 한국어 없음 --- **제외** |

판단: Voice Memo는 짧은 메모로 한정되므로(§17) 속도보다 정확도를
우선한다. 30초 메모에서 2초와 5초의 차이는 무의미하다.

**실측이 필요한 항목: 한영 코드 스위칭.** "목요일까지 API 명세를
전달하기로 했다" 같은 문장이 본 제품의 전형적 입력이며, 공개 벤치마크는
이 성능을 알려주지 않는다. Whisper large-v3-turbo와 Qwen3-ASR(코드
스위칭 목표 설계)을 실제 음성으로 비교한다.

### 11.9 Hardware Tier Policy

배포 대상 기기는 8GB\~128GB로 편차가 크다. 기기 메모리를 감지해 티어를
자동 선택한다.

| RAM      | Analysis                | Answer Generation             |
| -------- | ----------------------- | ----------------------------- |
| 8\~15GB  | Apple Foundation Models | Apple Foundation Models       |
| 16\~23GB | Apple Foundation Models | Qwen3.5-4B-4bit (피크 ~5.8GB) |
| 24GB+    | Apple Foundation Models | Qwen3.5-9B-4bit (피크 ~8.7GB) |
| 48GB+    | Apple Foundation Models | Qwen3.5-9B 또는 35B-A3B (MoE) |

**Embedding과 Reranker는 티어와 무관하게 전 기기 동일하다.** Embedding은
벡터 호환성 때문에 티어링이 원리적으로 불가능하다(§9.5).

Apple Foundation Models를 Analysis 기본값으로 두면 하드웨어 티어링
문제의 상당 부분이 사라진다. 저사양 기기도 다운로드 없이 즉시 동작하는
기본 경험을 갖고, 여유 있는 기기만 추가 모델을 받아 답변 품질을 올린다.

#### MLX는 MVP 필수 요소가 아니다

역할별로 보면 MLX가 필요한 곳은 **Answer Generation 하나뿐**이며, 그조차
기본 티어에서는 Apple Foundation Models가 담당한다.

| Role      | Runtime                           | MLX 필요    |
| --------- | --------------------------------- | ----------- |
| OCR       | Apple Vision                      | 아니오      |
| Embedding | Core ML                           | 아니오      |
| Reranker  | Core ML                           | 아니오      |
| Analysis  | Apple Foundation Models           | 아니오      |
| Answer    | Apple FM (기본) / MLX (상위 티어) | 상위 티어만 |
| STT       | WhisperKit                        | 아니오      |

따라서 **MLX 없이 Capture → Recall 루프 전체가 동작하는 MVP를 만들 수
있다.** MLX는 16GB 이상 기기의 답변 품질 업그레이드로 취급하고 Phase 3
이후에 도입한다(§25).

이 순서의 이점:

- Phase 2에서 모델 다운로드, 메모리 관리, JIT entitlement, 로딩 지연이
  모두 발생하지 않는다 --- 파이프라인 자체에만 집중할 수 있다
- Answer 품질이 실제로 부족한지는 Phase 3에서 사용해보고 판단한다.
  미리 도입하면 검증되지 않은 복잡도를 먼저 짊어진다
- Apple FM 가드레일 거부율(§28 O4)을 먼저 측정해야 MLX 폴백의 우선순위를
  정할 수 있다

### 11.10 Model Residency Policy

메뉴바 상주 앱이 대형 모델을 24시간 메모리에 올려두어서는 안 된다.
두 경로의 성격이 다르므로 분리한다.

**Capture Path** --- 상시 동작, 백그라운드

```text
Apple Vision (OS) + Embedding (Core ML / ANE) + Apple FM (OS)
→ 앱 상주 메모리 약 1GB 수준
→ ANE 중심이므로 배터리 부담 최소 (§21 목표와 정합)
```

**Recall Path** --- 사용자가 질문할 때만

```text
Reranker + Generation LLM을 온디맨드 로드, idle 시 해제
→ 첫 질문의 로딩 지연은 §12.1의 "Answer 생성 전 Source 먼저 표시" UX로 가린다
```

### 11.11 VLM

**MVP 제외.**

Screenshot은 OCR → Text → LLM 경로로만 처리한다. 향후 Screenshot 검색
품질에서 실제 문제가 확인될 경우 추가 검토한다.

### 11.12 MVP에서 Generation 모델에 요구하지 않는 것

- 완벽한 Person Graph
- Project Graph
- Task management
- Decision tracking
- Promise tracking
- 복잡한 agent behavior

---

## 12. Retrieval and Q&A

### 12.1 Query flow

```text
User Question
      ↓
Query Embedding
      ↓
Vector Search
      ↓
Top-N Candidates (50~100)
      ↓
Reranker (cross-encoder)          ← §11.6
      ↓
Top-K Sources / Chunks (5~10)
      ↓
[관련 Source 목록을 먼저 화면에 표시]   ← 아래 참조
      ↓
Context Assembly
      ↓
Generation LLM
      ↓
Answer + Sources
```

초기 파라미터 후보:

- Vector Search Top-N: 50\~100개
- Reranker 통과 Top-K: 5\~10개

실사용 품질을 보며 조정한다.

**2단 검색을 쓰는 이유는 §11.6 참조.** 회수(recall)는 임베딩이,
정밀도(precision)는 Reranker가 담당한다.

**Progressive rendering:** Answer 생성 전에 Reranker를 통과한 Source
목록을 먼저 표시한다. 사용자에게 즉각적인 피드백을 주는 동시에, Recall
Path의 모델 온디맨드 로딩 지연(§11.10)을 가리는 역할을 한다.

### 12.2 Answer policy

Generation 모델은 검색된 Source에 기반하여 답변한다.

검색 결과가 충분하지 않은 경우 확신하는 답을 만들지 않고:

> 저장된 Memory에서 충분한 근거를 찾지 못했습니다.

와 같은 형태로 처리할 수 있어야 한다.

### 12.3 Source citation

답변 아래에 Source를 표시한다.

예:

```text
8월 25일 저장한 내용에서는 Refresh Token 만료 기간을
14일로 설정하고 Rotation을 적용하는 방식을 참고했습니다.

Sources
• Slack #payment · Aug 25
• GitHub PR #382 · Aug 21
```

Source 클릭 시 Source Detail로 이동한다.

---

## 13. Source Detail

Source 상세 화면에서 확인할 수 있어야 하는 것:

- 원본 Selected Text
- Screenshot
- File
- Voice Transcript
- User Note
- OCR Text
- AI Summary
- Topics
- Application
- Window Title
- URL
- Captured Time

가능하면 원래 URL을 다시 열 수 있도록 한다.

---

## 14. Main App UI

MVP는 복잡한 Wiki UI보다 검색/Chat 중심으로 구성한다.

### Suggested structure

```text
Sidebar
├── Chat / Search
├── Memories
├── Files
└── Settings
```

### Chat/Search

```text
┌──────────────────────────────────────┐
│ Ask your memory                      │
│                                      │
│ 전에 OAuth 관련해서 저장한 내용?    │
│                                      │
│ [Answer]                             │
│                                      │
│ Sources                              │
│ • ...                                │
│ • ...                                │
│                                      │
│ ──────────────────────────────────── │
│ Ask anything...                      │
└──────────────────────────────────────┘
```

### Memories

시간순으로 저장된 Source를 확인할 수 있다.

필터 후보:

- All
- Text
- Screenshot
- Note
- Voice
- File

고급 분류는 MVP 이후.

---

## 15. Menu Bar App

앱은 백그라운드에서 동작할 수 있어야 한다.

Menu Bar 예:

```text
Personal Memory

Quick Memory
Open Memory
Settings
Quit
```

핵심 Global Shortcut은 앱 창이 닫혀 있어도 동작해야 한다.

---

## 16. File Processing

### PDF

```text
PDF
 ↓
Text extraction
 ↓
Page metadata 유지
 ↓
Chunking
 ↓
Embedding
```

검색 결과가 PDF Chunk라면 해당 페이지 정보를 Source에 표시한다.

### TXT / Markdown

```text
Text
 ↓
Chunking
 ↓
Embedding
```

### PNG / JPG

MVP에서는:

```text
Image
 ↓
Apple Vision OCR
 ↓
Text
 ↓
Local LLM
 ↓
Embedding
```

VLM 분석은 하지 않는다.

---

## 17. Voice Memo

### Scope

짧은 Memo 중심.

예상 UX:

```text
Quick Memory
   ↓
Record
   ↓
● 00:13
   ↓
Stop
   ↓
Transcript Preview
   ↓
Remember
```

STT 모델 후보 및 선정 근거는 §11.8 참조. Voice Memo가 짧은 메모로
한정되므로 속도보다 **정확도와 한영 코드 스위칭 성능**을 우선한다.

### MVP boundary

회의처럼 장시간 음성을 녹음하고:

- Speaker diarization
- 참석자 구분
- Meeting Summary
- Decision 추출
- Action Item 추출

등을 수행하는 기능은 **Meeting Recording**으로 정의하고 MVP에서
제외한다.

---

## 18. Privacy and Security

이 제품은 사용자의 매우 민감한 Context를 저장할 수 있으므로 Privacy는
부가 기능이 아니라 제품 핵심 요구사항이다.

### MVP principles

- 데이터 Local 저장
- AI Local 실행 (추론 서버 없음, §2.2)
- Cloud LLM 기본 사용 안 함
- API Key 요구 안 함
- 필요한 macOS Permission을 명확히 설명
- 사용자가 Source 삭제 가능
- 삭제 시 관련 Chunk/Embedding/파일도 함께 제거
- 앱 제거/데이터 삭제 정책 명확화

### Permissions

기능 구현 방식에 따라 다음 권한이 필요하다. 모두 TCC(Transparency,
Consent, Control) 권한이며 App Sandbox와는 별개 계층이다(§19.1).

| Permission       | 용도                               | 없으면                |
| ---------------- | ---------------------------------- | --------------------- |
| Accessibility    | Selected Text 감지 (Journey A)     | Screenshot으로만 동작 |
| Screen Recording | Screenshot 캡처, Window Title 수집 | Journey B 불가        |
| Microphone       | Voice Memo                         | Voice Memo 불가       |

권한은 실제 기능에 필요한 최소 수준으로, **해당 기능을 처음 쓰는
시점에** 요청한다. 첫 실행에 모든 권한을 한꺼번에 요구하지 않는다.

각 권한이 왜 필요한지 앱 내에서 설명하고, 거부된 경우에도 나머지 기능이
동작해야 한다.

### License 검증 (유료 배포 시)

라이선스 검증은 **오프라인에서 완결되어야 한다.**

- 구매 시 서버가 개인키로 서명한 라이선스 파일을 발급한다
- 앱은 공개키만 내장하고 네트워크 없이 검증한다
- 활성화 시점에만 1회 통신하고, 이후 주기적 서버 확인을 하지 않는다

근거: "데이터가 기기를 떠나지 않는다"를 판매하는 제품이 주기적으로 서버에
접속하면 제품 약속과 모순된다. 이 사용자층은 네트워크 트래픽을 감시한다.

---

## 19. Platform, Runtime and Distribution

### 19.1 App Sandbox --- 비활성화

**App Sandbox를 켜지 않는다.** 이는 개발 편의가 아니라 능력 경계의
문제다.

| 항목                            | Sandbox ON                    | Sandbox OFF         |
| ------------------------------- | ----------------------------- | ------------------- |
| Accessibility API               | **불가**                      | 사용자 승인 후 가능 |
| 다른 앱에 키 이벤트 주입        | 불가                          | 가능                |
| 브라우저 URL 수집 (AppleEvents) | 대상별 예외 entitlement 필요  | 가능                |
| MLX JIT entitlement             | App Store 불승인              | 공증에서 승인       |
| 파일 저장                       | 컨테이너 한정                 | 임의 경로           |
| 사용자 파일 재접근              | security-scoped bookmark 필요 | 일반 경로           |
| Notarization                    | 가능                          | **가능**            |

핵심 근거: Apple 개발자 포럼에서 Apple 엔지니어가 **"샌드박스된 앱에서
Accessibility API를 사용하는 것은 불가능하며, 사용자가 시스템 설정에서
직접 권한을 부여해도 동작하지 않는다"**고 확인했다. Apple 공식 문서 또한
"다른 앱을 제어하는 앱은 샌드박스할 수 없다"고 명시한다.

Sandbox를 켜면 Journey A(Selected Text)와 로컬 MLX 추론이 모두 막히므로
**§1.3의 MVP 가설 자체를 검증할 수 없다.**

**주의:** Sandbox와 TCC는 별개다. Sandbox를 껐다고 권한 프롬프트가
사라지지 않는다(§18 Permissions).

### 19.2 Mac App Store 미사용

App Store로 배포하지 않는다. **독립적인 이유가 두 개** 있다.

1.  **Accessibility API** --- 신규 앱은 App Sandbox가 필수이고,
    샌드박스에서 Accessibility API를 쓸 수 없다(§19.1). App Store에
    Accessibility를 쓰는 앱이 존재하지만 모두 2012년 샌드박싱 의무화
    이전에 등록된 앱이다
2.  **MLX JIT entitlement** --- 로컬 LLM 추론에 필요한
    `allow-jit` / `allow-unsigned-executable-memory`는 직접 배포 공증에서는
    승인되지만 **Mac App Store에서는 승인되지 않는다**(§19.3)

즉 제품의 정체성을 이루는 두 축이 각각 독립적으로 App Store와 충돌한다.

**오해 정정:** 모델 가중치를 런타임에 다운로드하는 것은 App Store
가이드라인 위반이 아니다. 2.5.2조는 앱의 기능을 바꾸는 **코드**를
금지하며, ML 모델 가중치는 데이터로 취급된다(Apple DTS 확인). 이는 App
Store를 쓰지 않는 이유가 아니다.

### 19.3 Signing and Notarization

배포 경로: **홈페이지 DMG 다운로드 + Developer ID 서명 + 공증**

필요 조건:

- Apple Developer Program 유료 멤버십 (연 USD 99 수준)
- Developer ID Application 인증서 (Account Holder 권한으로 발급)
- 서명·공증에 **추가 비용 및 횟수 제한 없음**

**공증은 사실상 필수다.** macOS Sequoia부터 Control-click으로 Gatekeeper를
우회하는 방법이 제거되었다. 공증되지 않은 앱은 사용자가 시스템 설정 →
개인정보 보호 및 보안으로 이동해 "Open Anyway"를 눌러야 하며, 그 버튼은
실행 시도 후 약 1시간만 노출된다. 유료 앱의 온보딩으로는 성립하지 않는다.

빌드 파이프라인 요구사항:

```text
1. 번들에 넣을 파일을 모두 배치 (서명은 번들 내용을 봉인한다)
2. 안쪽부터 서명: .dylib / .so → framework → app
   (--deep 플래그는 중첩 번들을 잘못 봉인할 수 있어 사용하지 않는다)
3. --options runtime (Hardened Runtime) + --timestamp
   → 둘 중 하나라도 없으면 Apple이 공증을 거부한다
4. codesign --verify --deep --strict 로 로컬 검증
   → 공증 왕복(수 분) 낭비 방지
5. xcrun notarytool submit
6. xcrun stapler staple
   → 티켓을 박아 Gatekeeper가 오프라인 검증 가능하게 한다
```

스테이플링은 본 제품에서 특히 중요하다. Local-first를 내세우는 앱이 첫
실행에 네트워크를 요구하면 모순이며, 오프라인 환경에서 실행이 막힌다.

**Hardened Runtime entitlements (MLX 사용 시 필수)**

```xml
<key>com.apple.security.cs.allow-jit</key>
<true/>
<key>com.apple.security.cs.allow-unsigned-executable-memory</key>
<true/>
<key>com.apple.security.cs.disable-library-validation</key>
<true/>
```

앞의 두 개는 MLX가 런타임에 Metal 커널을 JIT 컴파일하기 때문에 필요하다.
**없으면 첫 추론 시점에 Hardened Runtime이 프로세스를 종료시킨다.**
세 번째는 `mlx.metallib` 등 서명되지 않은 라이브러리를 번들에서 로드할
경우 필요하다.

### 19.4 Model Delivery

- 모델 가중치를 **앱 번들에 포함하지 않는다.** 앱 바이너리는 작게
  유지한다
- 첫 실행 시 또는 Background Assets로 설치 직후 백그라운드 다운로드
- 호스팅은 **정적 CDN**(R2/S3 등)으로 충분하다. GPU 인스턴스가 아니다
- 가중치 재배포 권리가 필요하므로 **License를 반드시 확인한다**
  (Qwen 계열 Apache 2.0, bge-m3 MIT, PIXIE 미확인 --- §11.5)
- 첫 실행 경험이 "수 GB 다운로드를 기다리세요"가 되지 않도록,
  Apple Foundation Models 기반 기본 경험을 먼저 제공한다(§11.9)

### 19.5 Update and Payment

App Store가 대신해주던 기능을 직접 구성해야 한다.

| 항목          | 방식                                           |
| ------------- | ---------------------------------------------- |
| 자동 업데이트 | Sparkle (appcast에 EdDSA 서명)                 |
| 결제          | Merchant of Record (Paddle / Lemon Squeezy 등) |
| 라이선스 검증 | 오프라인 검증 서명 파일 (§18)                  |
| 배포 호스팅   | 정적 CDN (§19.4와 공용)                        |

결제에 Merchant of Record를 권하는 이유는 EU VAT 및 미국 각 주
sales tax 처리를 대행하기 때문이다. Apple은 App Store 외부 거래에
관여하지 않으며 **수수료도 없다.**

멤버십이 만료되어도 이미 배포된 앱은 계속 다운로드·실행 가능하다. 다만
새 업데이트에 서명하려면 유효한 멤버십이 필요하다.

### 19.6 Data Location

Sandbox를 쓰지 않으므로 데이터 경로를 직접 정한다.

- 저장 위치: `~/Library/Application Support/<app>/`
- **경로 결정을 코드 전체에 흩뿌리지 않고 한 곳에서 관리한다**

이유는 Sandbox 전환 대비가 아니라, 전체 데이터 삭제(§22 Privacy), 백업,
재색인(§9.5) 기능이 모두 이 추상화를 필요로 하기 때문이다.

---

## 20. Error and Processing States

AI 처리는 비동기적으로 이루어질 수 있다.

Source 상태 예:

```text
captured
processing
ready
failed
```

Capture 자체는 빠르게 완료하고 AI 분석 때문에 사용자가 기다리지 않도록
한다.

예:

```text
✓ Remembered
Analyzing locally...
```

분석 실패 시 원본 Source는 유지하고 재처리가 가능해야 한다.

---

## 21. Performance Goals

정확한 수치는 개발 과정에서 측정하지만 MVP 목표는 다음과 같다.

### Capture

- Shortcut 입력 후 Popup이 즉각적으로 느껴질 것
- Source 저장이 AI 처리 완료를 기다리지 않을 것

### AI

- Background processing
- Mac 사용을 심각하게 방해하지 않을 것
- 역할별 모델 메모리 사용량 측정 (§11.1)
- 배터리/CPU/GPU/ANE 사용량 측정
- **Capture Path 상주 메모리 목표: 약 1GB 이하** (§11.10)
- 대형 Generation 모델을 상시 상주시키지 않을 것

### Search

- 일반적인 Memory 규모에서 검색 결과가 빠르게 표시될 것
- Answer 생성 전 관련 Source 결과를 먼저 표시한다 (§12.1
  Progressive rendering) --- Recall Path 모델 로딩 지연을 가리는 역할도
  한다

---

## 22. MVP Functional Requirements

### Capture

- [ ] Global Shortcut 동작
- [ ] Selected Text 감지
- [ ] Selected Text 저장
- [ ] Selection 없을 때 Screenshot
- [ ] Screenshot Preview
- [ ] Apple Vision OCR
- [ ] Capture Popup
- [ ] User Note
- [ ] Quick Note
- [ ] Voice Memo
- [ ] File Drag & Drop
- [ ] File Picker

### Shortcut

- [ ] Remember Current Context Shortcut
- [ ] Quick Memory Shortcut
- [ ] Shortcut 변경
- [ ] Shortcut 충돌 처리
- [ ] 설정 영구 저장
- [ ] Restore Defaults

### AI

- [ ] Local LLM 실행 (Apple Foundation Models 또는 MLX Swift)
- [ ] Generation 백엔드 교체 가능 구조 (§11.3)
- [ ] Summary 생성
- [ ] Topics 생성 (구조화 출력 보장)
- [ ] Analysis 거부/실패 시 폴백 경로 (§11.7.1)
- [ ] Local Embedding 생성
- [ ] Reranker 적용
- [ ] Hardware Tier 자동 감지 및 모델 선택 (§11.9)
- [ ] Model Residency 정책 (온디맨드 로드/해제, §11.10)
- [ ] Background processing
- [ ] Failed job retry

### Storage

- [ ] SQLite
- [ ] Screenshot 저장
- [ ] File 저장
- [ ] Voice 저장
- [ ] Source metadata
- [ ] Chunk 저장
- [ ] Embedding 저장 (모델명 + 버전 포함, §9.4)
- [ ] Source 삭제 cascade
- [ ] 데이터 경로 단일 추상화 (§19.6)
- [ ] 재색인 작업 (재개 가능 + 진행률 표시, §9.5)

### Recall

- [ ] 자연어 질문
- [ ] Vector Search (Top-N 회수)
- [ ] Reranker 재정렬 (Top-K)
- [ ] Source 목록 우선 표시 (Progressive rendering)
- [ ] 근거 기반 Answer 생성
- [ ] 근거 부족 시 거절 처리 (§12.2)
- [ ] Source 표시
- [ ] Source Detail
- [ ] URL reopen

### Privacy

- [ ] Local processing 기본
- [ ] Permission 기능별 지연 요청 (§18)
- [ ] Permission 거부 시 부분 동작
- [ ] Source 삭제
- [ ] 전체 데이터 삭제 기능

### Distribution (MVP 이후 배포 시)

- [ ] Developer ID 서명 + Hardened Runtime + MLX entitlements
- [ ] Notarization + Stapling
- [ ] 모델 다운로드 (CDN, 재개 가능)
- [ ] Sparkle 자동 업데이트
- [ ] 오프라인 라이선스 검증

---

## 23. Explicitly Out of Scope

MVP에서는 다음을 구현하지 않는다.

- VLM
- 화면 상시 감시
- 화면 24시간 녹화
- Automatic Context Capture
- 장시간 Meeting Recording
- Speaker Diarization
- iPhone
- Apple Watch
- Android
- Windows
- Multi-device Sync
- Cloud Sync
- MCP
- Cursor integration
- Claude Code integration
- Codex integration
- Calendar 자동 등록
- Todo 자동 등록
- Slack API
- Gmail API
- KakaoTalk integration
- Instagram integration
- Notion integration
- GitHub API integration
- Jira integration
- Cloud LLM
- OpenAI API
- Anthropic API
- Knowledge Graph
- Person Graph
- Project Graph
- 자동 Decision tracking
- 자동 Promise tracking
- 자동 Task management

---

## 24. MVP Success Metrics

MVP의 성공은 기능 개수가 아니라 Capture → Recall loop가 실제로
발생하는지로 판단한다.

### Primary qualitative signal

> "저장하지 않았다면 다시 찾기 어려웠을 정보를 이 앱 덕분에 실제로
> 찾아냈다."

이 경험이 반복되는가?

### Suggested metrics

- Daily Captures per Active User
- Capture → Save conversion
- User Note usage rate
- Search queries per user
- Searches with Source open
- Successful Recall rate
- Time from Capture to Recall
- Repeat usage after 7/14 days

초기 개인 테스트에서는 특히 다음을 기록한다.

```text
하루에 몇 번 자연스럽게 Capture하는가?
↓
며칠 뒤 실제로 질문하는가?
↓
원하는 Source를 찾았는가?
↓
그 Source가 실제로 도움이 되었는가?
```

---

## 25. Recommended Development Order

### Phase 0 --- Model selection (구현 전 필수)

Embedding 선택은 되돌리기 어렵기 때문에(§9.5) 코드 작성 전에 확정한다.

**이 단계의 유일한 필수 산출물은 Embedding 모델 확정이다.** 나머지는
측정·검증 항목이며, 나중에 변경 가능하다(§11.1 교체 난이도 참조).

산출물은 모두 **출하되지 않는 검증용 코드**다. 두 트랙으로 나뉜다.

#### Track A --- Retrieval 실험 (Python)

검색 품질과 관련된 모든 실험. `sentence-transformers` 등을 사용한다.

1.  자체 평가셋 구축
    - 실제 캡처 30\~50개 (웹 텍스트 / Screenshot OCR / 한국어 메모 /
      PDF 조각 혼합)
    - "며칠 뒤 이렇게 물어볼 것 같다" 형태의 질문 20\~30개
    - 각 질문에 정답 Source 라벨링
2.  **Embedding 후보 비교 (§11.5) --- 3개 게이트 전부 통과 확인**
3.  Reranker 유무 효과 측정 (§11.6)
4.  Searchable Text 필드 가중치 실험 (§10, 특히 User Note)
5.  STT 한영 코드 스위칭 실측 (§11.8)

#### Track B --- Apple 프레임워크 검증 (Swift)

Apple Foundation Models와 Core ML은 Python에서 접근할 수 없으므로 별도
트랙으로 분리한다. 앱이 아니라 **커맨드라인 도구 또는 Playground 수준의
확인용 코드**다.

6.  Track A에서 확정한 Embedding 모델의 **Core ML 변환 및 실행 검증**
7.  Apple Foundation Models 가드레일 거부율 **예비 측정** ---
    평가셋의 실제 캡처 샘플을 그대로 요약시켜 거부 빈도를 확인한다.
    본 측정은 Phase 2에서 실제 파이프라인으로 수행한다(§11.7.1)

Track B는 Embedding 결정을 차단하지 않는다. 단, 항목 6에서 실패하면
Track A로 돌아가 다음 후보를 검토해야 한다.

**중요:** 공개 벤치마크는 깨끗한 문서 기준이며 본 제품의 데이터 성격과
다르다. 반드시 자체 데이터로 판단한다.

### Phase 1 --- Capture foundation

Sandbox를 끈 상태로 시작한다(§19.1).

1.  macOS Menu Bar App
2.  Global Shortcut
3.  Custom Shortcut Settings
4.  **Selected Text Capture --- 최우선 기술 리스크 검증**
5.  Screenshot Capture
6.  Capture Popup
7.  User Note
8.  Local Source Storage (경로 추상화 포함, §19.6)

Selected Text 감지는 앱마다 동작이 다르므로 Chrome / Slack / Cursor /
Terminal / PDF 뷰어로 조기에 실측한다. 이것이 `⌥ Space` 경로의 절반을
담당한다.

**평가셋 적재는 앱 기능으로 만들지 않는다.** 캡처한 자료는 이미 로컬 DB에
저장되므로, Phase 0 평가셋은 그 DB를 **읽기 전용으로 읽는 외부
스크립트**(`phase0/`)로 뽑는다. 앱에 내보내기 기능을 넣지 않는 이유는 두
가지다.

- 사용자 내용을 평문으로 앱 보호 영역 밖에 쓰는 기능은 §18과 충돌한다.
  실수로 출하되면 미정리가 아니라 사고다
- "배포 전에 지운다"는 코드는 안 지워지거나, 지우면서 다른 것을 깨뜨린다.
  지울 것을 만들지 않는 편이 안전하다

Phase 1에서 필요한 것은 기능이 아니라 **DB 경로와 스키마를 문서화하는
것**이다(§19.6 경로 추상화에 이미 포함). 외부에서 읽을 수 있으면 충분하다.

앱 안에 도그푸딩 도구가 정말 필요해지면 원복 대상으로 두지 말고
`#if DEBUG`로 감싼다. 릴리스 빌드에 구조적으로 포함될 수 없게 만드는 것이
사람의 기억에 의존하는 것보다 안전하다.

### Phase 2 --- Processing

**MLX를 도입하지 않는다.** Apple Foundation Models만으로 파이프라인을
완성한다(§11.9).

1.  Apple Vision OCR
2.  `TextGenerator` 프로토콜 정의 + `AppleFMGenerator` 구현 (§11.3)
3.  Summary
4.  Topics (`@Generable` 구조화 출력)
5.  가드레일 거부율 측정 및 실패 처리 (§11.7.1)
6.  Local Embedding (Phase 0에서 확정한 모델)
7.  Background processing pipeline
8.  Failed job retry

### Phase 3 --- Recall

1.  Vector Search (Top-N)
2.  Reranker (Top-K)
3.  Search UI + Progressive rendering (§12.1)
4.  RAG answer + 거절 정책 (§12.2) --- Apple FM으로 먼저 구현
5.  Source citation
6.  Source Detail

이 시점에서 **Answer 품질을 실측한다.** 부족하다고 판단되면 Phase 3.5로
넘어간다.

**질문 라벨의 출처가 여기서 생긴다.** 평가셋의 문서는 DB에서 뽑을 수 있지만
질문과 정답 라벨은 자동으로 나오지 않는다. Recall이 동작하면 "사용자가 무엇을
검색했고 어떤 결과를 실제로 열었는지"가 곧 (질문, 정답) 쌍이 된다. 손으로
만든 질문보다 실제 사용 패턴을 반영하므로 가치가 높다.

단 이것도 앱 기능이 아니다. 검색어와 열어본 Source id는 로컬 DB에만 남기고
(외부 전송 없음, §18), 평가셋 변환은 Phase 0 스크립트가 담당한다.

### Phase 3.5 --- MLX 도입 (조건부)

Phase 3의 Answer 품질이 불충분할 경우에만 수행한다.

1.  `MLXGenerator` 구현 (§11.3)
2.  Hardware Tier 감지 및 모델 선택 (§11.9)
3.  모델 다운로드 + 진행률 UI
4.  Model Residency 정책 --- 온디맨드 로드/해제 (§11.10)
5.  Hardened Runtime entitlements 검증 (§19.3) --- 서명된 빌드에서
    첫 추론이 죽지 않는지 반드시 확인
6.  Apple FM ↔ MLX 품질 비교

### Phase 4 --- Additional MVP capture

1.  Quick Note
2.  Voice Memo (STT)
3.  File Upload
4.  PDF Chunking

### Phase 5 --- Dogfooding / optimization

1.  1\~2주 실제 사용
2.  Capture frequency 측정
3.  Search failure 사례 수집
4.  Embedding 품질 재평가 --- 실사용 DB에서 평가셋을 뽑아 Phase 0 하니스를
    재실행한다(Phase 1·3 참조). 이 시점에야 O1을 통계적으로 확정할 수 있는
    표본이 모인다
5.  모델 성능/속도/메모리 측정 (§21)
6.  Shortcut UX 개선
7.  OCR 실패 사례 분석

### Phase 6 --- Distribution (MVP 검증 이후)

1.  Apple Developer Program 가입
2.  서명 + 공증 파이프라인 CI 구성 (§19.3)
3.  Hardware Tier별 모델 다운로드 (§19.4)
4.  Sparkle 자동 업데이트
5.  결제 + 오프라인 라이선스 검증 (§19.5)
6.  **릴리스 빌드 점검** --- 아래 항목을 CI에서 자동 확인한다

릴리스 점검은 특정 기능을 되돌리는 작업이 아니다. 되돌릴 것을 만들지 않는
것이 원칙이고(Phase 1), 이 점검은 그 원칙이 지켜졌는지 확인하는 게이트다.

- `#if DEBUG` 경로가 릴리스 빌드에 포함되지 않았는지
- 사용자 내용을 앱 보호 영역 밖으로 쓰는 코드 경로가 없는지 (§18)
- 테스트·평가용 파일 경로가 번들에 남아 있지 않은지
- 서명된 빌드에서 첫 추론이 죽지 않는지 (§19.3 entitlements)

---

## 26. Post-MVP Direction

MVP 검증 이후에만 확장한다.

```text
MVP
Capture + Recall
      ↓
V1
Structured Memory
People / Project / Decision / Task / Promise / Event
      ↓
V2
MCP
Cursor / Claude Code / Codex
      ↓
V3
Actions
Calendar / Todo / Reminder
      ↓
V4
Automatic Context Capture
      ↓
V5
External Services
Slack / Gmail / Notion / GitHub / Jira ...
      ↓
V6
Mobile / Real-world Context
```

장기적인 제품 방향은 단순 Mac 메모 앱이 아니라:

> **Personal Context Layer**

사용자가 자신의 Memory를 소유하고 필요한 AI/Agent에게 필요한 범위의
Context를 제공하는 구조를 지향한다.

---

## 27. Final MVP Definition

### User inputs

```text
1. Remember Current Context
   ├── Selected Text
   └── Screenshot + OCR

2. Quick Memory
   ├── Text
   └── Voice Memo

3. File Import
```

### AI

```text
Apple Vision
→ OCR

Local Embedding
→ Retrieval (회수)

Reranker
→ Retrieval (정밀도)

Local LLM (Apple Foundation Models / MLX Qwen)
→ Summary / Topics / Answer

STT
→ Voice Transcript
```

### Storage

```text
SQLite
+
Local File System
```

### Platform

```text
macOS 26+ / Apple Silicon
App Sandbox: OFF
배포: Developer ID + Notarization, 홈페이지 직접 다운로드
추론: 100% 사용자 기기 (서버 없음)
```

### Output

```text
Natural Language Question
        ↓
Vector Search (Top-N)
        ↓
Reranker (Top-K)
        ↓
Local LLM
        ↓
Answer
+
Original Sources
```

### Core UX statement

> **보고 있는 것은 단축키로 기억하고, 생각하고 있는 것은 Quick Memory로
> 남기며, 나중에는 자연어로 다시 꺼낸다.**

### MVP product loop

```text
발견
 ↓
"나중에 필요하겠다"
 ↓
Capture
 ↓
필요하면 User Note
 ↓
잊어버림
 ↓
며칠/몇 주 후 질문
 ↓
AI Retrieval
 ↓
Answer + Original Source
 ↓
"저장해두길 잘했다"
```

이 Loop를 빠르고 정확하며 Local-first로 만드는 것이 MVP의 전부다.

---

## 28. Decision Log

Rev. 2 기준. 확정 사항과 미결 사항을 분리해 기록한다. 새로운 결정이
생기면 이 절을 갱신한다.

### 28.1 개발 환경 (기준 기기)

```text
MacBook Pro / Apple M4 Pro / 12-core (8P + 4E) / 48GB / macOS 26.5.2
```

이 기기는 도그푸딩 기준이며, 배포 대상은 8GB\~128GB로 가정한다(§11.9).

### 28.2 확정 사항

| #   | 결정                                                          | 근거                                                                |
| --- | ------------------------------------------------------------- | ------------------------------------------------------------------- |
| D1  | Mac App Store 미사용                                          | §19.2 --- 독립적 이유 2개                                           |
| D2  | 홈페이지 직접 배포 (Developer ID + 공증)                      | §19.3                                                               |
| D3  | App Sandbox OFF                                               | §19.1                                                               |
| D4  | 추론 서버 없음, Cloud는 정적 CDN만                            | §2.2, §19.4                                                         |
| D5  | 출하 코드는 Swift 네이티브, Python 번들 금지                  | §11.3                                                               |
| D6  | 단일 모델 → 5개 Model Role 분리                               | §11.1                                                               |
| D7  | Retrieval에 Reranker 단계 추가                                | §11.6                                                               |
| D8  | Embedding은 전 티어 동일, 교체 시 전체 재색인                 | §9.5, §11.9                                                         |
| D9  | Capture Path / Recall Path 모델 상주 분리                     | §11.10                                                              |
| D10 | 모델 가중치는 번들 제외, 설치 후 다운로드                     | §19.4                                                               |
| D11 | 라이선스 검증은 오프라인 완결                                 | §18                                                                 |
| D12 | Model selection을 Phase 0으로 선행                            | §25                                                                 |
| D13 | Deployment Target은 macOS 26 유지                             | §11.3 --- 27 요구 시 기기 축소                                      |
| D14 | Generation 백엔드는 자체 `TextGenerator` 프로토콜             | §11.3 --- Apple 통합 API는 27 SDK 필요                              |
| D15 | MLX는 MVP 필수 아님, Phase 3.5로 조건부 연기                  | §11.9, §25                                                          |
| D16 | Embedding 후보 License 전수 확보 (2026-08-25)                 | §11.5 --- PIXIE 계열 포함 전부 Apache 2.0/MIT                       |
| D17 | 게이트 3에서 인코더 계열 우선                                 | §11.5 --- 디코더는 ANE 불가, Capture 경로 배터리                    |
| D18 | 인코더 후보 4종 Core ML 변환 검증 완료                        | §28.3.2 --- 전부 통과, 일치 0.9998 이상                             |
| D19 | 평가셋 적재는 앱 기능 아님, 외부 스크립트가 DB를 읽음         | §25 Phase 1 --- §18 충돌 회피, 원복 대상 미생성                     |
| D20 | 도그푸딩 도구는 `#if DEBUG`, 릴리스 점검은 CI 게이트          | §25 Phase 1·6 --- 기억에 의존하지 않음                              |
| D25 | Embedding 모델: BAAI/bge-m3 (MIT, fp16, 1081MB)               | §11.5 --- no-note 강건성 최고, 프롬프트 불필요, Phase 5 재검증 예정 |
| D26 | Searchable Text 조합: User Note + Summary + Content + Context | §10 --- embedding_version v1 기준. 변경 시 재색인 필요              |

**후보에서 제외된 것**

| 제외 대상            | 이유                                        |
| -------------------- | ------------------------------------------- |
| Parakeet (STT)       | 한국어 미지원 (유럽 25개 언어 전용)         |
| Qwen3-Embedding-0.6B | 한국어 리트리벌에서 bge-m3보다 낮음 (§11.5) |
| Python 런타임 번들   | 코드사이닝·공증 비용 (§11.3, §19.3)         |
| VLM                  | MVP 범위 외 (§11.11)                        |

### 28.3 미결 사항

| #   | 미결 항목                                                 | 결정 시점       | 차단 요인                                                                                                                                                                      |
| --- | --------------------------------------------------------- | --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| O1  | ~~Embedding 모델 확정~~ **해소**                          | Phase 0         | **BAAI/bge-m3 (MIT, XLM-R 568M, Core ML fp16) 확정 (2026-08-26).** 게이트 2·3 통과, no-note 성적 1위(0.923), MIT 최관대, 프롬프트 접두어 불필요. Phase 5에서 실데이터 재검증   |
| O13 | ~~Searchable Text 필드 조합 확정~~ **해소**               | Phase 0         | **`[User Note] + [Summary] + [Content/OCR/Transcript] + [Context]` 확정 (2026-08-26).** User Note가 가장 강한 검색 신호(§28.3.1). Context 제거 시 영향 미미하나 포함 비용 없음 |
| O14 | Embedding int8 양자화 채택 여부                           | Phase 5         | 일치 0.986 --- fp16(1081MB) 우선 사용. Phase 5 실데이터로 품질 열화 여부 확인 후 결정                                                                                          |
| O15 | ANE 실제 활용 여부                                        | Phase 5         | Core ML 지연 격차 1.35배로 불확실                                                                                                                                              |
| O4  | ~~Analysis에 Apple Foundation Models 사용 여부~~ **해소** | Phase 2         | Apple FM 사용 확정. 가드레일 거부 시 failed 마킹 (max 3회 재시도). Phase 2에서 구현 완료                                                                                       |
| O5  | STT 모델 (Whisper turbo vs Qwen3-ASR)                     | Phase 4         | 한영 코드 스위칭 실측 필요                                                                                                                                                     |
| O6  | Answer 모델 최종 티어 구성                                | Phase 3         | 실사용 품질 확인 후                                                                                                                                                            |
| O11 | MLX 도입 여부                                             | Phase 3 종료    | Apple FM Answer 품질 실측 결과                                                                                                                                                 |
| O12 | macOS 27 이후 Apple 통합 추상화로 이전할지                | 27 정식 출시 후 | 이전 필수 아님                                                                                                                                                                 |
| O7  | Top-N / Top-K 값, Chunking 파라미터                       | Phase 3         | 실사용 조정                                                                                                                                                                    |
| O8  | ~~기본 단축키 충돌 검증~~ **해소**                        | Phase 1         | `⌥ Space`는 한국어 입력 소스 전환과 충돌. 사용자가 시스템 설정에서 입력 소스 단축키를 해제하거나, Settings에서 다른 키로 변경 가능. 기본값 유지 결정                           |
| O9  | 결제 머천트 및 라이선스 시스템                            | Phase 6         | MVP 검증 이후                                                                                                                                                                  |
| O10 | 국내 사업자등록·부가세 처리                               | Phase 6         | 세무 확인 필요 (제품 결정 아님)                                                                                                                                                |

**O1 해소로 Phase 3 진입이 가능해졌다.** 남은 미결 항목은 모두 해당 Phase에서 결정 가능.

### 28.2.1 Phase 1 Selected Text 감지 구현 현황

Phase 1에서 구현한 Selected Text 감지 접근 방식과 실측 대기 상태를 기록한다.

**구현 접근:**

1.  **AX API 1차** --- `kAXFocusedUIElementAttribute` →
    `kAXSelectedTextAttribute`
2.  **클립보드 폴백 2차** --- Cmd+C 시뮬레이션 후 `NSPasteboard` 읽기,
    원본 클립보드 복원
3.  **Window Title** --- AX API `kAXFocusedWindowAttribute` → `kAXTitleAttribute`
4.  **URL 수집** --- Chrome/Safari/Arc/Brave AppleScript

| 앱            | AX API | 클립보드 폴백 | Window Title | URL              | 비고                 |
| ------------- | ------ | ------------- | ------------ | ---------------- | -------------------- |
| Chrome        | 성공   | 미사용        | 성공         | AppleScript 성공 | AX만으로 충분        |
| Slack         | 성공   | 미사용        | 성공         | N/A              | AX만으로 충분        |
| Cursor        | 성공   | 미사용        | 성공         | N/A              | AX만으로 충분        |
| Terminal      | 실패   | 성공          | 성공         | N/A              | AX 미지원, 폴백 동작 |
| Preview (PDF) | 성공   | 미사용        | 성공         | N/A              | AX만으로 충분        |

**실측 결과 (2026-08-26):** Terminal을 제외한 모든 주요 앱에서 AX API 1차
감지가 동작한다. Terminal은 클립보드 폴백으로 정상 캡처됨. 기술 리스크 해소.

### 28.2.2 Phase 1 구현 시 추가된 설계 결정

PRD 원안에 없었으나 구현 과정에서 결정된 사항:

| 결정 | 내용                                                  | 근거                                                                                                                                       |
| ---- | ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| D21  | Screenshot 컨텍스트는 마우스 커서 아래 윈도우 기준    | 듀얼모니터에서 frontmostApp과 실제 보는 화면이 다를 수 있음. `SCShareableContent.windows`의 z-order + `CGRect.contains(mousePoint)`로 해결 |
| D22  | Screenshot 대상 디스플레이는 마우스 커서 위치 기준    | 메인 모니터 고정이 아닌 사용자가 보고 있는 화면 캡처                                                                                       |
| D23  | Capture Popup은 마우스가 있는 모니터에 표시           | 캡처한 화면과 같은 모니터에 결과를 보여줌                                                                                                  |
| D24  | AppDelegate 패턴으로 CaptureCoordinator 유지          | SwiftUI App struct의 `@State`는 body에서 미참조 시 생명주기 불안정. `NSApplicationDelegateAdaptor`가 확실함                                |
| D27  | Reranker(Phase 3.2) 미적용, brute-force vector search | MVP 규모(수천 벡터)에서 <50ms. 품질 실측 후 조건부 추가                                                                                    |
| D28  | ~~RAG Answer에 Apple FM 사용 (Phase 3.4)~~ → D30으로 교체 | ~~Context 8192 토큰 내에서 충분~~. Apple FM의 작은 컨텍스트 + 보수적 가드레일 문제로 MLX 교체 결정                                          |
| D29  | 메인 창 SwiftUI Window scene + @Observable AppState   | ObservableObject의 `@available` 프로퍼티 제약으로 @Observable 채택                                                                         |
| D30  | LLM을 Qwen3-4B-4bit (MLX) 기반으로 교체              | mlx-swift-lm 3.31.4, ChatSession API. 128K 컨텍스트. Apple FM 폴백 유지. TextGenerator 프로토콜 + ChatEngineProtocol로 추상화               |
| D31  | Chat 답변을 스트리밍으로 전환 (Phase 5.5)            | `ChatSession.streamResponse` 사용, AppState에 대화별 스트리밍 버퍼 + Task 취소로 "중지" 지원. thinking(`<think>…</think>`) 토큰은 스트리밍 중 실시간 필터. 답변 확정 후 Markdown 렌더 |
| D32  | 벡터 검색에 유사도 임계값(minScore=0.3) 도입          | 관련성 낮은 소스가 컨텍스트/근거로 유입되는 문제 방지. `VectorSearchEngine.search`에 파라미터 추가                                          |
| D33  | 커스텀 브랜드 색상(#F94315) 미적용, 시스템 색상 유지   | 사용자 요청으로 원복. 색상은 `AppTheme.swift`의 semantic 토큰 1곳에 집약해 향후 변경 용이하게 유지                                         |
| D34  | 최초 실행 온보딩 + 모델 상태 표시 추가 (Phase 5.5)   | 첫인상 개선. `hasCompletedOnboarding`(UserDefaults) 게이트, `AppState.modelStatus`로 다운로드 진행률/로딩/준비 상태를 메뉴바에 노출        |
| D35  | UI 텍스트 한국어 통일 (Phase 5.5)                    | 영어/한국어 혼용 제거. 기본 대화 제목도 "새 채팅"으로 변경                                                                                 |
| D36  | 생성(Answer/Analysis)을 GPT-5.6 Luna(클라우드)로 이전 (Phase 7) | 로컬 Qwen3-4B의 품질 한계 + RAM/용량 부담 해소. 무거운 "생성"만 클라우드로, 임베딩·검색·저장은 로컬 유지하는 하이브리드. `ChatEngineProtocol`에 `LunaChatEngine`(OpenAI Chat Completions) 추가. 로컬(MLX)·Apple FM 폴백 유지 |
| D37  | 임베딩은 로컬 bge-m3 유지 (클라우드 이전 안 함)       | 임베딩은 캡처마다 실행 → 클라우드로 옮기면 캡처마다 네트워크·과금·전체 전송(프라이버시 훼손). bge-m3는 하드웨어 부담 작고(단발 forward) 재임베딩 무료·오프라인. §9.5 재색인 정책상 교체 지양. Luna는 임베딩 미지원(`v1/embeddings: Not supported`) |
| D38  | BYOK(사용자 OpenAI 키) 우선, 제공 모델은 Luna 단일    | 초기엔 서버 없이 앱이 OpenAI 직접 호출(운영자 원가 0). 키는 Keychain 저장, 앱 번들에 미포함. 추후 사용자 키 입력 + 모델 선택 옵션. 운영자 부담(방식1)은 프록시 서버 필요 → 유료화 시점에 검토. **→ D43~D46에서 3-티어(BYOK/Free/Pro) + Supabase 프록시 + 웹 대시보드 배포로 구체화** |
| D39  | 저장 구조 재정의: MD(진실원) + 벡터(파생) 이중 저장 (Phase 7) | Luna로 요약·구조화한 **편집 가능한 .md**를 진실원으로 저장, 벡터는 MD에서 파생된 검색 인덱스. MD 수정 시 해당 항목만 재임베딩. Karpathy식 LLM wiki/MCP 확장 대비 (§2.3 원본/해석 분리 원칙 강화) |
| D40  | MD 생성은 백그라운드/지연 처리                        | 캡처 즉시 로컬 OCR 텍스트로 저장·임베딩해 검색은 바로 가능. Luna MD 생성은 온라인 시 `ProcessingQueue`에서 보강. 캡처 즉각성·오프라인 캡처 보장 |
| D41  | OCR을 프로토콜로 추상화 (Windows 확장 대비)           | `OCRProcessor` 프로토콜 + AppleVisionOCR(macOS 로컬 기본) / CloudVisionOCR(Luna 이미지입력, 선택적). 이미지 이해·맥락 해석은 Luna 이미지입력으로. Apple Vision 하드코딩 제거 |
| D42  | MVP 파일 지원 범위 축소: PDF/MD/이미지                | docx·xlsx는 파서 공수 대비 우선순위 낮아 보류, 음성(STT)도 보류. §5.5/§16 대비 축소 |
| D43  | 요금제 3-티어: BYOK / Free / Pro (D38 확장)           | 키 위치로 플랜 구분. **BYOK**=사용자 키, 앱이 직접 OpenAI 호출(서버 미경유, 로그인 불필요). **Free**=제작자 키 + 사용량 쿼터 + 제한 모델(프록시 경유, 로그인 필요). **Pro**=제작자 키 + 고급 모델(Luna) 구독. Free·Pro는 제작자 키를 클라이언트에 절대 노출하지 않음 → 프록시 필수 |
| D44  | 키 해석 계층화: `AICredentials` 리졸버 (구현)         | 우선순위 ①사용자 Keychain(BYOK) ②(DEBUG 전용)로컬 `.env` ③(미래)프록시 서버. `.env` 로더는 `#if DEBUG`로 릴리즈 빌드에서 컴파일 제외 → 제작자 키가 배포 바이너리에 절대 포함되지 않음. `AICredentials.swift` |
| D45  | Free/Pro 백엔드는 Supabase (Auth + Edge Function 프록시) | 회원가입/로그인/세션은 Supabase Auth, 플랜·사용량은 Postgres(+RLS), 제작자 키 대리 호출·쿼터·미터링은 Edge Function. 앱은 로그인 후 JWT를 Keychain 저장 → 서버 호출에 첨부. 인증·구독 검증은 **서버가** 판단(클라이언트 불신) |
| D46  | 배포 UX: 브라우저 다운로드 + 웹 대시보드 + 딥링크 로그인 | 회원가입·플랜·결제는 웹에서 처리, 앱은 로그인만. 데스크톱 로그인은 커스텀 URL 스킴(`campsis://auth?token=…`) 딥링크로 웹 인증 결과 수신. 초기 웹 대시보드 없이 앱 내 설정 화면 + 결제사 관리페이지로 대체 가능. §19.2/§19.5 보강 |

### 28.3.1 Phase 0 진행 현황

측정 도구는 `phase0/`에 구축 완료(Python 3.13, uv). 실행 방법은
`phase0/README.md` 참조. **평가셋이 아직 시드 수준이라 결정은 내리지
않았다.**

| 항목                                              | 상태                                |
| ------------------------------------------------- | ----------------------------------- |
| 평가 하니스 (hit@k, recall@k, NDCG, MRR)          | 완료, 검증됨                        |
| 통계적 유의성 (부트스트랩 신뢰구간 + 짝지은 비교) | 완료                                |
| BM25 기준선 (한글 문자 바이그램)                  | 완료                                |
| 평가셋 품질 검사 (어휘 중복)                      | 완료                                |
| 평가셋 수집 도구                                  | 완료                                |
| Searchable Text 조합 실험 (6종)                   | 완료                                |
| Reranker 단계 (Qwen3-Reranker-0.6B)               | 완료, 검증됨                        |
| 후보 License 전수 확인                            | 완료 --- 6종 전부 통과 (D16)        |
| **관문 3 Core ML 변환**                           | 완료 --- 인코더 4종 전부 통과 (D18) |
| 평가셋                                            | **문서 12건 / 질문 13건 --- 부족**  |

후보 6종 전수 측정값(2026-08-25, 시드 평가셋). **의사결정 근거로 쓸 수
없다.** 도구가 동작함을 확인한 값으로만 취급한다.

```text
model             composition    hit@1   hit@5   ndcg@10    mrr
arctic-l-v2       all            1.000   1.000     0.988   1.000
bge-m3-ko         all            1.000   1.000     0.986   1.000
bge-m3            all            1.000   1.000     0.984   1.000
pixie-rune        all            0.923   1.000     0.959   0.962
qwen3-emb-0.6b    all            0.923   1.000     0.950   0.962
pixie-spell       all            0.846   1.000     0.939   0.923
```

**이 평가셋은 포화되어 모델을 구분하지 못한다.** 상위 3종이 0.984\~0.988
범위에 몰려 있고 hit@1이 전부 1.000이다. 질문 13개에서는 1개 차이가 지표를
0.077씩 움직이므로 이 간격은 노이즈다.

공개 벤치마크와 순서가 반대로 나온 것(PIXIE 계열이 bge-m3보다 낮음)도
같은 이유다. **모델 특성이 아니라 평가셋 부족의 증거로 읽어야 한다.** 이
현상 자체가 평가셋을 채워야 하는 이유다.

**통계적으로 확인한 결론.** 부트스트랩 10,000회, 95% 신뢰구간, 질문 단위
짝지은 비교다(`src/significance.py`).

```text
비교                          차이      95% CI              판정
bge-m3-ko vs bge-m3        +0.003  [+0.000, +0.008]   구분 불가
bge-m3-ko vs pixie-rune    +0.027  [-0.005, +0.085]   구분 불가
bge-m3    vs pixie-rune    +0.024  [-0.012, +0.085]   구분 불가
bge-m3-ko vs BM25          +0.222  [+0.055, +0.416]   유의 (p=0.005)
pixie-rune vs BM25         +0.195  [+0.055, +0.356]   유의 (p=0.005)
```

**임베딩 후보끼리는 어느 쌍도 구분되지 않는다.** 유의하게 구분되는 것은
임베딩 대 BM25뿐이다. 즉 이 평가셋은 "임베딩이 단어 검색보다 낫다"는 것은
증명하지만 어느 임베딩이 나은지는 답하지 못한다.

1·2위 격차 0.003을 검출하려면 질문 약 50개가 필요하다. 다만 이 격차는
검출 가능해져도 **실질적으로 무의미한 수준**이다(기준 0.01). 표본을 늘려
통계적 유의성을 만드는 것과 사용자가 체감하는 품질은 다르다.

**BM25 기준선이 0.764로 높다.** 한국어는 조사가 붙어 어절 단위로 자르면
BM25가 부당하게 약해지므로 문자 바이그램을 쓴다. 어절 단위로 측정했을
때는 0.611이 나왔고, 그대로 두면 임베딩의 우위가 과장된다.

`no-note` 조합에서만 후보 간 차이가 드러났다. 실제 신호가 있는 유일한
관찰이며, 평가셋을 늘린 뒤 재확인한다.

```text
model             no-note hit@1   all 대비
bge-m3                    0.923    -0.077
bge-m3-ko                 0.846    -0.154
pixie-rune                0.846    -0.077
arctic-l-v2               0.769    -0.231
qwen3-emb-0.6b            0.538    -0.385
```

User Note를 제거하면 모든 후보가 하락하고 낙폭이 크게 갈린다.
**User Note가 가장 강한 검색 신호일 가능성이 높다.** 사실로 확인되면
Capture UI에서 메모 입력을 적극적으로 유도해야 한다(§6). Context(앱·창
제목·URL) 제거는 영향이 거의 없었다.

**Reranker는 시드셋으로 판단 불가.** 임베딩만으로 hit@1이 1.000이라
개선 여지가 없고 하락만 관측된다(-0.154). Reranker의 가치는 hit@1이 낮고
hit@5가 높을 때 드러나므로, 평가셋을 채운 뒤 재측정해야 한다.

**측정된 지연은 주의 깊게 볼 값이다.** Qwen3-Reranker-0.6B가 후보 1개당
약 115ms(PyTorch/MPS, fp16, batch 4)다. 후보 50개면 약 5.8초로 §21의
Recall 첫 응답 3초 목표를 초과한다. Swift/MLX 구현은 이보다 빠를 것이나,
**Top-N을 크게 잡을 수 없다는 신호다.** O7(Top-N 값)은 이 비용과 함께
결정한다.

### 28.3.2 관문 3 --- Core ML 변환 검증 결과

`src/coreml_check.py`로 실측했다(coremltools 9.0, macOS 26.5.2, M4 Pro,
seq_len 512 고정, fp16, mlprogram).

```text
후보              아키텍처          크기     ALL     CPU only   PyTorch 일치
pixie-rune      XLM-R 568M      1081MB   63.8ms    82.7ms      0.99996
bge-m3-ko       XLM-R 568M      1081MB   61.4ms    82.3ms      0.99992
arctic-l-v2     XLM-R 568M      1081MB   61.1ms    82.4ms      0.99994
bge-m3          XLM-R 568M      1081MB   61.0ms    82.3ms      0.99981
```

**인코더 후보 4종 전부 관문 3을 통과한다.** 변환에 성공하고 PyTorch와
코사인 일치가 0.9998 이상이다.

**그리고 관문 3도 후보를 구분하지 못한다.** 네 모델이 모두 XLM-RoBERTa
568M 동일 구조라 크기·지연·정확도가 사실상 같다. 이로써 관문 1(성적),
관문 2(License), 관문 3(변환) 모두에서 인코더 후보 간 우열이 없다.

**크기 1081MB가 실제 문제다.** 첫 실행에 1GB를 내려받게 하는 것은 제품
품질 문제다(§19.4). 가중치의 약 47%가 vocab 250K 임베딩 테이블
(250,002 × 1,024)이다. int8 양자화를 측정했다.

```text
정밀도    크기      ALL      PyTorch 일치
fp16    1081MB   61.0ms      0.99981
int8     542MB   51.2ms      0.98623
```

크기가 절반이 되고 오히려 빨라지지만 수치 일치가 0.986으로 떨어지고
양자화 중 `invalid value encountered in cast` 경고가 발생한다. **이 격차가
검색 품질에 영향을 주는지는 실제 평가셋으로만 답할 수 있다.** 시드
평가셋은 포화되어 열화를 검출하지 못한다. O14로 남긴다.

가속 여부는 판단을 보류한다. ALL(61ms)과 CPU only(82ms) 격차가 1.35배에
불과해 ANE가 충분히 활용되는지 불확실하다. 상시 동작하는 메뉴바 앱의
전력 특성과 직결되므로 Swift 트랙에서 재확인한다.

**변환 과정의 실무 메모** --- transformers 5.x가 어텐션 마스크 생성에
`new_ones`를 쓰는데 coremltools 9.0 프런트엔드에 변환 규칙이 없어 직접
등록해야 했다. 모델의 한계가 아니라 툴체인 공백이며, 변환은 개발 시점에
한 번만 수행하고 산출물(`.mlpackage`)만 앱에 들어가므로 배포에는 영향이
없다. `src/coreml_check.py`의 `_register_missing_ops` 참조.

### 28.4 참고 데이터

Phase 0에서 자체 평가셋으로 재검증할 대상이며, 그 전까지의 판단 근거다.

**한국어 리트리벌** --- NDCG@10, Korean-MTEB-Retrieval-Evaluators 코드베이스
(출처: telepix 모델 카드). 벤치마크별로 격차가 다르므로 단일 순위로 읽지 않는다.

```text
모델                            STELLA(XL)  MTEB(ko)  RTEB(en)  License
PIXIE-Spell-v1.5-0.6B              0.6731    0.7717    0.5923   Apache 2.0
PIXIE-Rune-v1.5 (0.5B)             0.6559    0.7651    0.5546   Apache 2.0
arctic-embed-l-v2.0 (0.5B)         0.5448    0.7390    0.5222   Apache 2.0
bge-m3 (0.5B)                      0.5056    0.7483    0.5104   MIT
Qwen3-Embedding-0.6B               0.4707    0.7017    0.6521   Apache 2.0
text-embedding-3-large (API)          N/A    0.6646    0.6174   상용 API
```

STELLA에서 PIXIE-Rune과 bge-m3의 격차는 0.15지만 MTEB(ko)에서는 0.017이다.
Rev. 2에 기록했던 단일 수치(0.7345 / 0.7126)는 출처가 불명확해 교체했다.

**Reranker** --- MTEB-R

```text
Qwen3-Reranker-0.6B    65.80   Apache 2.0, 32K ctx, Q6_K 약 472MB
BGE-reranker-v2-m3     57.03
```

**한국어 STT** --- CER

```text
Whisper large-v3-turbo (809M)   5.59%   13~14x RTFx, 101개 언어
SenseVoice Small                8.28%   52~118x RTFx, CJK 특화
Parakeet V3                     미지원
```

**Generation** --- Qwen 3.5는 201개 언어 지원, CJK 강점으로 한국어에서
Gemma 4 대비 우위. Gemma 4 E4B는 소형 모델 중 환각률 최저이므로 §12.2
거절 정책이 지켜지지 않을 경우의 대안.

**Apple Foundation Models** --- Context 8,192 토큰, 약 3B, `@Generable`
구조화 출력 보장, 다운로드 없음, OS 공유, 무료. 가드레일 오탐이 리스크.
macOS 26에서 사용 가능.

**SDK 제약** --- `MLXFoundationModels`(MLX ↔ FoundationModels 브릿지)는
macOS 27.0 SDK 필요. macOS 26에서는 Apple FM과 MLX를 각각 사용할 수 있으나
Apple의 통합 추상화는 쓸 수 없다. 따라서 자체 프로토콜을 사용한다(D14).

**MLX Swift** --- `ml-explore/mlx-swift-lm` 3.31.3 기준. products:
`MLXLLM`, `MLXLMCommon`, `MLXHuggingFace`. 버전 간 API 변경이 잦으므로
핀 고정 버전의 README를 기준으로 삼는다.
