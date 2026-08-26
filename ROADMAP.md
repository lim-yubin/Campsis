# Campsis Roadmap

마지막 업데이트: 2026-08-26

---

## 한눈에 보기

Campsis는 6단계에 걸쳐 만들어집니다.

| Phase              | 한줄 요약                           | 비유                          |
| ------------------ | ----------------------------------- | ----------------------------- |
| **0. 모델 평가**   | 어떤 AI 두뇌를 쓸지 테스트          | 시험지 만들어서 후보생 시험   |
| **1. 캡처**        | 사용자가 보고 있는 것을 가져오기    | 카메라 + 메모장 설치          |
| **2. 처리**        | 가져온 것을 AI가 이해하기           | 사진 속 글자 읽기, 요약, 분류 |
| **3. 검색**        | "그거 뭐였지?" 하면 찾아주기        | 개인 비서에게 물어보기        |
| **3.5. 고급 AI**   | 답변 품질이 부족할 때 더 큰 AI 투입 | 비서를 전문가로 교체          |
| **4. 추가 입력**   | 메모, 음성, 파일도 기억             | 메모장 + 녹음기 + 파일함 추가 |
| **5. 실사용 검증** | 직접 써보면서 다듬기                | 시범 운영                     |
| **6. 배포**        | 다른 사람도 쓸 수 있게 출시         | 앱스토어 오픈                 |

**현재 위치:** Phase 4 진행중 — Quick Note + File Upload 완료, Voice Memo 보류

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

## Phase 3.5 — MLX 도입 (조건부) `대기`

Phase 3의 Answer 품질이 불충분할 경우에만 수행.

| #     | 작업                                      | 상태 | 비고   |
| ----- | ----------------------------------------- | ---- | ------ |
| 3.5.1 | MLXGenerator 구현                         | 대기 | §11.3  |
| 3.5.2 | Hardware Tier 감지 + 모델 선택            | 대기 | §11.9  |
| 3.5.3 | 모델 다운로드 + 진행률 UI                 | 대기 |        |
| 3.5.4 | Model Residency 정책 (온디맨드 로드/해제) | 대기 | §11.10 |
| 3.5.5 | Hardened Runtime entitlements 검증        | 대기 | §19.3  |
| 3.5.6 | Apple FM ↔ MLX 품질 비교                  | 대기 |        |

---

## Phase 4 — Additional MVP Capture `진행중`

| #   | 작업             | 상태     | 비고                                       |
| --- | ---------------- | -------- | ------------------------------------------ |
| 4.1 | Quick Note       | 완료     | ⌥⇧Space → QuickNotePopup → Source(note)   |
| 4.2 | Voice Memo (STT) | **대기** | Phase 4.5로 보류 (O5 미결정)               |
| 4.3 | File Upload      | 완료     | Drag&Drop + File Picker, PDF/TXT/MD/이미지 |
| 4.4 | PDF Chunking     | **대기** | 현재 단일 Source, Phase 5에서 페이지 분할   |

---

## Phase 5 — Dogfooding / Optimization `대기`

| #   | 작업                                       | 상태 | 비고              |
| --- | ------------------------------------------ | ---- | ----------------- |
| 5.1 | 1~2주 실제 사용                            | 대기 |                   |
| 5.2 | Capture frequency 측정                     | 대기 |                   |
| 5.3 | Search failure 사례 수집                   | 대기 |                   |
| 5.4 | 임베딩 품질 재평가 (Phase 0 하니스 재실행) | 대기 | O1 최종 확정 시점 |
| 5.5 | 모델 성능/속도/메모리 측정                 | 대기 | §21               |
| 5.6 | Shortcut UX 개선                           | 대기 |                   |
| 5.7 | OCR 실패 사례 분석                         | 대기 |                   |

---

## Phase 6 — Distribution `대기`

| #   | 작업                          | 상태 | 비고  |
| --- | ----------------------------- | ---- | ----- |
| 6.1 | Apple Developer Program 가입  | 대기 |       |
| 6.2 | 서명 + 공증 CI 파이프라인     | 대기 | §19.3 |
| 6.3 | Hardware Tier별 모델 다운로드 | 대기 | §19.4 |
| 6.4 | Sparkle 자동 업데이트         | 대기 |       |
| 6.5 | 결제 + 오프라인 라이선스 검증 | 대기 | §19.5 |
| 6.6 | 릴리스 빌드 점검 (CI 자동)    | 대기 |       |

---

## 변경 이력

| 날짜       | 변경 내용                                                                                                                              |
| ---------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-08-26 | Phase 4 (Quick Note + File Upload) 완료. Voice Memo는 O5 미결정으로 보류. PDF Chunking은 Phase 5로 이동 |
| 2026-08-26 | Phase 3 완료: Core ML Embedding, Vector Search, Search UI, RAG Answer, Citation, Memories View 구현. Reranker는 품질 실측 후 추가 예정 |
| 2026-08-26 | O1 해소: BAAI/bge-m3 확정 (MIT, fp16, 1081MB). O13 해소: Searchable Text 조합 확정. Phase 3에 3.0(Local Embedding) 추가                |
| 2026-08-26 | Phase 2 완료 (2.6 Embedding 스킵 — O1 미확정). OCR, Summary, Topics, Pipeline, Retry 구현                                              |
| 2026-08-26 | 초기 작성. Phase 0, 1 완료 반영. Phase 2 이후 PRD 기반으로 작성                                                                        |
