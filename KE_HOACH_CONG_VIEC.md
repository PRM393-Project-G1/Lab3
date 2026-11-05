# Kế hoạch công việc — Realtron: "Hiểu nhanh bài báo qua danh sách tham khảo"

> **Mobile app Flutter, chỉ Android — sản phẩm cuối là file `.apk`** + Firebase + 2 công cụ có sẵn: **RefChecker** (Python) và **Saffron** (Java).
> Kế hoạch bám theo yêu cầu của thầy trong `achive/`:
> - **PRM393 Lab 3** — Cloud-Enabled Mobile App: Firebase 6 dịch vụ, ARTEMIS, AI Code Review.
> - **PRM393 Final** — One Complete System on Firebase: web admin, phân quyền, Gemini.
> - **Lab 3 Preparation Guide**.
>
> Các chỗ đánh dấu ⚠️ là việc **cần hỏi thầy trước khi làm** (xem mục 0).
>
> **Phân công:** phần Stitch → Figma → Flutter `.apk` có kế hoạch chi tiết riêng trong [PHAN_VIEC_FLUTTER.md](PHAN_VIEC_FLUTTER.md).
>
> **Đã chốt (05/11/2026):** SE196414 phụ trách code, tự commit và push, chạy backend, và nhiều khả năng làm luôn Firebase. Thành viên khác làm slide. Repo nhóm: `PRM393-Project-G1/Lab3` (đề ghi `PRM393_Lab03_<StudentID>`, cần hỏi thầy).

---

## 0. Cần hỏi thầy trước (làm ngay, trước mọi việc khác)

| # | Câu hỏi | Vì sao |
|---|---|---|
| Q1 | ✅ **Đã xong:** thầy cho phép làm Lab 3 với RefCheck + Saffron theo Ý tưởng 1. Nhóm **làm lại Stitch → Figma** đúng yêu cầu | Lab 3 mục 3: đổi đề tài cần thầy duyệt và phải làm lại thiết kế Lab 2 |
| Q2 | ✅ **Đã xong:** app gọi BE (RefChecker + Saffron) qua **Tailscale**, giống Lab 2. Thầy đã cho phép | Lab 3 yêu cầu nguồn dữ liệu được thầy duyệt |
| Q3 | ✅ **Chốt gói Spark (05/11/2026):** nhóm chỉ demo một lần. [Tài liệu Firebase](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024) ghi Spark không có bucket Cloud Storage, nên app lưu PDF trên máy và không có upload. Có thể mất điểm mục Cloud Storage (0.25) | Lab 3: "Spark plan is enough" |
| Q4 | ✅ **Dùng Google ARTEMIS:** tên file ghi Patrol, nhưng nội dung và bảng điểm đều ghi ARTEMIS. Commit đã ghim nằm trong `app/e2e_test/README.md` | Ảnh hưởng toàn bộ phần E2E test (1.5 điểm) |
| Q5 | ✅ Làm theo **nhóm**. Còn phải hỏi: tên repo (đề ghi `PRM393_Lab03_<StudentID>`), số commit/số ngày tối thiểu `[N]` | Mục 11 Lab 3 |

---

## 1. Ý tưởng & phạm vi

**Luồng chính:** người dùng nhập arXiv ID → RefChecker kiểm tra từng reference → lấy văn bản của các reference đọc được → Saffron rút chủ đề và dựng cây chủ đề → app hiển thị.

**Người dùng thấy:**
- Bài báo dựa trên **những mảng kiến thức nào**, hiển thị dạng cây chủ đề.
- Mỗi chủ đề có bao nhiêu reference, và **bao nhiêu trong số đó bị lỗi hoặc bịa**.
- Chủ đề nào **"yếu"**, tức phần lớn reference trong đó có vấn đề.

**Persona** (viết lại từ Lab 2):
- **P01 Linh:** sinh viên năm cuối phải trình bày một bài báo lạ ở seminar.
- **P02 TS. Hùng:** người phản biện cần bằng chứng.
- **P03 Khoa** (persona hỗ trợ): người chạy BE trên laptop và đưa địa chỉ Tailscale cho nhóm, giữ như Lab 2.

**Tiêu chí thành công (gợi ý):** từ lúc có kết quả, trong vòng 2 phút người dùng chỉ ra được 3 mảng kiến thức chính và chủ đề yếu nhất của bài.

### 3 user flow (chi tiết từng bước trong `PHAN_VIEC_FLUTTER.md` mục A.2)

| Flow | Đường chính | Nhánh thay thế | Nhánh lỗi / khôi phục |
|---|---|---|---|
| **A. Phân tích một bài báo** | Analyze → nhập arXiv ID → Analysis in progress (5 bước) → Paper overview | Bài đã có kết quả thì mở ngay; share link từ trình duyệt; push "Analysis complete" | Sai định dạng; **không tới được server** (Tailscale tắt, BE không chạy) → Retry / Change server; phân tích thất bại → Try again; offline; Cancel có xác nhận |
| **B. Tìm chủ đề yếu** | Overview → Topic map → "Weak only" → Topic detail → Reference detail → Copy fix | Chạm thẳng chủ đề yếu từ Overview; đi xuống chủ đề con | Không có chủ đề yếu → empty; reference không có nội dung → "Unclassified"; lỗi tải → Retry |
| **C. Xem lại & xuất báo cáo** | History → Overview → "Report" → tạo PDF → upload (có tiến độ) → link | Tìm kiếm, đổi tên; mở từ Notifications | Upload thất bại → Retry; lịch sử rỗng / lỗi; xoá có xác nhận |

### Màn hình (12 màn; Lab 3 yêu cầu ≥ 8)

Bottom nav 3 tab: **Analyze · History · Profile**. Các màn:
0. Connect server — dùng lại từ Lab 2; hiện sau lần đăng nhập đầu, đổi lại được trong Profile
1. Sign-in
2. Analyze
3. Analysis in progress
4. Paper overview
5. Topic map
6. Topic detail
7. Reference list
8. Reference detail
9. History
10. Notifications
11. Profile, có khu Firebase demo

Overlay: sheet Export report, dialog Likely fabricated, các dialog xác nhận.

---

## 2. Kiến trúc: BE qua Tailscale + Firebase (gói Spark)

App gọi BE trên laptop của nhóm qua **Tailscale**, giống Lab 2. BE là một service FastAPI nhỏ ("Orchestrator") điều phối RefChecker và Saffron. Kết quả và tiến độ được BE ghi vào **Firestore**, app nghe realtime từ đó.

```
┌─────────────────────┐  (1) POST /api/analyses {arxivId}         ┌──────────────────────────────┐
│ Flutter app (.apk)  │ ── HTTP qua Tailscale (100.x.x.x:8000) ─► │ Laptop nhóm (Tailscale)      │
│ MVVM + Provider     │    + header Firebase ID token             │ Orchestrator (FastAPI)       │
│                     │                                           │  ├─ RefChecker  (Docker)     │
│ Auth · Storage · FCM│                                           │  ├─ lấy văn bản reference    │
│ Analytics · Crash · │                                           │  └─ Saffron     (Docker)     │
│ Remote Config       │                                           └──────────────┬───────────────┘
└───┬─────────────▲───┘                                                          │ (2) ghi progress, kết quả,
    │             │ (3) nghe realtime analyses/{arxivId}                         │     notification + gửi FCM
    │             └──────────────────────────┐                                   │     (firebase-admin)
    │ Auth, library, reports, notifications  │     ┌───────────────┐             │
    └───────────────────────────────────────►└─────┤   Firestore   │◄────────────┘
                                                   └───────────────┘
```

**Quyết định thiết kế:**

1. **App → BE chỉ để ra lệnh** qua Tailscale:
   - `GET /api/health` cho màn Connect server.
   - `POST /api/analyses` để bắt đầu phân tích.
   - `POST /api/analyses/{id}/cancel` để huỷ.

   BE xác thực Firebase ID token gửi kèm, nên người ngoài tailnet không gọi được, và người trong tailnet cũng phải đăng nhập mới gọi được.
2. **Tiến độ và kết quả đi qua Firestore**, không đi qua HTTP hay WebSocket. Lợi ích:
   - App có realtime và offline cache mà không phải viết thêm.
   - History và kết quả cũ **vẫn xem được khi laptop tắt hoặc Tailscale mất kết nối**.
   - Lab 3 yêu cầu dữ liệu của người dùng nằm trên Firestore.
   - Push FCM gửi từ BE bằng Admin SDK, chạy được trên gói Spark.
3. **Kết quả lưu theo arXiv ID** (`analyses/{arxivId}`) và dùng chung cho mọi người dùng. Bài đã phân tích thì mở ngay mà không cần gọi BE (nhánh thay thế của Flow A). Nhờ vậy ARTEMIS test chạy nhanh và ổn định.
4. **Reference bịa thì không có toàn văn.** Mỗi reference vào Saffron dưới dạng một "document", lấy văn bản theo thứ tự ưu tiên:
   `toàn văn (arXiv / open-access PDF)` → `abstract (RefChecker enrichment)` → `tiêu đề trích dẫn + câu ngữ cảnh trích dẫn trong bài gốc`.
   Nếu không làm vậy, reference lỗi/bịa sẽ không thuộc chủ đề nào và chỉ số "chủ đề yếu" luôn sai.
5. **Logic nghiệp vụ nằm trong ViewModel** (quy tắc MVVM của Lab 3). Firestore chỉ lưu số đếm. Việc xác định chủ đề nào "yếu" do ViewModel tính, dùng ngưỡng lấy từ **Remote Config**: đổi ngưỡng trên Console thì app đổi theo mà không cần build lại.
6. **PDF được tạo ngay trên máy** bằng package `pdf`, nội dung là những gì người dùng đang xem. Sau đó upload lên `reports/{uid}/...`.
   Bài Final bỏ Cloud Storage: khi đó chỉ lưu file trên máy, chia sẻ bằng `share_plus`, và lưu metadata vào Firestore.

### Mô hình dữ liệu Firestore

```
users/{uid}
  displayName, photoUrl, createdAt, fcmTokens[]
  role: user | admin                         ← dùng cho bài Final
users/{uid}/notifications/{id}               ← trung tâm thông báo trong app
  title, body, type, analysisId, createdAt, read
users/{uid}/reports/{id}                     ← metadata file PDF đã xuất
  analysisId, storagePath, downloadUrl, sizeKb, createdAt
users/{uid}/library/{arxivId}                ← màn History (đổi tên, xoá chỉ ảnh hưởng tới user này)
  customTitle, addedAt, lastOpenedAt

analyses/{arxivId}                           ← kết quả dùng chung; chỉ BE ghi (Admin SDK)
  requestedBy (uid), aiAssisted (bool), createdAt,
  status: queued | processing | done | failed | cancelled,
  paperTitle, paperAuthors[], progress{stage, percent, message},
  summary{totalRefs, verified, warning, error, hallucinated, unverified,
          textFull, textAbstract, textContextOnly}, finishedAt, error
analyses/{arxivId}/references/{refId}
  index, title, authors[], year, venue, url,
  status (hallucination > error > warning > verified/unverified),
  issues[{type, message, cited, actual}], hallucination{verdict, explanation},
  textSource, topicIds[]
analyses/{arxivId}/topics/{topicId}
  term, parentId, depth, score, refIds[] (cộng dồn từ chủ đề con),
  counts{total, verified, warning, error, hallucinated, unverified}

announcements/{id}                           ← bài Final (hộp thư)
```

**Rules:**
- Người dùng chỉ đọc/ghi tài liệu của chính mình trong `users/{uid}/**`.
- `analyses/**` cho đọc khi đã đăng nhập; client không được ghi (BE ghi qua Admin SDK, không bị rules chặn).
- `storage.rules`: `reports/{uid}/**` chỉ chủ sở hữu được đọc/ghi.
- Tuyệt đối không dùng `if true`.

### Cấu trúc repo (theo mục 9 của Lab 3)

```
PRM393_Lab03_<ID>/
├── README.md              # đề tài, nguồn dữ liệu, cách chạy app + test + backend (Tailscale), version, AI tools, link video
├── lib/
│   ├── main.dart
│   ├── models/            # Analysis, RefItem, Topic, Request, AppNotification (freezed)
│   ├── services/          # AnalysisService, ReportService (PDF), ShareService
│   ├── firebase/          # AuthService, FirestoreService, StorageService, MessagingService,
│   │                      # AnalyticsService, CrashlyticsService, RemoteConfigService
│   ├── viewmodels/        # mỗi màn hình 1 ViewModel + 1 sealed state (loading/empty/error/data)
│   ├── screens/
│   ├── widgets/           # component Lab 2: button, text field, card, nav, app bar, dialog, loading/empty/error
│   ├── theme/             # ColorScheme, TextTheme, spacing/radius/elevation constants
│   └── utils/
├── e2e_test/              # ARTEMIS: conftest.py, pyproject.toml, test_auth/analysis/topics/export/profile.py
├── android/               # có google-services.json (được phép commit)
├── firebase/              # storage.rules, firestore.rules, firestore.indexes.json, remote-config-defaults.json
├── backend/               # Orchestrator FastAPI + docker-compose (RefChecker, Saffron) + saffron-config.json
│                          #   + HUONG_DAN_TAILSCALE.md; không commit mã RefChecker/Saffron (dùng Docker image / submodule)
├── docs/                  # design-traceability, architecture, analytics-plan, test-plan, code-review
├── evidence/              # ảnh Console, DebugView, Crashlytics, trace ARTEMIS
├── report/Lab03_<ID>.pdf
└── slides/Lab03_<ID>_slides.pdf
```

> Thư mục `backend/` nằm ngoài cấu trúc gợi ý của thầy, nên phải giải thích lý do trong `docs/architecture.md` (Lab 3 cho phép đổi cấu trúc nếu có giải thích).

---

## 3. Các giai đoạn & phân chia công việc

**Thứ tự bắt buộc** (Lab 3 mục 4, git history phải thể hiện đúng thứ tự):
Plan → Architect → Integrate → Instrument → Test → Review → Report.
Đặt tiền tố commit theo giai đoạn, ví dụ `[S3-auth] ...`, để thầy dễ đối chiếu.

**Vai trò** (gán người theo nhóm):
- `UI`: thiết kế
- `FE`: Flutter
- `FB`: Firebase / instrumentation
- `BE`: pipeline
- `QA`: ARTEMIS / review

Khi thầy vấn đáp, **mỗi thành viên** có thể bị yêu cầu chạy một test ARTEMIS, đổi một giá trị Remote Config, giải thích một ViewModel và một quyết định code review. Vì vậy mỗi người nên tự sở hữu ít nhất 1 ViewModel và 2–3 test case.

### GĐ 1 — Làm lại thiết kế: Stitch → Figma

> Lab 3 dùng sản phẩm thiết kế làm đặc tả: file Figma 6 page (01 User Flow · 02 Wireframe · 03 Final UI · 04 Design System · 05 Components · 06 Prototype), `DESIGN.md`, `flutter-handoff.md`.
> Nhóm làm lại theo **đúng quy trình Lab 2** (`../lab2/code/Lab2/ux/ai-design-log.md`).
> **Chi tiết từng bước, prompt mẫu, danh sách component: [PHAN_VIEC_FLUTTER.md](PHAN_VIEC_FLUTTER.md) Phần A + B.**

| ID | Công việc | Vai trò | Đầu ra |
|---|---|---|---|
| 1.1 | Viết lại persona, tiêu chí thành công, sitemap, 3 user flow A/B/C | UI | `persona.md`, `user-flow.md` |
| 1.2 | Stitch: project mới (Mobile · Standard), Prompt 1→2→3 → v1 → phản biện ≥ 5 phát hiện → Prompt 1b → R0–R3 → v2 | UI | `ux/stitch/v1`, `v2`, `ai-design-log.md` |
| 1.3 | `design-decisions.md`: chấp nhận / sửa / bỏ, kèm bảng contrast và accessibility | UI | Quyết định thiết kế |
| 1.4 | Copy to Figma → dựng đủ 6 page; Variables/Styles; component có đủ trạng thái; prototype 3 flow gồm nhánh thay thế và nhánh lỗi | UI | Link Figma công khai |
| 1.5 | Viết `flutter-handoff.md`: 6 mục mỗi màn + Bảng token → Flutter + Bảng component → widget | UI + FE | Handoff |

### GĐ 2 — Stage 1: Design traceability

| ID | Công việc | Vai trò | Đầu ra |
|---|---|---|---|
| 2.1 | Ánh xạ mọi màn hình, flow, component của Lab 2 sang route, widget và nguồn dữ liệu Flutter, kèm cột trạng thái | FE | `docs/design-traceability.md` |
| 2.2 | Quy ước: mọi chỗ app lệch khỏi Figma đều ghi vào file này kèm lý do, đồng thời cập nhật lại Figma | Cả nhóm | (duy trì suốt dự án) |

### GĐ 3 — Stage 2: Kiến trúc & theme

| ID | Công việc | Vai trò | Đầu ra |
|---|---|---|---|
| 3.1 | `flutter create --platforms=android`; khoá hướng dọc, `minSdk` 23; cài **Provider** (giống Lab 2), go_router; ghim version trong `pubspec.yaml` | FE | Khung project |
| 3.2 | Viết `docs/architecture.md`: cây thư mục (mỗi thư mục 1 dòng), sơ đồ tầng (Mermaid), **1 sequence diagram cho Flow A**, bảng ViewModel ↔ service | FE | `architecture.md` |
| 3.3 | `lib/theme/`: ColorScheme, TextTheme, hằng số spacing/radius/elevation lấy từ handoff. **Cấm** hard-code màu, cỡ chữ, padding trong screen | FE | Theme |
| 3.4 | `lib/widgets/`: mỗi component Lab 2 là 1 widget, variant và state truyền qua tham số. Thêm `StatusChip`, `StatusBar` (thanh tỷ lệ lỗi), `TopicTreeNode` | FE | Thư viện widget |
| 3.5 | Mẫu sealed state `ViewState<T> = Loading / Empty / Error / Data` dùng chung cho mọi ViewModel | FE | `viewmodels/view_state.dart` |

### GĐ 4 — Stage 3: Firebase setup & Authentication

| ID | Công việc | Vai trò | Đầu ra |
|---|---|---|---|
| 4.1 | Tạo Firebase project, đăng ký app Android, thêm **SHA-1 của khoá ký APK**, tải `google-services.json`. Làm theo `app/firebase/README.md` | FB | `google-services.json` |
| 4.2 | `AuthService` với Google Sign-In; router chuyển màn hình theo auth state (chưa đăng nhập → Login, đã đăng nhập → Analyze); hủy đăng nhập thì hiện thông báo; đăng xuất thì xoá dữ liệu cục bộ của user | FE + FB | Đăng nhập chạy được |
| 4.3 | Tạo `users/{uid}` ở lần đăng nhập đầu | FB | |
| 4.4 | Viết `firestore.rules` + `storage.rules` (mục 2); test bằng Emulator | FB | `firebase/` |
| 4.5 | Tạo **1 tài khoản Google riêng để test** (dùng cho ARTEMIS, không dùng tài khoản cá nhân) | QA | Tài khoản test |
| 4.6 | Bằng chứng: ảnh 2 trạng thái đăng nhập + tab Users trên Console | FB | `evidence/auth/` |

### GĐ P — Backend qua Tailscale (BE, làm song song từ GĐ 2 trở đi)

| ID | Công việc | Đầu ra |
|---|---|---|
| P.0 | Cài Tailscale trên laptop chạy BE và điện thoại/emulator của cả nhóm; cố định địa chỉ (IP `100.x` hoặc MagicDNS); cập nhật `HUONG_DAN_TAILSCALE.md` từ Lab 2 | Tailnet của nhóm |
| P.1 | Chạy RefChecker bằng Docker; lấy Semantic Scholar API key và key LLM; chạy `refchecker-webui check --paper 1706.03762 --json --check-hallucinations`, lưu JSON mẫu | `backend/samples/` |
| P.2 | Ghi lại schema JSON thực tế (status, issues, hallucination, abstract, ngữ cảnh trích dẫn) | `backend/docs/refchecker_schema.md` |
| P.3 | ✅ Đã build (JDK 25) và chạy được. **Máy chủ model gốc đã chết (404):** POS model tải từ bản sao của Apache, mô hình dựng cây train lại; xem `app/backend/README.md`. Ghi chú cũ: Build Saffron. pom trộn target Java 1.8 và 16 nên cần JDK ≥ 16; thử JDK 17. Lần đầu tải khoảng 3GB model. **Giới hạn 2 ngày**; quá hạn thì dùng docker-compose sẵn có của Saffron | Saffron chạy được |
| P.4 | `saffron-config.json` cho corpus nhỏ: chế độ `TAXO`, `oneTopicPerDoc: true`, `minTermFreq: 1`, `maxTerms ≈ 40` | Config |
| P.5 | Orchestrator FastAPI. **Hợp đồng API với FE:**<br>• `GET /api/health` → `{status, version}`<br>• `POST /api/analyses {arxivId, aiAssisted}` → `{analysisId, status}` (đã có kết quả thì trả `done` ngay)<br>• `POST /api/analyses/{id}/cancel`<br>Xác thực Firebase ID token ở header `Authorization: Bearer` | `backend/app/` |
| P.6 | Job chạy nền: cập nhật `progress` → RefChecker → lấy văn bản theo 3 nguồn ưu tiên → tạo `corpus.json` → chạy Saffron → merge `doc-terms.json` + `taxonomy.json` thành `topics/` (cộng dồn từ chủ đề con, nhóm Unclassified) → ghi batch (≤ 500 thao tác/batch) | `backend/app/jobs/` |
| P.7 | Khi xong: ghi `users/{uid}/notifications` + gửi **FCM** tới `fcmTokens` (Admin SDK); khi lỗi: `status=failed` kèm thông báo dễ hiểu | |
| P.7b | Unit test cho bước merge; `docker-compose.yml` chạy cả 3 service bằng 1 lệnh | `backend/tests/` |
| P.8 | **Phân tích trước 5–10 bài demo** để Firestore luôn có dữ liệu thật cho phát triển, ARTEMIS và video | Dữ liệu demo |

> Lab 3 cấm dữ liệu giả trong bản nộp. Dữ liệu dùng lúc phát triển phải là dữ liệu thật từ P.8, không được hard-code.

### GĐ 5 — Stage 4: Tính năng (mọi flow Lab 2, đủ trạng thái)

| ID | Công việc | Vai trò | Ghi chú |
|---|---|---|---|
| 5.1 | Sign-in → Connect server (lần đầu): nhập địa chỉ Tailscale, "Test connection" gọi `/api/health`, các thông báo lỗi riêng cho từng nguyên nhân (giống Lab 2); cho phép HTTP cleartext tới dải IP Tailscale trong `network_security_config.xml` | FE | A |
| 5.2 | Analyze + `AnalyzeViewModel`: kiểm tra và chuẩn hoá arXiv ID (`1706.03762`, `arxiv.org/abs/...`, `/pdf/...`); đã có `analyses/{id}` thì mở ngay, chưa có thì gọi `POST /api/analyses`; ghi `users/{uid}/library`; Recent checks | FE | A |
| 5.3 | Nhận link được share từ trình duyệt (`receive_sharing_intent`) và điền sẵn vào Analyze | FE | A, điểm nhấn mobile |
| 5.4 | Analysis in progress: stepper 5 bước nghe `analyses/{id}.progress`; "Try again" khi `failed`; Cancel gọi `/cancel` | FE | A, nhánh lỗi |
| 5.5 | Paper overview: thẻ cảnh báo nặng nhất, stacked bar 5 trạng thái (có Semantics label), thẻ Topics | FE | A/B |
| 5.6 | Topic map + `TopicMapViewModel`: dựng cây từ danh sách phẳng, tính chủ đề yếu theo ngưỡng Remote Config, lọc "Weak only", nhóm Unclassified; từ cấp 4 trở xuống mở màn con | FE | B |
| 5.7 | Topic detail → Reference list → Reference detail (Cited / Actual, Copy fix, dialog Likely fabricated) | FE | B |
| 5.8 | History (`users/{uid}/library`); "Report": `ReportService` tạo PDF → `StorageService` upload `reports/{uid}/...` có tiến độ → link → lưu `users/{uid}/reports` | FE + FB | C |
| 5.9 | Notifications, Profile + khu Firebase demo | FE | |
| 5.10 | Mọi màn có tải dữ liệu đều có loading, empty, error + retry; nút Back hoạt động ở mọi màn; mất mạng không làm crash app | FE | Tiêu chí chấm điểm |

### GĐ 6 — Stage 5: Instrumentation (Analytics, Crashlytics, Remote Config, FCM)

| ID | Công việc | Vai trò | Đầu ra |
|---|---|---|---|
| 6.1 | **Viết `docs/analytics-plan.md` trước khi viết code tracking** (bảng mục 5, ≥ 7 sự kiện, ánh xạ vào từng bước của flow) | FB | Analytics plan |
| 6.2 | `AnalyticsService`: log sự kiện, `setUserId` sau khi đăng nhập, bật debug mode; chụp DebugView cho **từng** sự kiện | FB | `evidence/analytics/` |
| 6.3 | `CrashlyticsService`: gắn handler lỗi Flutter, user ID, custom key (`arxiv_id`, `screen`). Ghi **non-fatal từ lỗi thật**, ví dụ upload PDF thất bại hoặc parse dữ liệu analysis lỗi. Nút **test crash** trong khu demo | FB | Ảnh dashboard |
| 6.4 | `RemoteConfigService` với giá trị mặc định trong app (`remote-config-defaults.json`): `weak_topic_threshold` (0.5), `weak_topic_min_refs` (3), `max_recent_checks` (10), `enable_report_export` (true). Đổi trên Console thì app đổi mà không cần build lại | FB | Ảnh trước/sau |
| 6.5 | `MessagingService`: xin quyền thông báo (Android 13+); nhận ở cả 3 trạng thái foreground / background / terminated; lưu vào trung tâm thông báo; bấm vào mở đúng Paper overview của bài | FB + FE | Ảnh 3 trạng thái |
| 6.6 | Mỗi dịch vụ đều xử lý lỗi (mất mạng, bị từ chối quyền, người dùng hủy) bằng thông báo hiển thị, không crash | FB | |

### GĐ 7 — Stage 6: Test plan & ARTEMIS E2E

| ID | Công việc | Vai trò | Đầu ra |
|---|---|---|---|
| 7.1 | Cài ARTEMIS (Python 3.12+, uv, ADB, key model đa phương thức); **ghim commit** trong README | QA | Môi trường |
| 7.2 | Thêm `Semantics` label cho các nút, item danh sách, biểu đồ, node cây | FE | |
| 7.3 | Viết `docs/test-plan.md`: danh sách flow quan trọng ↔ màn hình; ≥ 10 test case (mục 6) | QA | Test plan |
| 7.4 | Viết pytest dùng `ArtemisClient`, nhóm theo tính năng; **assert trên giá trị agent trả về** (số reference, tên chủ đề, giá trị Remote Config), không chỉ kiểm tra `SUCCESS`; các test độc lập, không phụ thuộc thứ tự | QA | `e2e_test/` |
| 7.5 | Chạy mỗi test ≥ 3 lần (profile Flash); lập bảng pass rate; giải thích mọi test flaky/fail và cách sửa | QA | `evidence/artemis/` |
| 7.6 | ≥ 1 test kiểm tra sự kiện analytics đã được log (Logcat hoặc DebugView) | QA | |
| 7.7 | 1 phiên **exploratory 15–30 phút** (profile Pro) + danh sách lỗi tìm được | QA | Báo cáo |

### GĐ 8 — Stage 7: AI code review

| ID | Công việc | Vai trò | Đầu ra |
|---|---|---|---|
| 8.1 | Mở pull request, chạy CodeRabbit / Copilot review / SonarCloud, lưu output | QA | |
| 8.2 | Ghi ≥ 5 finding gắn với file:line, thuộc ≥ 2 loại (bug, security, vi phạm MVVM, performance, thiếu test, maintainability) | QA | `docs/code-review.md` |
| 8.3 | Mỗi finding ghi quyết định: chấp nhận / điều chỉnh / từ chối, kèm lý do dẫn tới yêu cầu cụ thể trong handout hoặc tác động đo được | Cả nhóm | |
| 8.4 | Sửa ≥ 3 finding, **mỗi finding một commit có ghi ID** (ví dụ `fix(CR-02): ...`); liệt kê mọi AI tool đã dùng | FE | Commit đã link |

### GĐ 9 — Stage 8: Báo cáo, slide, video, APK

| ID | Công việc | Vai trò |
|---|---|---|
| 9.1 | `flutter build apk --release` → `app-release.apk`, ký bằng khoá debug của máy build (nhóm chỉ demo một lần); thử cài trên điện thoại thật | FE |
| 9.2 | Báo cáo PDF 8–12 trang theo mục 9 Lab 3; mọi khẳng định "chạy được" đều có ảnh hoặc link bằng chứng | Cả nhóm |
| 9.3 | Slide 12–15 trang: so sánh Figma với app, MVVM, từng dịch vụ Firebase, kết quả ARTEMIS, code review | Cả nhóm |
| 9.4 | Video 5–10 phút quay **trực tiếp trên điện thoại**, theo đúng thứ tự trong test plan; mở Firebase Console ở những chỗ cần chứng minh | Cả nhóm |
| 9.5 | Kiểm tra repo, báo cáo, slide, video mở được trong **cửa sổ ẩn danh**; không commit secret | Cả nhóm |

### GĐ 10 — Sau Lab 3: bài Final (chỉ định hướng, lập kế hoạch chi tiết sau)

- Đổi tên repo thành `PRM393_Final_<ID>`; tách thành `mobile/`, `web/`, `packages/core/` (dùng chung model và Firestore service).
- **Web admin** (Flutter Web trên Firebase Hosting):
  - Đăng nhập, chỉ chấp nhận admin.
  - **Hàng đợi duyệt** yêu cầu phân tích (thêm collection `requests` ở bài Final): approve / reject kèm lý do, app cập nhật realtime.
  - Quản lý danh mục bài nổi bật.
  - Dashboard: 3 số liệu + 1 biểu đồ (tổng số phân tích, tỷ lệ reference bịa, chủ đề yếu thường gặp).
  - Form thông báo → hộp thư trên mobile.
- **Cross-role flow:** người dùng gửi yêu cầu trên mobile (pending) → admin duyệt trên web → BE phân tích → app cập nhật realtime + nhận tin trong hộp thư.
- Đề Final ghi "no custom server". Thầy đã cho phép dùng BE qua Tailscale ở Lab 3; khi sang Final nên xin thầy xác nhận lại.
- **Gemini qua Firebase AI Logic** (mức 2 — structured output):
  - Từ cây chủ đề, sinh JSON "lộ trình đọc": thứ tự chủ đề cần đọc, tên tiếng Việt dễ hiểu, giải thích 1 dòng.
  - Có nhãn "AI", người dùng sửa được.
  - Lấy model, prompt và cờ bật/tắt từ Remote Config.
  - Bật App Check; có phương án dự phòng khi hết quota; log `ai_request`, `ai_result_accepted`, `ai_error`.
- Rules phân quyền + test Emulator: mỗi role, mỗi collection có ít nhất 1 ca được phép và 1 ca bị từ chối.
- Bài Final bỏ Cloud Storage: PDF chỉ lưu trên máy và chia sẻ, metadata để trong Firestore.

---

## 4. Prompt Stitch

Prompt mẫu (tiếng Anh, design system "Academic Verifier" kế thừa từ Lab 2) và các vòng tinh chỉnh R0–R3 nằm trong [PHAN_VIEC_FLUTTER.md](PHAN_VIEC_FLUTTER.md) mục A.4–A.5.

---

## 5. Kế hoạch Analytics (bản nháp cho `docs/analytics-plan.md`)

| Sự kiện | Khi nào | Tham số (kiểu) | Câu hỏi sản phẩm | Flow |
|---|---|---|---|---|
| `login` | Đăng nhập thành công | method (string) | Bao nhiêu người quay lại mỗi tuần? | — |
| `search` | Gửi một arXiv ID | search_term (string, arXiv ID), cache_hit (bool) | Bài nào được tra nhiều; bao nhiêu % được trả ngay từ cache? | A |
| `view_analysis` | Mở Paper overview | analysis_id (string), ref_count (int), weak_topic_count (int) | Bao nhiêu yêu cầu đi tới được kết quả? | A |
| `view_topic` | Mở chi tiết chủ đề | topic_id (string), topic_name (string), is_weak (bool) | Người dùng có thực sự xem các chủ đề yếu không? | B |
| `view_reference` | Mở chi tiết reference | reference_id (string), status (string) | Loại lỗi nào được xem nhiều nhất? | B |
| `filter_weak_topics` | Bật bộ lọc chủ đề yếu | analysis_id (string) | Bộ lọc có giúp rút ngắn Flow B không? | B |
| `export_report` | Tạo và upload PDF thành công | analysis_id (string), file_size_kb (int) | Bài nào dẫn tới việc xuất báo cáo? | C |
| `notification_open` | Bấm vào thông báo | notification_type (string) | Thông báo có đưa người dùng quay lại không? | A |
| `logout` | Đăng xuất | — | Phiên dùng kéo dài bao lâu trước khi đăng xuất? | — |

Không gửi email, tên hay thông tin cá nhân nào trong tham số. arXiv ID và tên chủ đề không phải dữ liệu cá nhân.

---

## 6. Test case ARTEMIS (bản nháp cho `docs/test-plan.md`)

| ID | Flow | Kiểu | Hướng dẫn tóm tắt → giá trị cần agent báo lại |
|---|---|---|---|
| TC-01 | Đăng nhập | **Native** (Google account picker) | Đăng xuất → Google Sign-In → chọn tài khoản test → báo tên tab đang chọn |
| TC-02 | Đăng nhập | Lỗi | Hủy ở account picker → báo nội dung thông báo hiện ra |
| TC-03 | A | Happy (cache) | Nhập `1706.03762` → báo tổng số reference và số chủ đề yếu |
| TC-04 | A | Lỗi | Nhập `abc123` → báo nội dung lỗi ở ô nhập |
| TC-05 | A | Thay thế | Share link arXiv từ Chrome vào app → báo ID đã điền sẵn |
| TC-06 | B | Happy | Mở Topic map → bật "Weak only" → báo số node còn lại |
| TC-07 | B | Happy | Mở chủ đề yếu đầu tiên → mở reference đầu tiên → báo trạng thái và lỗi đầu tiên |
| TC-08 | A/B | Lỗi | Bật chế độ máy bay → mở Paper overview → báo có error state và nút retry |
| TC-09 | C | Happy | Overview → "Report" → báo upload xong và có hiện link (kèm kiểm tra sự kiện `export_report` trong Logcat) |
| TC-10 | Thông báo | **Native** | Mở thông báo từ notification shade → báo tên màn hình được mở |
| TC-11 | Profile | Remote Config | Báo giá trị `weak_topic_threshold` hiển thị trong khu demo |
| TC-12 | Các tab | Happy | Lần lượt mở 3 tab → báo tiêu đề mỗi tab |
| TC-13 | Đăng xuất | Happy | Đăng xuất → báo màn hình hiện ra (phải là Sign-in) |
| TC-14 | Connect server | Lỗi | Profile → Change server → nhập `http://100.1.2.3:8000` → Test connection → báo thông báo lỗi và các gợi ý hiện ra |

> Điện thoại hoặc emulator chạy ARTEMIS phải ở trong tailnet và BE phải đang chạy. Các test đọc kết quả (TC-03, 06, 07, 09) dùng bài đã có sẵn trên Firestore, nên không phải chờ BE phân tích.

---

## 7. Rủi ro & cách xử lý

| Rủi ro | Cách xử lý |
|---|---|
| Laptop chạy BE tắt, ngủ, hoặc Tailscale mất kết nối | Kết quả cũ vẫn xem được từ Firestore; app hiện lỗi "Can't reach the server" kèm gợi ý; tắt chế độ ngủ của laptop khi demo/test |
| Địa chỉ Tailscale thay đổi | Dùng MagicDNS hoặc IP cố định của máy; đổi lại được ở Profile → Change server |
| Android chặn HTTP (cleartext) | `network_security_config.xml` chỉ cho phép dải IP Tailscale (đã làm ở Lab 2) |
| Console đòi gói Blaze khi bật Cloud Storage | Đã chốt không bật (Q3). App lưu PDF trên máy |
| Saffron khó build (Java cũ, model 3GB) | Giới hạn 2 ngày → chuyển sang Docker → vẫn không được thì thay bằng TF-IDF/KeyBERT trong Python, giữ schema `topics/` |
| Corpus nhỏ, nhiều ref chỉ có abstract, nên cây chủ đề nghèo | `oneTopicPerDoc: true`, `minTermFreq: 1`, thêm ngữ cảnh trích dẫn vào văn bản |
| Hết quota hoặc tốn tiền LLM cho hallucination check | Cache theo arXiv ID; khoảng $0.04/bài theo paper của RefChecker; tắt được khi cần |
| ARTEMIS flaky do phải chờ phân tích lâu | Test chỉ dùng bài đã có trong cache (P.8); thêm Semantics label; viết hướng dẫn rõ ràng |
| Google Sign-In lỗi `ApiException: 10` | Thêm SHA-1 của máy build APK, tải lại `google-services.json` |
| Thiếu bằng chứng bị tính là không làm | Chụp ảnh ngay khi mỗi tính năng chạy được, lưu vào `evidence/` theo từng dịch vụ |
| Git history không đúng thứ tự stage | Commit thường xuyên, dùng tiền tố `[S1]`…`[S8]` |

---

## 8. Mốc kiểm tra

Điền ngày cụ thể khi thầy công bố hạn nộp.

- **M0:** Chốt số commit tối thiểu với thầy. Repo nhóm: `PRM393-Project-G1/Lab3`; hỏi thầy tên này có được không.
- **M1:** Xong Figma, `DESIGN.md`, `flutter-handoff.md`; RefChecker và Saffron chạy được với 1 bài.
- **M2:** Xong `design-traceability.md` và `architecture.md`; theme và widget xong; đăng nhập Google chạy được.
- **M3:** Điện thoại gọi được BE qua Tailscale; BE ghi kết quả thật vào Firestore; đã có 5–10 bài demo.
- **M4:** Cả 3 flow chạy trọn vẹn trên điện thoại thật, đủ trạng thái; xuất và upload PDF được.
- **M5:** 6 dịch vụ Firebase có đủ bằng chứng trên Console.
- **M6:** ARTEMIS chạy ≥ 10 test × 3 lần, có bảng pass rate; xong phiên exploratory.
- **M7:** Xong code review (≥ 5 finding, ≥ 3 commit sửa).
- **M8:** Có APK release, báo cáo, slide, video; mọi link mở được trong cửa sổ ẩn danh.
