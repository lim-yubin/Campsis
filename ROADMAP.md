# Campsis Roadmap

마지막 업데이트: 2026-08-31

---

## 한눈에 보기

Campsis는 6단계에 걸쳐 만들어집니다.

| Phase              | 한줄 요약                           | 비유                          |
| ------------------ | ----------------------------------- | ----------------------------- |
| **0. 모델 평가**   | 어떤 AI 두뇌를 쓸지 테스트          | 시험지 만들어서 후보생 시험   |
| **1. 캡처**        | 사용자가 보고 있는 것을 가져오기    | 카메라 + 메모장 설치          |
| **2. 처리**        | 가져온 것을 AI가 이해하기           | 사진 속 글자 읽기, 요약, 분류 |
| **3. 검색**        | "그거 뭐였지?" 하면 찾아주기        | 개인 비서에게 물어보기        |
| **3.5. MLX LLM**   | 로컬 AI를 Qwen3-4B로 업그레이드     | 비서 두뇌를 교체              |
| **4. 추가 입력**   | 메모, 음성, 파일도 기억             | 메모장 + 녹음기 + 파일함 추가 |
| **4.5. 대화형 UI** | ChatGPT 스타일로 기억과 대화        | 비서와 채팅하기               |
| **5. 실사용 검증** | 직접 써보면서 다듬기                | 시범 운영                     |
| **6. 배포**        | 브라우저 다운로드 + 웹 대시보드로 출시 | 웹사이트에서 직접 배포 (App Store 미배포) |

**현재 위치:** Phase 7 진행중 — 클라우드 생성(GPT-5.6 Luna) 통합 + MD 지식베이스 도입 (품질 개선 & 하드웨어 부담 완화)

**출시 전략(2026-08-31 확정):** MVP 점진 출시가 아니라 **핵심 기능 완성 후 공개 출시**. 스코프 = Phase 7(Luna+MD) + BYOK/Free/Pro + 서버·결제·대시보드. Pro+(iCloud 동기화·내보내기·팀 공유)는 **출시 후**로 분리. 공개 출시 전 **클로즈드 베타(20~30명)** 필수.

**빌드 순서:** A(제품 완성: Phase 7 마무리 → Phase 5 도그푸딩) 와 B(계정·결제 인프라: Supabase Auth+프록시 → 딥링크 로그인 → 결제 → 대시보드) 를 **병행** → C(패키징: 서명·공증 → Sparkle → 호스팅) → **클로즈드 베타** → **공개 출시**. 서버·결제·대시보드는 이제 "나중"이 아니라 **출시 선행 조건**이다.

---

## Phase 0 — 임베딩 모델 평가 `완료`

| #   | 작업                                          | 상태       | 비고                                                         |
| --- | --------------------------------------------- | ---------- | ------------------------------------------------------------ |
| 0.1 | 평가 하니스 구축 (hit@k, recall@k, NDCG, MRR) | 완료       | `phase0/`                                                    |
| 0.2 | BM25 기준선 (한글 문자 바이그램)              | 완료       |                                                              |
| 0.3 | 후보 6종 전수 측정                            | 완료       | 시드 평가셋 한정                                             |
| 0.4 | Reranker 단계 검증 (Qwen3-Reranker-0.6B)      | 완료       |                                                              |
| 0.5 | Core ML 변환 검증 (인코더 4종)                | 완료       | D18                                                          |
| 0.6 | 라이선스 전수 확인                            | 완료       | D16                                                          |
| 0.7 | 평가셋 확장                                   | **미완료** | 문서 12건/질문 13건 — 부족. Phase 5에서 실사용 데이터로 보강 |

**해소:** O1(임베딩 모델) → **BAAI/bge-m3** 확정 (2026-08-26). MIT, no-note 강건성 최고, 프롬프트 불필요.

---

## Phase 1 — Capture Foundation `완료`

| #    | 작업                              | 상태 | 비고                                                            |
| ---- | --------------------------------- | ---- | --------------------------------------------------------------- |
| 1.1  | macOS Menu Bar App (MenuBarExtra) | 완료 | LSUIElement, Dock 숨김                                          |
| 1.2  | Global Shortcut (⌥ Space)         | 완료 | O8 해소 — 한국어 입력기 충돌 확인됨, 사용자 설정으로 해결       |
| 1.3  | Custom Shortcut Settings          | 완료 | KeyboardShortcuts 라이브러리                                    |
| 1.4  | Selected Text Capture             | 완료 | AX API + 클립보드 폴백. Terminal 제외 모두 AX 성공              |
| 1.5  | Screenshot Capture                | 완료 | ScreenCaptureKit, 마우스 위치 기준 디스플레이/윈도우 (D21, D22) |
| 1.6  | Capture Popup                     | 완료 | NSPanel, 마우스 모니터에 표시 (D23)                             |
| 1.7  | User Note                         | 완료 | 팝업 내 메모 필드                                               |
| 1.8  | Local Source Storage              | 완료 | GRDB + SQLite, AppPaths 경로 추상화                             |
| 1.9  | 단위 테스트                       | 완료 | AppPaths, Migration, SourceRepository CRUD                      |
| 1.10 | 빌드/실행 스크립트                | 완료 | `Campsis/run.sh`                                                |

---

## Phase 2 — Processing `완료`

Apple Foundation Models만으로 파이프라인을 완성한다. MLX는 도입하지 않는다.

| #   | 작업                                      | 상태 | 의존성             | 비고                                |
| --- | ----------------------------------------- | ---- | ------------------ | ----------------------------------- |
| 2.1 | Apple Vision OCR                          | 완료 | 없음               | VNRecognizeTextRequest, 한국어+영어 |
| 2.2 | TextGenerator 프로토콜 + AppleFMGenerator | 완료 | 없음               | §11.3, @Generable 구조화 출력       |
| 2.3 | Summary 생성                              | 완료 | 2.2                | AppleFMGenerator에 포함             |
| 2.4 | Topics 추출 (@Generable 구조화 출력)      | 완료 | 2.2                | AppleFMGenerator에 포함             |
| 2.5 | 가드레일 거부율 측정 + 실패 처리          | 완료 | 2.3, 2.4           | max 3회 재시도 후 failed            |
| 2.6 | Local Embedding                           | 완료 | O1 확정됨 (bge-m3) | Core ML bge-m3 fp16, Phase 3에 통합 |
| 2.7 | Background processing pipeline            | 완료 | 2.1~2.5            | Actor 기반 ProcessingQueue          |
| 2.8 | Failed job retry                          | 완료 | 2.7                | 3회 초과 시 failed 마킹             |

---

## Phase 3 — Recall `완료` (Reranker 보류)

| #   | 작업                              | 상태     | 의존성  | 비고                                             |
| --- | --------------------------------- | -------- | ------- | ------------------------------------------------ |
| 3.0 | Local Embedding (bge-m3, Core ML) | 완료     | O1 확정 | EmbeddingService + swift-transformers 토크나이저 |
| 3.1 | Vector Search (Top-N)             | 완료     | 3.0     | Accelerate vDSP cosine similarity, brute-force   |
| 3.2 | Reranker (Top-K)                  | **대기** | 3.1     | 품질 실측 후 조건부 추가                         |
| 3.3 | Search UI + Progressive rendering | 완료     | 3.1     | Sources 먼저 표시 → Answer 스트리밍              |
| 3.4 | RAG answer + 거절 정책            | 완료     | 3.1     | Apple FM AnswerGenerator, 근거 부족 시 거절      |
| 3.5 | Source citation                   | 완료     | 3.4     | Answer 아래 참조 Source 목록                     |
| 3.6 | Source Detail                     | 완료     | 3.3     | 원본 텍스트/스크린샷/OCR/Summary/Topics/Metadata |
| 3.7 | Memories View                     | 완료     | 3.6     | 시간순 목록 + 타입 필터                          |

**게이트:** Answer 품질 실측 후 불충분 시 Phase 3.5(MLX Reranker)로 진행.

---

## Phase 3.5 — MLX LLM 통합 `완료`

Apple FM의 제한된 컨텍스트/품질 문제로 Qwen3-4B-4bit (MLX) 직접 통합 결정.

| #     | 작업                                         | 상태 | 비고                                                  |
| ----- | -------------------------------------------- | ---- | ----------------------------------------------------- |
| 3.5.1 | MLXGenerator 구현 (요약/태깅용)              | 완료 | MLXLLM ChatSession, JSON 파싱                         |
| 3.5.2 | MLXChatEngine 구현 (대화형 검색)             | 완료 | ChatSession, 128K 컨텍스트, thinking 토큰 strip       |
| 3.5.3 | HuggingFace 모델 자동 다운로드               | 완료 | swift-huggingface HubClient, 캐시 관리                |
| 3.5.4 | Apple FM 폴백                                | 완료 | MLX 로드 실패 시 AppleFMGenerator + AppleFMChatEngine |
| 3.5.5 | ChatEngineProtocol 추상화                    | 완료 | MLX/AppleFM 교체 투명                                 |
| 3.5.6 | Hardware Tier 감지 + Model Residency         | 대기 | Phase 5 dogfooding 후 결정                            |
| 3.5.7 | Hardened Runtime entitlements 검증            | 대기 | §19.3                                                 |

---

## Phase 4 — Additional MVP Capture `진행중`

| #   | 작업             | 상태     | 비고                                       |
| --- | ---------------- | -------- | ------------------------------------------ |
| 4.1 | Quick Note       | 완료     | ⌥⇧Space → QuickNotePopup → Source(note)    |
| 4.2 | Voice Memo (STT) | **대기** | Phase 4.5로 보류 (O5 미결정)               |
| 4.3 | File Upload      | 완료     | Drag&Drop + File Picker, PDF/TXT/MD/이미지 |
| 4.4 | PDF Chunking     | **대기** | 현재 단일 Source, Phase 5에서 페이지 분할  |

---

## Phase 4.5 — Chat UI `완료`

| #     | 작업                                              | 상태 | 비고                           |
| ----- | ------------------------------------------------- | ---- | ------------------------------ |
| 4.5.1 | Conversation + Message 데이터 모델 + 마이그레이션 | 완료 | v4-chat 마이그레이션           |
| 4.5.2 | ConversationRepository + MessageRepository        | 완료 | GRDB CRUD                      |
| 4.5.3 | ChatEngine (multi-turn + 벡터 검색)               | 완료 | MLX ChatSession (AppleFM 폴백) |
| 4.5.4 | ChatView 대화형 UI                                | 완료 | 메시지 버블 + 입력창 + 스크롤  |
| 4.5.5 | Conversation 사이드바 목록                        | 완료 | New Chat, 삭제, 시간순 정렬    |
| 4.5.6 | 기존 SearchView 제거 + 네비게이션 재구성          | 완료 | Search 탭 → Chat 기반으로 교체 |

---

## Phase 5 — Dogfooding / Optimization `대기`

| #   | 작업                                       | 상태 | 비고              |
| --- | ------------------------------------------ | ---- | ----------------- |
| 5.1 | 1~2주 실제 사용                            | 대기 |                   |
| 5.2 | Capture frequency 측정                     | 대기 |                   |
| 5.3 | Search failure 사례 수집                   | 대기 |                   |
| 5.4 | 임베딩 품질 재평가 (Phase 0 하니스 재실행) | 대기 | O1 최종 확정 시점 |
| 5.5 | 모델 성능/속도/메모리 측정                 | 대기 | §21               |
| 5.6 | Shortcut UX 개선                           | 완료 | 메뉴바 빠른 메모 연결 + ⌥⇧M 충돌 제거 |
| 5.7 | OCR 실패 사례 분석                         | 대기 |                   |

---

## Phase 5.5 — UX 개선 1차 `완료`

improvement-plan.md + 코드 분석 통합. 유료 기능(BYOM/하이브리드 검색/내보내기/태그)은 이후로 보류.

| #     | 작업                                    | 상태 | 비고                                                    |
| ----- | --------------------------------------- | ---- | ------------------------------------------------------- |
| 5.5.1 | 메뉴바 빠른 메모 버그 + 단축키 충돌 수정 | 완료 | `.triggerQuickMemory` 알림 연결, ⌥⇧M 중복 제거          |
| 5.5.2 | 미사용 ConversationListView 제거         | 완료 | 죽은 코드 정리                                          |
| 5.5.3 | 검색 유사도 임계값 (minScore)            | 완료 | 기본 0.3 미만 결과 제외                                 |
| 5.5.4 | 모델 다운로드/로딩 상태 표시             | 완료 | AppState.modelStatus + 메뉴바 표기, 다운로드 % 진행률   |
| 5.5.5 | 캡처/노트 저장 성공 피드백               | 완료 | "기억함" 토스트 패널                                    |
| 5.5.6 | 스트리밍 답변 + "생각 중" 표시           | 완료 | ChatSession.streamResponse, thinking 토큰 실시간 필터   |
| 5.5.7 | 생성 중지                                | 완료 | 전송 버튼 → 중지, Task 취소                             |
| 5.5.8 | 대화 제목 AI 자동 요약                   | 완료 | 첫 응답 후 2~4단어 제목 생성                            |
| 5.5.9 | 에러 타입별 안내 + 새 채팅 액션          | 완료 | 컨텍스트 초과 시 "새 채팅 시작" 버튼                    |
| 5.5.10| Memories 자유 텍스트 검색                | 완료 | 제목/내용/요약/OCR/전사/메모/앱 대상                    |
| 5.5.11| 날짜 선택 UI 개선                        | 완료 | scaleEffect 제거, 팝오버 크기 정상화                    |
| 5.5.12| 원문/URL 열기 버튼                       | 완료 | SourceDetailView 툴바 "원문 열기"                       |
| 5.5.13| 최초 실행 온보딩                         | 완료 | 권한/단축키 안내 4단계                                  |
| 5.5.14| UI 텍스트 한국어 통일                    | 완료 | 메뉴/설정/팝업/상세/사이드바 전반                       |
| 5.5.15| semantic 색상 토큰 + 접근성 라벨         | 완료 | AppTheme.swift, accessibilityLabel 추가                 |

---

## Phase 7 — 클라우드 생성(Luna) + MD 지식베이스 `진행중`

**배경:** 로컬 생성 모델(Qwen3-4B)은 품질 한계 + 소비자 하드웨어(RAM/용량) 부담이 큼. **무거운 "생성"만 GPT-5.6 Luna(클라우드)로 이전**하고, 임베딩(bge-m3)·검색·원본 저장은 로컬 유지하는 하이브리드로 전환한다. 저장은 **MD(사람이 읽고 편집 가능한 진실원) + 벡터(파생 인덱스)** 이중 구조로 재정의한다.

**전략 근거:** 프라이버시(로컬 저장·검색)를 유지해야 경쟁 우위가 있음. 생성만 선택적 클라우드로 빼면 하드웨어 부담↓·품질↑·프라이버시 대부분 유지. 모델은 프로토콜로 추상화해 교체 가능(락인 회피). 제공 모델은 Luna 단일, 추후 BYOK로 사용자 키/모델 선택.

**지원 파일:** PDF, MD, 이미지(png/jpg 등) / **미지원(추후):** docx, xlsx, 음성

| #   | 작업                                              | 상태     | 비고                                                        |
| --- | ------------------------------------------------- | -------- | ----------------------------------------------------------- |
| 7.1 | OpenAI API 키 Keychain 저장                       | 완료     | BYOK 기반, 키는 앱 번들에 심지 않음. KeychainHelper         |
| 7.2 | LunaChatEngine (OpenAI Chat Completions 스트리밍) | 완료     | ChatEngineProtocol 준수, 검색·컨텍스트·인용 재사용          |
| 7.3 | 설정: AI 제공자 선택 + API 키 입력                 | 완료     | 로컬 Qwen ↔ GPT-5.6 Luna, 런타임 전환. AISettingsView      |
| 7.4 | 엔진 선택/전환 배선 (AppState/AppDelegate)         | 완료     | 설정 기반 엔진 구성, 폴백 유지. configureChatEngine        |
| 7.4.1 | AICredentials 계층 키 리졸버                       | 완료     | 키체인(BYOK) → (DEBUG).env → (미래)프록시. 릴리즈 컴파일 제외 |
| 7.5 | MD 진실원 저장 계층                                | 대기     | Luna로 요약·구조화 → .md 저장, 편집 가능                    |
| 7.6 | MD 백그라운드 생성 (지연 처리)                     | 대기     | 캡처 즉시 로컬 OCR로 검색 가능, Luna MD는 온라인 시 보강    |
| 7.7 | OCRProcessor 프로토콜화 + Luna 비전 이해            | 대기     | AppleVision(로컬) 기본 + CloudVisionOCR(Luna) 선택, Windows 확장 대비 |
| 7.8 | MD 수정 시 재임베딩 (bge-m3)                        | 대기     | MD=진실원 → 벡터는 파생, 편집 시 해당 항목만 재임베딩       |
| 7.9 | 이미지+메모+메타데이터 → Luna 통합 이해            | 대기     | 단일 호출로 OCR+이해+맥락+태깅 → MD 생성                    |

**결정:** 생성=Luna(클라우드), 임베딩=bge-m3(로컬 유지), OCR=로컬 기본+Luna 선택, MD 생성=백그라운드/지연. (상세 §28 D36~)

---

## Phase 6 — 계정·결제 인프라 + 배포 (출시 선행 조건) `대기`

**배포 모델 확정(2026-08-31):** **App Store 미배포**. 브라우저에서 .dmg 다운로드 + 웹 대시보드(회원가입·플랜·결제) + 딥링크 로그인. 이유: App Store는 App Sandbox 필수라 AX 기반 "어디서나 캡처"가 막힘. 상세는 `docs/monetization-architecture.md`.

**플랜:** BYOK(사용자 키, 서버 미경유) / Free(제작자 키 + 쿼터, 프록시 경유) / Pro(고급 모델 구독). Free·Pro는 Supabase Auth + Edge Function 프록시 필요.

**순서 변경(2026-08-31):** "완성 후 공개 출시" 결정으로, 아래 인프라(6.6~6.8)는 **출시 후 검토**가 아니라 **출시 선행 조건**이다. Pro가 출시 첫날부터 동작해야 하므로 결제·세금·환불 처리까지 사전 준비한다. B(인프라)는 A(제품, Phase 7·5)와 병행하고, C(패키징)는 그 뒤, 마지막에 클로즈드 베타 → 공개 출시.

### B. 계정·결제 인프라 (Free/Pro 전제)

| #   | 작업                          | 상태 | 비고  |
| --- | ----------------------------- | ---- | ----- |
| 6.6 | Supabase Auth + Edge Function 프록시 | 대기 | Free/Pro 인증·쿼터·미터링·제작자 키 대리 호출 |
| 6.7 | 딥링크 로그인 (campsis:// URL 스킴) | 대기 | 웹 인증 → 앱 토큰 수신 → 키체인 저장 |
| 6.8 | 결제 연동 (LemonSqueezy/Paddle 등)  | 대기 | 웹 대시보드 결제 → 웹훅으로 플랜 반영, 세금·환불 처리 |
| 6.10 | 웹 대시보드 (가입·플랜·사용량)     | 대기 | 초기엔 앱 내 설정 + 결제사 관리페이지로 최소화 가능 |

### C. 패키징 & 배포

| #   | 작업                          | 상태 | 비고  |
| --- | ----------------------------- | ---- | ----- |
| 6.1 | Apple Developer Program 가입  | 대기 | Developer ID 서명·공증용 (App Store 아님) |
| 6.2 | 서명 + 공증 CI 파이프라인     | 대기 | Developer ID + notarytool, §19.3 |
| 6.3 | Hardware Tier별 모델 다운로드 | 대기 | §19.4 (로컬 모델 사용 시) |
| 6.4 | Sparkle 자동 업데이트         | 대기 | App Store 미배포 → 자체 업데이트 필수 |
| 6.5 | 랜딩/다운로드 페이지 + .dmg 호스팅 | 대기 | S3 / Cloudflare R2 등 |
| 6.9 | 릴리스 빌드 점검 (CI 자동)    | 대기 | .env/제작자 키 미포함 확인 포함 |

### D. 출시

| #   | 작업                          | 상태 | 비고  |
| --- | ----------------------------- | ---- | ----- |
| 6.11 | 클로즈드 베타 (20~30명)       | 대기 | 공개 출시 전 필수. 치명적 버그·UX 검증, Pro 결제 흐름 실검증 |
| 6.12 | 공개 출시                     | 대기 | ProductHunt/HN/디스콰이엇 등 (business-plan §5) |

**출시 후(Pro+, 별도 Phase):** iCloud 동기화, 내보내기(Obsidian/MD), 팀 공유 — 핵심 출시 스코프에서 제외.

---

## 변경 이력

| 날짜       | 변경 내용                                                                                                                              |
| ---------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-08-31 | **출시 전략 변경: MVP 점진 출시 → 핵심 기능 완성 후 공개 출시.** 순서 변경: Phase 6의 계정·결제 인프라(6.6~6.8)를 "출시 후 검토"에서 **출시 선행 조건**으로 이동. Phase 6을 B(인프라)/C(패키징)/D(출시)로 재구성, 웹 대시보드(6.10)·클로즈드 베타(6.11)·공개 출시(6.12) 신설. 빌드 순서 A(제품:7·5)∥B(인프라) → C → 베타 → 출시. 스코프: Pro+(동기화·내보내기·팀공유)는 출시 후로 분리. 영향: Supabase 프록시·결제·대시보드가 출시 크리티컬 패스에 편입 |
| 2026-08-31 | 배포·수익화 모델 확정: **App Store 미배포**, 브라우저 다운로드 + 웹 대시보드 + 딥링크 로그인. 플랜 BYOK/Free/Pro 3-티어(제작자 키는 Supabase Edge Function 프록시에만 보관). Phase 6 재정의(6.5~6.8 신설), "한눈에 보기" 6번 문구 수정. Phase 7.1~7.4 완료(Keychain, LunaChatEngine, AISettingsView, configureChatEngine 배선) + AICredentials 계층 키 리졸버(7.4.1) 추가. 상세 `docs/monetization-architecture.md` |
| 2026-08-31 | Phase 7 신설 & 착수: 클라우드 생성(GPT-5.6 Luna) 하이브리드 전환 + MD 지식베이스. 생성만 클라우드로 이전(하드웨어 부담↓·품질↑), 임베딩·검색·저장은 로컬 유지(프라이버시). MD=진실원+벡터=파생 이중저장. 지원 파일 PDF/MD/이미지로 확정(docx/xlsx/음성 보류). 7.1(Keychain)부터 착수 |
| 2026-08-31 | Phase 5.5 (UX 개선 1차) 완료. 스트리밍 답변, 생성 중지, 온보딩, 모델 상태 표시, Memories 검색, 캡처 피드백, 검색 임계값, 한국어 통일, semantic 색상/접근성. 메뉴바 빠른 메모 버그+단축키 충돌 수정. 커스텀 브랜드 색상은 시스템 색상으로 원복 유지 |
| 2026-08-26 | Phase 3.5 (MLX 통합) 완료. Qwen3-4B-4bit via MLXLLM ChatSession. Apple FM 폴백 유지. 컨텍스트 8K→128K 확장                              |
| 2026-08-26 | Phase 4.5 (Chat UI) 완료. SearchView → ChatView 대화형 UI로 전환, 대화 이력 DB 저장                                                    |
| 2026-08-26 | Phase 4 (Quick Note + File Upload) 완료. Voice Memo는 O5 미결정으로 보류. PDF Chunking은 Phase 5로 이동                                |
| 2026-08-26 | Phase 3 완료: Core ML Embedding, Vector Search, Search UI, RAG Answer, Citation, Memories View 구현. Reranker는 품질 실측 후 추가 예정 |
| 2026-08-26 | O1 해소: BAAI/bge-m3 확정 (MIT, fp16, 1081MB). O13 해소: Searchable Text 조합 확정. Phase 3에 3.0(Local Embedding) 추가                |
| 2026-08-26 | Phase 2 완료 (2.6 Embedding 스킵 — O1 미확정). OCR, Summary, Topics, Pipeline, Retry 구현                                              |
| 2026-08-26 | 초기 작성. Phase 0, 1 완료 반영. Phase 2 이후 PRD 기반으로 작성                                                                        |
