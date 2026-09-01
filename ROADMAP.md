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
| **7. 하이브리드 AI** | 클라우드 생성(Luna) + MD 지식베이스 + 비전 이해 | 무거운 생각만 클라우드에 맡기기 |

**현재 위치:** Phase 7 완료 — 클라우드 생성(GPT-5.6 Luna) + MD 지식베이스(진실원+파생벡터) + Luna 비전 통합 이해. 다음: Phase 5 도그푸딩 / Phase 6 인프라(계정·결제·대시보드) 병행

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

## Phase 3.5 — MLX LLM 통합 `완료` → `제거됨 (2026-09-01)`

Apple FM의 제한된 컨텍스트/품질 문제로 Qwen3-4B-4bit (MLX) 직접 통합했으나,
품질·하드웨어 부담·앱 용량 문제로 **2026-09-01 로컬 생성 LLM(MLX/Qwen·Apple FM)을 전면 제거**하고
생성/채팅을 GPT-5.6 Luna(클라우드) 단일로 일원화했다(D49). 아래는 이력 보존용 기록이다.

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

## Phase 7 — 클라우드 생성(Luna) + MD 지식베이스 `완료`

**배경:** 로컬 생성 모델(Qwen3-4B)은 품질 한계 + 소비자 하드웨어(RAM/용량) 부담이 큼. **무거운 "생성"만 GPT-5.6 Luna(클라우드)로 이전**하고, 임베딩(bge-m3)·검색·원본 저장은 로컬 유지하는 하이브리드로 전환한다. 저장은 **MD(사람이 읽고 편집 가능한 진실원) + 벡터(파생 인덱스)** 이중 구조로 재정의한다.

**전략 근거:** 프라이버시(로컬 저장·검색)를 유지해야 경쟁 우위가 있음. 생성만 선택적 클라우드로 빼면 하드웨어 부담↓·품질↑·프라이버시 대부분 유지. 모델은 프로토콜로 추상화해 교체 가능(락인 회피). 제공 모델은 Luna 단일, 추후 BYOK로 사용자 키/모델 선택.

**지원 파일:** PDF, MD, 이미지(png/jpg 등) / **미지원(추후):** docx, xlsx, 음성

| #   | 작업                                              | 상태     | 비고                                                        |
| --- | ------------------------------------------------- | -------- | ----------------------------------------------------------- |
| 7.1 | OpenAI API 키 Keychain 저장                       | 완료     | BYOK 기반, 키는 앱 번들에 심지 않음. KeychainHelper         |
| 7.2 | LunaChatEngine (OpenAI Chat Completions 스트리밍) | 완료     | ChatEngineProtocol 준수, 검색·컨텍스트·인용 재사용          |
| 7.3 | 설정: API 키 입력                                 | 완료     | ~~로컬 Qwen ↔ Luna 전환~~ → 로컬 LLM 제거(D49)로 Luna 단일. AISettingsView는 API 키 섹션만 |
| 7.4 | 엔진 선택/전환 배선 (AppState/AppDelegate)         | 완료     | 설정 기반 엔진 구성, 폴백 유지. configureChatEngine        |
| 7.4.1 | AICredentials 계층 키 리졸버                       | 완료     | 키체인(BYOK) → (DEBUG).env → (미래)프록시. 릴리즈 컴파일 제외 |
| 7.5 | MD 진실원 저장 계층                                | 완료     | 2026-09-01. Source에 markdown_path/status/updated_at, v5 마이그레이션, AppPaths/markdowns, LunaMarkdownGenerator, SourceDetailView 정리본/원본 세그먼트 |
| 7.6 | MD 백그라운드 생성 (지연 처리)                     | 완료     | 2026-09-01. 이후 7.7에서 Luna 단일 파이프라인으로 통합(캡처→Luna 1회 호출→MD→임베딩) |
| 7.7 | AppleVision OCR 제거 + Luna 단일 이해로 재정의      | 완료     | 2026-09-01. OCRProcessor.swift·Vision 의존성 제거. 캡처된 모든 소스를 Luna 비전+MD 단일 호출로 이해(OCR+요약+태그+MD). always-online 전제(offline/no-key 미지원) |
| 7.8 | MD 수정 시 재임베딩 (bge-m3)                        | 완료     | 2026-09-01. SearchableTextBuilder가 MD 우선, MD 생성/편집 시 해당 항목만 delete+재임베딩 (source당 벡터 1개 유지) |
| 7.9 | 이미지+메모+메타데이터 → Luna 통합 이해            | 완료     | 2026-09-01. LunaMarkdownGenerator가 스크린샷/이미지 파일을 비전 입력(data URL)으로 첨부 → 단일 호출로 OCR+이해+맥락+태깅→구조화 노트(title/summary/tags/markdown, JSON) |

**결정:** 생성=Luna(클라우드), 임베딩=bge-m3(로컬 유지), 이해(OCR/요약/태그/MD)=Luna 단일 호출, offline/no-key 미지원. (상세 §28 D36~)

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
| 6.3 | 임베딩 모델(bge-m3) 첫 실행 다운로드 + 진행률 | 대기 | 앱 번들 대신 첫 실행 시 원격에서 다운로드(재개 가능·무결성 검증). 진행률 %는 창 사이드바 하단 + 메뉴바에 표시(ModelStatus 재사용). **다운로더 인프라는 모델/에셋 업데이트에도 재사용.** 생성은 클라우드(Luna)라 Qwen 다운로드는 배포 대상 아님 |
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
| 2026-09-01 | **D1 마크다운 표/링크/이미지 렌더링.** 커스텀 `MarkdownTextView`에 GFM 파이프 표 지원 추가: 헤더+구분행(`\| --- \|`) 감지→`NSTextTable`로 셀 테두리·패딩·헤더 배경 렌더(CJK 폭 문제 없이 정렬). 링크 `[텍스트](url)`는 `.link` 속성으로 클릭 가능(NSTextView `linkTextAttributes`), 이미지 `![alt](src)`는 로컬 파일/파일 URL만 `NSTextAttachment`로 인라인 표시(최대 폭 360, 원격 http는 대체 텍스트). 표 렌더는 TextKit1 필요 → `layoutManager` 참조로 강제. 채팅 답변·정리본 미리보기·상세 모두 동일 렌더러라 일괄 적용. 빌드 통과 |
| 2026-09-01 | **UX 1차 개선 배치.** (A1) 인스펙터 미리보기 상단에 스크린샷/이미지 캡처본 노출. (A2) 인스펙터 폭 자유 조절(min 320·ideal 420·max 900). (A3) `InspectorToggleButton`으로 채팅·메모리 화면 어디서든 분할창 토글. (A4) 인스펙터 메모리 탭을 `MemoryRowView` 재사용으로 크게·명확하게. (B2) 정리본 복사 메뉴 2종(마크다운 원문/일반 텍스트) — 인스펙터 미리보기·메모리 상세 양쪽, `MarkdownClipboard` 헬퍼 추가. (C1) 채팅 입력을 커스텀 `ChatTextEditor`(NSTextView 기반)로 교체해 Enter=전송·Shift+Enter=줄바꿈, 자동 높이. (C2) 채팅방 진입 시 최하단(최근 대화)로 스크롤. 빌드·테스트 통과. 후속 예정: B1(인스펙터 메모리→상세 전환 UX 통일), B3(원본 편집→정리본 재생성+재벡터화, 텍스트 한정), D1(표/링크/이미지 렌더링), E1(문서 연결)·E2(마인드맵) |
| 2026-09-01 | **채팅 출처 UX 개선 + 인스펙터 분할 보기.** 답변 본문의 인라인 `[1]` 인용 제거(LunaChatEngine 지시문 변경 + `stripCitations`로 방어적 스트립, 레거시 메시지도 표시 직전 정리). 출처는 관련도순으로만 노출: `relevantSources`가 최상위 점수 대비 상대 마진(0.1)·절대 하한(0.4)을 적용해 무관한 출처가 무조건 5개 노출되던 문제 해결(LLM 입력·표시·저장에 동일 집합 사용). 오른쪽 `.inspector` 패널 신규(InspectorPanelView/SourcePreviewView): 말풍선 하단 출처 클릭 시 정리본(MD) 미리보기, 세그먼트로 메모리 목록↔정리본 전환. 채팅 툴바에 "메모리 패널" 토글(sidebar.right)로 메모리+채팅 동시 보기. AppState에 showInspector/inspectorSource/inspectorMode 추가. 인스펙터는 읽기전용, 편집은 기존 SourceDetailView 유지. 빌드·테스트 통과 |
| 2026-09-01 | **로컬 생성 LLM 전면 제거 (Qwen3-4B/MLX + Apple FM).** 채팅·생성을 Luna(클라우드) 단일로 일원화(D49). 삭제: MLXGenerator/AppleFMGenerator/TextGenerator/AppleFMChatEngine, ChatEngine.swift의 MLXChatEngine(ChatResponse/ChatEngineProtocol은 유지). AIProvider에서 `.local` 제거→`.luna`만, SettingsView는 엔진 선택 Picker 제거하고 API 키 섹션 상시 표시. CampsisApp: MLX 프리로드/mlxContainer 제거, modelStatus를 임베딩(bge-m3) 로드 기준으로 재정의, configureChatEngine은 키 있으면 Luna·없으면 nil(설정 안내). project.pbxproj에서 mlx-swift-lm·swift-huggingface 패키지 제거(swift-transformers는 임베딩 토크나이저용으로 유지). 디스크 HF 캐시의 Qwen 모델 3종(Qwen3-4B-4bit·Reranker-0.6B·Embedding-0.6B, 약 4.3G) 삭제. 효과: 앱 번들·의존성·메모리 사용 대폭 감소. 빌드·테스트 통과 |
| 2026-09-01 | **Luna 단일 이해 파이프라인 (AppleVision OCR 제거).** 7.7 재정의: OCRProcessor.swift·Vision 의존성 삭제, 로컬 요약/태그 생성(TextGenerator.analyze) 제거. ProcessingQueue는 캡처된 소스를 Luna 1회 호출로 이해(OCR+요약+태그+MD)→MD 저장→bge-m3 임베딩. MarkdownGenerator가 구조화 GeneratedNote(title/summary/tags/markdown, JSON response_format) 반환. CampsisApp 배선 정리(generator 인자 제거, updateMarkdownGenerator→processAllPending, MLX 프리로드는 로컬 채팅용으로 유지). 테스트를 MockMarkdownGenerator로 교체. 전제: always-online(offline/no-key 미지원). 트레이드오프: 모든 소스가 Luna 왕복 후 검색 색인(캡처 직후 짧은 지연) |
| 2026-09-01 | Phase 7 완료(7.7·7.9). OCRProcessing 프로토콜 + AppleVisionOCR로 OCR 추상화(Windows 확장 대비), LunaMarkdownGenerator가 스크린샷/이미지 파일을 비전 입력(base64 data URL)으로 첨부 → 단일 Luna 호출로 OCR+이해+맥락+태깅→MD(7.9). 로컬 Apple Vision OCR은 캡처 즉시 검색용으로 유지. Phase 7 전체 완료 → 상태 `완료`, 현재 위치 갱신 |
| 2026-09-01 | Phase 7.8 완료: MD 수정 시 재임베딩. SearchableTextBuilder가 MD(진실원) 있으면 MD 기준으로 검색 텍스트 구성, MD 자동생성(Luna) 및 수동편집(⌘S) 시 해당 소스만 delete→재임베딩(source당 벡터 1개 유지). 편집한 정리본이 즉시 의미검색에 반영됨. ProcessingQueue.reembedSource(id:) 추가 |
| 2026-09-01 | UX: 사이드바 계층화(메모리/채팅 섹션 분리) + 메모리 상세 흐름 개편. 상세를 모달(sheet)→인라인 푸시(NavigationStack)로 전환, 정리본(MD) 우선 표시 + 툴바 "편집/직접 작성"(⌘S 저장)으로 MD 직접 편집 가능, 원본은 세그먼트로 확인. MD 생성 속도 개선: LunaMarkdownGenerator에 reasoning_effort=low. Source에 Hashable 추가(navigationDestination). 주의: MD 편집 저장은 파일·메타데이터만 갱신하며 검색 재임베딩은 7.8에서 처리 |
| 2026-09-01 | Phase 7.5·7.6 완료: MD(진실원) 저장 계층 + 백그라운드 생성. Source에 markdown_path/markdown_status/markdown_updated_at 추가(v5-markdown 마이그레이션), AppPaths.markdowns 디렉터리, MarkdownGenerator 프로토콜 + LunaMarkdownGenerator(gpt-5.6-luna), ProcessingQueue.generateMissingMarkdown(캡처 즉시 OCR+임베딩 → MD는 온라인+Luna 구성 시 지연 보강), SourceDetailView "정리본(MD)/원본" 세그먼트로 원본 소스 즉시 확인. provider=local이면 MD 생성 건너뜀. 7.8(MD 편집 재임베딩)은 대기 |
| 2026-09-01 | UX: Dock 앱 지원 강화 — 상단 앱 메뉴바 명령(새 채팅 ⌘N/빠른 메모 ⌘⇧N/메모리 열기 ⌘⇧M), Dock 아이콘 우클릭 메뉴, reopen 시 창 앞으로, 사이드바 하단 AI 상태(다운로드 % 포함)+설정 진입점, 빈 상태 한국어 통일. Phase 6.3 재정의: 임베딩 모델(bge-m3) 첫 실행 다운로드+진행률(다운로더는 업데이트에도 재사용), Qwen 다운로드는 배포 제외(생성=클라우드) |
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
