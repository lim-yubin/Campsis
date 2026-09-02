# Campsis Roadmap

마지막 업데이트: 2026-09-02

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
| **8. 메모+LLM위키** | 정리본을 토픽별 위키로 종합 + MCP | 흩어진 메모를 살아있는 위키로 |

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

## Phase 8 — 메모 + LLM 위키 + MCP `진행중`

> **구현 상세 스펙: [`docs/phase8-llm-wiki.md`](docs/phase8-llm-wiki.md)** — 데이터 모델·라우팅 알고리즘·재합성 프롬프트·UI 상태·엣지 케이스·미결 질문(OW1~OW6)은 이 문서를 정본으로 참조한다. (아래 표는 요약)

**한줄 요약:** 정리본(메모)을 **토픽별 위키로 승격·종합**해, 캡처가 쌓일수록 스스로 풍부해지는 개인 지식베이스를 만들고, 채팅·검색·MCP가 이 위키를 우선 활용하도록 한다. (비개발자용 LLM Wiki — Karpathy "LLM wiki" 패턴을 소비자용으로 재해석)

**목표 인터랙션 모델(확정):**
- 사용자 표면은 **메모 / 나의 위키 / 채팅** 3개. "위키 엔진"은 숨긴다.
- **메모(정리본)** = raw→MD, 자동 생성·항상 검색됨.
- **위키** = 사용자가 **명시적으로 승격**한 메모들을 **종합한 문서**(폴더가 아니라 한 장의 종합 노트).
- 승격은 **메모함에서 배치 큐레이션**(체크 → "위키에 정리" → 라우팅 미리보기 → 실행), 실행 시 **즉시 증분 재합성**(위키당 1회, 백그라운드 상태).
- 채팅은 **위키 우선 검색 → 메모 드릴다운**, 출처는 위키/메모 구분.
- MCP는 **위키만** read.

**데이터 모델(신규):** `Wiki`(토픽 허브=종합 MD, 위키 우선 검색 대상), `NoteWikiLink`(메모↔위키 다대다), `WikiWikiLink`(위키↔위키 관련 토픽 백링크, 마인드맵 기반). 위키 페이지 구조 = `종합 요약 / 핵심 포인트 / 관련 위키(백링크) / 구성 메모 목록`. 위키 MD도 파일 진실원(D39 방식).

| #    | 작업                                                          | 상태 | 비고                                                                 |
| ---- | ------------------------------------------------------------- | ---- | -------------------------------------------------------------------- |
| 8.1  | 데이터 모델·마이그레이션 (`Wiki`·`NoteWikiLink`·`WikiWikiLink`) | 완료 | 2026-09-02. v8 마이그레이션(+`wiki_revision`·`wiki_embedding`), `Wiki.swift` 모델, `WikiRepository`, `AppPaths` 위키 디렉터리. 임베딩은 FK 제약상 별도 `wiki_embedding` 테이블. 테스트 7종 추가·통과 |
| 8.2  | 메모 메뉴에 "위키 미주입/주입됨" 구분 + 소속 위키 배지         | 완료 | 2026-09-02. `MemoriesView`에 위키 주입 세그먼트 필터(전체/미주입/주입됨, 위키 존재 시만 노출) + 행에 소속 위키 배지(book 칩, 최대 3+오버플로). `WikiRepository.membershipTitles()` 단일조회 맵 |
| 8.3  | 승격 UX: 체크박스 선택 + "위키에 정리" 버튼                     | 완료 | 2026-09-02. 툴바 "위키에 정리" → 선택 모드(미주입만 체크 가능, 주입됨은 딤), 하단 액션바(전체 선택/해제·선택 개수·"위키에 정리"), `WikiPromotionSheet` 스캐폴드(선택 메모 확인, 위치 정하기는 8.4에서 연결) |
| 8.4  | 라우팅 미리보기: 기존 위키 매칭(임베딩)→목적지 제시·수정, 없으면 새 위키 후보 | 완료 | 2026-09-02. `WikiRouter`(0.7·코사인+0.3·태그자카드, T_high 동적/T_low 0.40, N_max 3, centroid 폴백) + `WikiPromotionSheet` 라우팅 미리보기(목적지 요약칩·메모별 목적지 편집·새 위키 토글). 테스트 4종. 실행은 8.5 |
| 8.5  | 승격 실행: 소속 등록 + 백링크 생성(즉시)                       | 완료 | 2026-09-02. `WikiPromoter`: 새 위키 생성(slug 중복 재사용)·소속 등록·공동소속 백링크. 새 위키 `pending`(재합성 대기). 시트 "정리 실행" 연결, `WikiPromotionResult`(addedByWiki)로 8.6 인계. 테스트 3종 |
| 8.6  | 증분 재합성 파이프라인: 위키별 1회, `[페이지+새 메모]`만 Luna 전달, 백그라운드 상태 | 완료 | 2026-09-02. `LunaWikiSynthesizer`(통합·비append·충실성·모순표시, JSON) + `WikiResynthesizer` 액터(위키별 1회·스냅샷·재임베딩·related_topics 백링크·사람편집 보호). 승격 후 백그라운드 트리거. 테스트 3종 |
| 8.7  | 나의 위키 메뉴: 리스트 + 상세(종합/구성메모/관련위키)          | 완료 | 2026-09-02. 사이드바 "나의 위키" + `WikiListView`(리스트·정리중 배지·빈상태) + `WikiDetailView`(종합 MD 렌더·구성메모→인스펙터·관련위키 이동·복사). `.wikiUpdated` 알림으로 자동 새로고침 |
| 8.8  | 채팅: 위키 우선 검색 → 메모 드릴다운 + 출처 배지(위키/메모)     | 완료 | 2026-09-02. `VectorSearchEngine.searchWikis`(위키 페이지 임베딩 대상), `LunaChatEngine` 위키 우선→메모 드릴다운(위키 구성 메모는 컨텍스트 제외), 출처=`ChatReference`(위키/메모)·토큰 직렬화, 칩에 위키/메모 배지+클릭 시 위키는 나의 위키로 열기(`.openWiki`) |
| 8.9  | 사이드바 검색 대상에 위키 페이지 추가                          | 대기 | Phase 6 의미검색 확장(작음)                                          |
| 8.10 | 사람 편집 보호: 위키 페이지 수동 편집 시 자동 재합성 덮어쓰기 방지 | 대기 | `markdownEdited` 개념 위키로 확장                                    |
| 8.11 | 위키 유지보수(Lint): 중복 위키 병합 제안·모순·고아 감지        | 대기 | 관리자 부재 대비 필수 인프라. "정리 제안" 카드                       |
| 8.12 | MCP 서버: 위키만 read + 공개/비공개 권한 스코핑                | 대기 | 위키 신선도(8.11) 전제                                               |
| 8.13 | (추후) 마인드맵/지식 지도 — 백링크 그래프 시각화              | 대기 | 기존 E2(D51). 기본 숨김                                              |

**설계 결정/원칙:**
- **비용:** 증분 재합성 + 위키당 1회 + 명시적 배치 트리거 + `reasoning_effort: low`. (자동·건건 재합성 금지)
- **재합성 타이밍:** "위키에 정리" 버튼 클릭 시 **즉시** 수행(사용자가 요청한 배치라 비용 통제). 단 백그라운드 + "정리 중" 상태로 비차단.
- **신뢰:** 승격은 사용자 명시적, 라우팅 미리보기로 결과 예측, 사람 편집 위키 보호, 조용한 버전/되돌리기.
- **무마찰:** 캡처·정리본은 자동, 큐레이션은 별도.
- **차별점:** "위키=종합"(폴더 아님)이 유일한 해자. 채팅이 위키 우선으로 이 가치를 소비.

**리스크:** ①토픽 폭발·중복(8.4 매칭+8.11 병합) ②재합성 품질/환각(충실성 규칙·출처 추적) ③관리자 부재→위키 부패(8.11 Lint 필수) ④대규모 비용(승격당 목적지 위키 수 상한).

**의존성/순서:** `8.1 → 8.2·8.3·8.4·8.5 → 8.6 → 8.7 → 8.8·8.9 → 8.10 → 8.11 → 8.12 → 8.13`. 기존 자산 재사용: `LunaMarkdownGenerator`·`ProcessingQueue`·`VectorSearchEngine`, MD 진실원+파생벡터(D39), Phase 3 출처 칩·Phase 6 검색. 기존 **D51(E1·E2 보류)** 를 "note↔topic-hub" 방식으로 구체화.

---

## 변경 이력

| 날짜       | 변경 내용                                                                                                                              |
| ---------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-09-02 | **8.8 채팅 위키 우선 검색 완료.** `Search/VectorSearchEngine.swift`에 `searchWikis(query:topN:minScore:)` 추가(위키 페이지 임베딩 OW2 대상 코사인 검색, `WikiSearchResult` 반환) 및 `wikiRepository` 의존성 추가. `Chat/ChatEngine.swift`: `ChatReference`(kind=wiki/memo, id·title·score, `token`="wiki:<id>"/"memo:<id>") + `ChatResponse.sources`→`references`로 교체. `Chat/LunaChatEngine.swift`: `gatherHits`로 **위키 우선 검색 → 메모 드릴다운**(위키가 이미 요약한 구성 메모는 컨텍스트에서 제외, 메모는 최대 3개 보완), 시스템 프롬프트에 WIKI/MEMO 구분 명시, 컨텍스트 조립 위키(마크다운 본문)→메모 순. `CampsisApp`: 참조 토큰을 `sourceIds`로 저장(레거시 plain id=메모 하위호환). `UI/ChatView.swift`: 토큰 파싱→`ChatReference` 캐시. `UI/MessageBubbleView.swift`: 출처 칩에 `위키`/`메모` 배지(위키=chatAccent 책 아이콘)+클릭 시 메모는 인스펙터·위키는 `.openWiki`로 나의 위키에서 상세 push. `MainContentView`+`WikiListView`가 `.openWiki`/`pendingWikiId`로 위키 상세 이동. 테스트: `ChatWikiReferenceTests`(토큰 포맷·관련성 컷오프) |
| 2026-09-02 | **8.7 나의 위키 메뉴 완료.** 사이드바 라이브러리에 "나의 위키"(`books.vertical`) 항목 + `SidebarSection.wiki`. `UI/WikiListView.swift`: 위키 리스트(제목·요약·구성 메모 수·관련 위키 수·최근 갱신, `정리 중`/`실패` 상태 배지), 빈 상태 안내, 값 기반 내비게이션. `UI/WikiDetailView.swift`: 헤더(제목·요약·"메모 N개로 만들어졌어요"·정리중), 종합 MD 렌더(`MarkdownTextView`, 중복 H1 제거), 관련 위키 칩(탭→해당 위키 push), 구성 메모 목록(탭→인스펙터 미리보기), 마크다운/일반텍스트 복사(`MarkdownClipboard`)+토스트. `.wikiUpdated` 알림(재합성 완료·승격 직후 발행)으로 리스트·상세 자동 새로고침. `source.md`에 "나의 위키" 소비자 소개 추가 |
| 2026-09-02 | **8.6 증분 재합성 완료(플로우 D.2).** `Processing/WikiSynthesizer.swift`: `WikiSynthesizer` 프로토콜 + `LunaWikiSynthesizer`(GPT-5.6, `reasoning_effort: low`, `json_object`). 프롬프트 §6 — `[현재 페이지 + 새 메모]`만 전달(증분·비용 선형), 단순 append 금지·종합 재구성, 충실성(환각 금지·세부 보존), 사용자 편집 존중, 모순 인라인 표시, 언어 자동 매칭. 출력 `{markdown, summary, related_topics}`. `Processing/WikiResynthesizer.swift`(actor): 위키별 1회 재합성 — status `.processing`→`writeMarkdown`(쓰기 직전 OW4 스냅샷)→`.completed`, 위키 페이지 재임베딩(OW2, `wiki_embedding`), `related_topics`→기존 위키 slug 매칭 시 양방향 `wiki_wiki_link`(weight 0.8). **사람 편집 보호(§10·8.10 선반영):** `markdownEdited` 위키는 자동 덮어쓰기 스킵. 첫 종합 실패→`.failed`, 기존 내용 있으면 유지. `AppState.wikiResynthesizer` 배선(키 변경 시 `updateWikiSynthesizer`), 승격 시트가 D.1 즉시 반영 후 `Task.detached`로 D.2 백그라운드 트리거(비차단). 테스트 3종(MD 작성·완료, related 백링크, 편집보호 스킵) |
| 2026-09-02 | **8.5 승격 실행 완료(플로우 D.1).** `Processing/WikiPromoter.swift`: 확정된 목적지별로 (1) 새 위키 생성 — `topic_slug` 정규화 후 동일 슬러그 위키가 있으면 재사용(중복 방지), 없으면 `pending` 상태로 신규 생성(재합성 8.6 대기) (2) `note_wiki_link` 소속 등록(match_score 저장, member_count 갱신) (3) 한 메모가 여러 위키로 간 경우 그 위키들끼리 양방향 `wiki_wiki_link` 백링크(co-membership, weight 1.0). `WikiPromotionRequest`(목적지·메모·점수)/`WikiPromotionResult`(addedByWiki·createdWikiIds → 8.6 재합성 인계). `WikiPromotionSheet` "정리 실행" 버튼 활성화(배정 메모 ≥1)·백그라운드 실행·완료 시 목록/배지 즉시 갱신. 테스트 3종(새 위키+링크·슬러그 재사용·공동소속 백링크). 종합 MD 재작성은 8.6 |
| 2026-09-02 | **8.4 라우팅 미리보기 완료.** `Processing/WikiRouter.swift`: 정리본→기존 위키 매칭. 신호 = `0.7·코사인(위키 페이지 임베딩, 없으면 구성 메모 centroid 폴백) + 0.3·태그 자카드(위키 제목/슬러그+구성 메모 topics)`. 2단 밴드(자동선택 ≥T_high, 후보 T_low~T_high) + 콜드스타트 동적 T_high(0~2:0.65 / 3~4:0.60 / 5+:0.55), T_low=0.40, N_max=3. 매칭 없으면 대표 토픽으로 새 위키 제안. LLM 비호출(저장 임베딩 재사용). `WikiPromotionSheet` 확장: 상단 목적지 요약칩(기존/신규·개수·새 위키 제목 편집), 메모별 후보 칩으로 목적지 추가/제외(멀티토픽), 미분류 경고. `AppState` 재주입으로 시트 환경 보장. 테스트 4종(T_high 스케일·slug·jaccard·콜드스타트 새 위키). 승격 실행(링크+백링크)은 8.5, 재합성은 8.6 |
| 2026-09-02 | **8.3 승격 선택 UX 완료.** `MemoriesView`: 툴바 "위키에 정리"(checklist) → 선택 모드 진입(자동으로 미주입 필터 전환). 행마다 체크 서클, 미주입만 선택 가능(주입됨 딤 처리). 하단 `selectionActionBar`(전체 선택/해제·"N개 선택됨"·borderedProminent "위키에 정리"). "위키에 정리" → `WikiPromotionSheet`(선택 메모 목록 확인 컨테이너, 실제 목적지 매칭/승격은 8.4·8.5·8.6에서 채움). 취소/닫힘 콜백으로 선택 모드 종료·목록 새로고침 |
| 2026-09-02 | **8.2 메모함 위키 구분·소속 배지 완료.** `MemoriesView`: 위키가 1개 이상일 때만 상단에 세그먼트 필터(전체/위키 미주입/위키 주입됨) 노출, `matchesWikiFilter`로 그룹핑 반영. 각 메모 행(`MemoryRowView`)에 소속 위키 배지(chatAccent book.closed 칩, 최대 3개+`+N` 오버플로). `WikiRepository.membershipTitles()`(위키 제목 맵×note_wiki_link 단일 조회)로 소스별 소속 위키 표시. `AppState`에 `wikiRepository` 배선 |
| 2026-09-02 | **8.1 데이터 모델·마이그레이션 완료(Phase 8 착수).** v8 마이그레이션: `wiki`(토픽 허브 메타)·`note_wiki_link`(메모↔위키 다대다)·`wiki_wiki_link`(위키 백링크)·`wiki_revision`(OW4 되돌리기 스냅샷)·`wiki_embedding`(OW2 위키 페이지 임베딩) 테이블 + 인덱스. `Storage/Wiki.swift`(Wiki·NoteWikiLink·WikiWikiLink·WikiRevision·WikiEmbeddingRecord 모델), `Storage/WikiRepository.swift`(CRUD·MD쓰기+스냅샷·링크·member_count·리비전 링버퍼·임베딩), `AppPaths`에 wiki_markdowns·wiki_revisions 추가. **구현 이탈:** 위키 임베딩은 기존 `embedding.source_id` FK(cascade) 제약상 `kind` 컬럼 대신 동형 별도 테이블 `wiki_embedding`으로 분리(노트 파이프라인 무간섭·FK 정합). 위키↔소스 삭제 시 링크·임베딩 FK cascade 자동 정리. 테스트 7종 추가, 빌드·전체 테스트 통과 |
| 2026-09-02 | **OW5 Lint 트리거 확정: 이벤트 기반 국소(주) + 저빈도 전수(보조), LLM 비호출.** 시점 ①위키 메뉴 진입 ②승격/재합성 완료 직후 해당 위키(piggyback) ③앱 유휴 시 하루 최대 1회 전수(마지막+24h & 위키 변경 있을 때, ProcessingQueue 잡). 비용: 중복(벡터)·고아(DB)·stale(날짜) 로컬 0 + 모순은 재합성 piggyback 추가 0 → 별도 LLM Lint 잡 없음. 결과는 비파괴 제안 카드 + dismiss 재알림 쿨다운. MVP는 ①② 우선, ③ 후순위. 상세 `docs/phase8-llm-wiki.md` OW5·§8. **→ 이로써 Phase 8 미결 질문 OW1~OW6 전부 확정, 착수 준비 완료** |
| 2026-09-02 | **OW4 되돌리기 방식 확정: MD 스냅샷.** git 유사 이력 폐기(비개발자 과잉·취약, §10 요구는 원클릭 되돌리기지 VCS 아님). 위키 MD 쓰기 직전 이전 버전을 `wiki_revision` 테이블 + `wiki_revisions/{wikiId}/{id}.md`(기존 AppPaths 상대경로 패턴)로 보관, 위키당 최근 N=10 링버퍼. 되돌리기=직전 MD 복원+재임베딩, 승격이면 `added_source_ids`로 그 배치 링크만 제거+member_count 복구. UI: 완료 토스트 원클릭 되돌리기, 위키 상세 "기록"은 후순위. 상세 `docs/phase8-llm-wiki.md` OW4·§4·§10 |
| 2026-09-02 | **OW6 자동 추천 강도 확정: 배지만 표시(자동 체크 ✗) + 옵트인 넛지.** 경계 원칙 정립 — "무엇을 올릴지=사용자, 어디로 갈지=시스템(C.3, OW3)". 메모 목록(B)에선 T_high 이상 확신 매칭만 추천 배지 표시하고 프리셀렉트 안 함(§2 "위키는 사용자가 승격한 것만" 준수). 사장·콜드스타트는 "정리 안 된 메모 N개·추천 묶음 보기" 옵트인 배너로 완화(클릭 시 batch 프리필→라우팅 미리보기, 자동 커밋 없음). 배지/넛지 off 가능. 상세 `docs/phase8-llm-wiki.md` OW6·§3B |
| 2026-09-02 | **OW2 위키 대표 임베딩 확정: 위키 페이지 임베딩.** (centroid 아님) 근거: 채팅·MCP가 어차피 페이지 임베딩을 요구→추가 인프라 0·유지 대상 단일화, 위키=종합 문서이므로 그 문서 임베딩이 의미상 정확, centroid는 멀티토픽 drift로 매칭 저하, 요약이라 8k 토큰 truncation 위험 낮음. 폴백: 재합성 전 위키만 구성 메모 centroid 임시 사용. 스키마: `embedding` 테이블에 `kind`(note/wiki) 추가 + source_id→ref_id 일반화. 상세 `docs/phase8-llm-wiki.md` OW2·§4·§5 |
| 2026-09-02 | **OW3 임계값 확정.** 현행 앱 bge-m3 코사인 스케일(채팅 관련성 하한 0.4·검색 0.3·의미검색 0.25) 기준. 매칭 신호=`0.7·코사인+0.3·태그겹침`. **2단 밴드:** T_high=0.55(자동 선택)·T_low=0.40(후보 제시, relevanceFloor와 정렬), 사이=사용자 선택, 미만=새 위키. **콜드스타트:** T_high를 위키 수로 스케일(0~2→0.65, 3~4→0.60, 5+→0.55). **T_merge=0.80** 또는 topic_slug 일치(병합 제안, 보수적). **N_max=3**(메모당 목적지 상한). 모두 초기값 → `match_score` 로그로 사후 튜닝, 라우팅 미리보기 수락/거절이 라벨. 상세 `docs/phase8-llm-wiki.md` OW3·§5·§8 |
| 2026-09-02 | **OW1 토픽 체계 확정: 임계값 기반 하이브리드.** 순수 반통제형(B) 폐기 — 사용자가 어떤 성격의 데이터를 넣을지 모르는데 기존 위키에 강제 편입하면 주제가 한쪽으로 쏠림·왜곡되기 때문. 대신 정리본 임베딩↔기존 위키 유사도의 임계값(T_match)으로 발현형/편입을 자동 분기: ≥T_match면 기존 위키 편입 제안, 중간 점수면 후보 K개 사용자 선택, 어디에도 <T_match면 강제 편입 없이 "새 위키 만들기" 제안(라우팅 미리보기 C.3에서 명시 승인). 콜드스타트(위키 0~2개)엔 T_match를 높여 새 위키 유도→성숙 시 낮춰 편입 유도, 한 위키 과다 집중 시 Lint가 분할 제안. 상세 `docs/phase8-llm-wiki.md` OW1·§5 |
| 2026-09-02 | **Phase 8(메모 + LLM 위키 + MCP) 신설.** Karpathy "LLM wiki" 패턴을 비개발자용으로 재해석해 로드맵에 추가. 정리본(메모)을 사용자가 명시적 배치 큐레이션(체크→"위키에 정리"→라우팅 미리보기→실행)으로 **토픽별 위키에 승격**, 실행 시 **즉시 증분 재합성**(위키당 1회, 백그라운드)해 종합 문서를 만든다. 표면은 메모/나의 위키/채팅 3개, 엔진은 숨김. 채팅은 위키 우선→메모 드릴다운, 사이드바 검색은 위키+메모, MCP는 위키만 read. 데이터 모델 신규(`Wiki`·`NoteWikiLink`·`WikiWikiLink`), 위키 페이지=종합요약/핵심포인트/관련위키(백링크)/구성메모. 유지보수(Lint)·사람 편집 보호·토픽 중복 병합을 필수 인프라로 포함. 기존 D51(E1·E2)을 "note↔topic-hub"로 구체화. 상세 결정은 §28 D53. (설계만 확정, 미구현) |
| 2026-09-02 | **핵심 UX/UI 개선 6종 배치(메모리·정리본·원본·채팅 출처·검색).** (P1) 메모리 열기 인터랙션 통일 — 인스펙터 미리보기(`SourcePreviewView`) 헤더에 `전체 보기`/`원본`/`원문 열기` 승격 액션 추가, 미리보기→편집 가능한 `SourceDetailView`를 시트로 연결(`SourceDetailView(initialTab:)` 파라미터 추가), 채팅 출처·인스펙터 메모리 목록에 현재 미리보기 항목 선택 하이라이트. (P2) `SourceDetailView`를 정리본 주 화면 + 원본 보조 토글(`원본 보기 (N자)` ↔ `정리본으로`)로 재구성, 편집 모델 라벨 명확화(원본 수정→정리본 재생성=주 경로, 정리본 직접수정=고급). (P3) `MessageBubbleView`의 접힘형 `출처 N개`를 항상 보이는 컴팩트 칩 행으로 교체(타입 아이콘+제목, 클릭→미리보기, 관련도순, `+N개 더보기`, `FlowLayout` 재사용). (P4) `MemoryRowView`에 1줄 요약 스니펫 + 주제 태그 미니칩 + 스크린샷/이미지 썸네일 + 선택 하이라이트. (P5) OCR/전사/요약/원본 내용 GroupBox에 복사 버튼 + 공용 `복사되었습니다` 토스트 modifier(`copyToast`, 상세·미리보기 일관 적용; 채팅은 기존 인라인 체크마크 유지). (P6) 사이드바 전역 검색을 `VectorSearchEngine` 의미검색으로 승격(`AppState.searchEngineRef` 노출, 350ms 디바운스, 텍스트 정확일치+의미유사 병합) + `이 검색어로 채팅하기` 브리지(`pendingChatPrefill`→새 채팅 입력창 프리필). **참고:** P1의 SourceViewer 완전 통합은 회귀 위험이 커 미리보기→상세 시트 브리지로 대체(상세 편집 로직은 `SourceDetailView` 단일 유지). 파일 간 변경이 얽혀 Phase별 독립 커밋 대신 단일 커밋으로 반영. 빌드 통과 |
| 2026-09-02 | **사이드바 상단 툴바 정리 + 너비 제어.** 새 채팅 버튼을 대화 섹션 헤더에서 사이드바 상단 툴바의 아이콘 묶음(`[토글][작성]`, `topIconCluster`)으로 이동 — 시스템 사이드바 토글을 숨기고(`.toolbar(removing: .sidebarToggle)`) 커스텀 토글(`columnVisibility` 제어)로 대체해 순서·간격을 직접 지정, 호버 배경 지원(`ToolbarIconButton`). 접힘 시에도 디테일 툴바에 동일 묶음 유지. 사이드바 너비는 `navigationSplitViewColumnWidth`가 macOS에서 강제되지 않아, 하부 `NSSplitViewItem`의 min/max 두께(240~340)를 `NSViewRepresentable`(`SidebarWidthLimits`)로 직접 강제 — 접었다 펼칠 때 max가 리셋되는 문제는 `columnVisibility` 변화 토큰 + 지연 재적용으로 보정. 메인(디테일) 최소 너비 520 지정. 빌드 통과 |
| 2026-09-02 | **사이드바 라이브러리 재설계(캔버스 방향 반영).** 사이드바를 상단 검색창 + `라이브러리`(전체 기억·오늘·텍스트·스크린샷·메모·음성·파일) + `대화`(헤더 + 버튼) 구조로 재구성. 필터 소유권을 사이드바로 이전: `SidebarSection.memories`→`.library(LibraryItem)`, 기존 `SourceFilter`→`LibraryItem`(label·systemImage 추가). `MemoriesView`는 `filter`/`searchText` 바인딩을 받아 내부 필터 드롭다운·검색필드 제거(달력·개수·가져오기 유지), navigationTitle에 필터명 표시, `오늘`은 onAppear에서 오늘 날짜로 초기화. 사이드바 검색은 전역 검색으로 동작(입력 시 `.library(.all)`로 전환해 결과 표시). 상단 "새 채팅" 버튼은 대화 섹션 헤더의 + 로 이동. 개수 표시는 이번 범위 제외. 빌드·테스트 통과 |
| 2026-09-02 | **B1 → 스킵.** 인스펙터 `메모리` 탭에서 항목 탭 시 `SourceDetailView`를 push로 통일하려던 작업(embedded 옵션 + NavigationStack). 시제품 구현 후 사용자가 불필요하다고 판단해 되돌림 — 인스펙터는 현행대로 채팅 출처 미리보기(정리본) + 메모리 목록 읽기전용 스왑 유지, 전체 상세/편집은 메모리 메뉴에서 수행하는 흐름으로 충분. 커밋 전 로컬 상태에서 revert되어 코드 변경 없음. E1(문서 연결)·E2(마인드맵)은 계속 별도 Phase 보류 |
| 2026-09-02 | **B3 원본 편집 → 정리본 재생성 + 재벡터화.** 텍스트 계열(selectedText/note/file) 원본을 상세 화면 '원본' 탭에서 직접 편집 가능(이미지/음성 제외). 저장 시 `ProcessingQueue.regenerate(id:newContent:)` 호출 → 원본 저장 후 `processSource` 재사용으로 Luna가 제목/요약/태그/MD 재생성 → MD 기준 재임베딩(7.8 파이프라인 활용). `SourceDetailView`: 원본 편집기(TextEditor)+저장/취소, 재생성 중 정리본 탭에 진행 표시, 완료 후 최신 소스/MD 자동 로드. 편집·재생성 중 탭 전환/마크다운 편집 버튼 비활성화. **정리본 직접 수정 기능은 유지**(용도 구분: 정리본 수정=표현 다듬기, 원본 편집=내용 변경). **덮어쓰기 경고 추가**: `markdown_edited` 컬럼(v7)로 수동 편집 여부 추적(수동 저장 시 true, Luna 생성 시 false) → 직접 수정한 정리본이 있는 상태에서 원본을 저장하면 재생성 전 확인 alert. 빌드·테스트 통과 |
| 2026-09-02 | **B5 메모리 리스트 타이틀 명확화.** 그동안 버려지던 Luna 생성 제목(`GeneratedNote.title`)을 저장하도록 개선: `source` 테이블에 `title` 컬럼 추가(v6 마이그레이션), `ProcessingQueue`가 처리 시 `source.title = note.title` 저장. 공용 `Source.displayTitle`(우선순위: 생성 제목→요약→창 제목→본문 첫 줄→유형명, 첫 줄만 80자로 정리) 도입해 리스트·인스펙터·채팅 출처·상세 헤더 제목 로직을 통일(기존엔 원본 content 앞 80자를 그대로 노출). 기존 메모리는 title이 없어 요약으로 폴백(원본 잘림보다 개선), 신규 캡처부터 생성 제목 표시. 빌드·테스트 통과 |
| 2026-09-01 | **채팅 답변 링크·출처 정확도 개선.** (1) 답변을 항상 `MarkdownTextView`로 렌더(평문 산문도 동일하게 보이며 URL 링크 확실히 동작) — SwiftUI Text+NSDataDetector 방식은 macOS 클릭 미동작으로 폐기. (2) 평문 URL 자동 링크화 + 굵게(`**...**`) 내부 URL도 재귀 파싱해 링크화(모델이 URL을 굵게 감싸 링크가 안 되던 문제). 링크 색/밑줄을 속성에 직접 지정하고, `Coordinator`(NSTextViewDelegate)로 클릭 시 `NSWorkspace.open`. (3) 무관한 답변에 출처·복사 버튼이 뜨던 문제: `sources(for:from:)`가 답변이 `💡 메모리에 관련 정보가 없어`로 시작하면 출처를 비움 + 규칙2 강화("유사도≠관련성, 메모리 미사용 시 마커 필수"). `MarkdownTextView`/`MessageBubbleView`/`ChatView`(스트리밍 말풍선 아바타 제거)/`LunaChatEngine` 수정. 빌드 통과 |
| 2026-09-01 | **채팅 답변 UX 정리.** (1) 말풍선 아바타(브레인/사람 아이콘) 제거, 어시스턴트 답변은 전체 폭 사용(사용자 메시지는 우측 정렬·최대 600 유지). (2) 답변 형식 분기: 출처(메모리) 연결된 답변만 마크다운 렌더+복사 버튼, 무관한 일반 답변은 평문 채팅. (3) 복사 버튼을 말풍선 하단 왼쪽→내부 우측 상단 아이콘 오버레이로 이동. (4) 프롬프트 튜닝(규칙5): "항상 마크다운" → 기본 대화체 평문, 구조(헤딩·표·불릿·단계)는 내용상 이득 있을 때만 사용 — 도입부 대화 문장이 문서처럼 과도하게 구조화되던 문제 완화. `MessageBubbleView`/`LunaChatEngine` 수정. 빌드 통과 |
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
