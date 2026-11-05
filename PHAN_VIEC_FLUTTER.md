# Phần việc của mình — Realtron: Stitch → Figma → Flutter `.apk`

> Lab 3 của nhóm: **RefCheck + Saffron** theo "Ý tưởng 1 – Hiểu nhanh một bài báo qua danh sách tham khảo" (thầy đã duyệt).
> Mình phụ trách: **làm lại thiết kế trên Stitch → đẩy sang Figma (6 page) → hiện thực app Flutter → build `app-release.apk`**.
> Kế hoạch chung của cả nhóm (pipeline, Firebase, ARTEMIS, review): [KE_HOACH_CONG_VIEC.md](KE_HOACH_CONG_VIEC.md).

**Kế thừa từ Lab 2** (`../lab2/code/Lab2/`) — dùng làm mẫu, không chép nguyên:

| Lab 2 có | Dùng lại thế nào ở Lab 3 |
|---|---|
| Quy trình Stitch trong `ux/ai-design-log.md`: Prompt 1→2→3, phản biện v1, vòng 1b, tinh chỉnh R0→R3 | Làm lại **đúng quy trình đó** cho sản phẩm mới |
| Design system "Academic Verifier" (`ux/stitch/DESIGN.md`, `mobileapp/lib/core/theme/tokens.dart`) | **Đề xuất giữ** bộ màu/chữ này (đã kiểm tra contrast). Đưa giá trị token vào prompt để Stitch sinh đồng bộ |
| Persona Linh (P01), TS. Hùng (P02) trong `ux/persona.md` | Viết lại nhu cầu cho ý tưởng mới: đọc hiểu bài lạ, tìm chủ đề yếu. Giữ P03 Khoa làm persona hỗ trợ: người chạy BE và đưa địa chỉ Tailscale |
| Màn Connect Server + `HUONG_DAN_TAILSCALE.md` | **Dùng lại**: app vẫn gọi BE qua Tailscale. Thầy đã cho phép |
| Cấu trúc Figma 6 page: **01 User Flow · 02 Wireframe · 03 Final UI · 04 Design System · 05 Components · 06 Prototype** | Giữ nguyên cấu trúc |
| `ux/flutter-handoff.md`: 6 mục mỗi màn + 2 bảng mapping | Viết lại cho các màn mới |
| Code Flutter `mobileapp/` (Provider, go_router, `StatusChip`, `ReferenceTile`, `StateView`, `InfoBanner`, stacked bar) | Dùng lại theme, widget, `ApiClient` (Dio, chuyển lỗi mạng thành câu dễ hiểu), `SettingsStore` (địa chỉ server), màn Connect.<br>**Bỏ** `CheckSocket` (tiến độ giờ đi qua Firestore) và `AppState` toàn cục (Lab 3 cấm global mutable state) |

---

## Phần A — Làm lại thiết kế trên Stitch

### A.1 Sản phẩm mới: màn hình và điều hướng

**Bottom navigation, 3 tab:** `Analyze` · `History` · `Profile`.
UI giữ tiếng Anh như Lab 2. **Quy tắc chữ (thầy góp ý 04/11): ngắn, dễ quét, không ghi tên backend**, xem `app/design/user-flow.md` mục 0. Chuỗi chuẩn của từng màn nằm trong `user-flow.md`; các bảng dưới đây chỉ mô tả bố cục.

| # | Màn hình | Route | Ghi chú |
|---|---|---|---|
| 0 | Connect server | `/connect`, `/profile/server` | Từ Lab 2: "Server URL" (địa chỉ Tailscale), "Test connection" → `GET /api/health`; trạng thái idle, testing, connected, failed (Tailscale tắt, sai cổng, timeout, không phải BE của nhóm). Hiện sau lần đăng nhập đầu; đổi lại được trong Profile |
| 1 | Sign-in | `/sign-in` | Google Sign-In; trạng thái: default, signing in, cancelled, offline |
| 2 | Analyze (tab 1) | `/analyze` | Ô arXiv ID/link, chip "Try 1706.03762", công tắc "AI-assisted check", Recent checks, chuông thông báo |
| 3 | Analysis in progress | `/analyses/:id/progress` | Stepper 5 bước, ẩn bottom nav; failed, offline, cancel |
| 4 | Paper overview | `/analyses/:id` | Thẻ cảnh báo nặng nhất ở đầu, stacked bar 5 trạng thái, **thẻ Topics** (số chủ đề, số chủ đề yếu), nút "Explore topics", "Report" |
| 5 | Topic map | `/analyses/:id/topics` | Cây chủ đề thu gọn/mở rộng, lọc "All / Weak only", nhóm "Unclassified" |
| 6 | Topic detail | `/analyses/:id/topics/:topicId` | Đường dẫn chủ đề, stacked bar, chủ đề con, danh sách reference |
| 7 | Reference list | `/analyses/:id/references?filter=` | Từ Lab 2, lọc theo trạng thái |
| 8 | Reference detail | `/analyses/:id/references/:refId` | Bảng Cited / Actual, "Copy fix", các topic chứa reference; dialog "Likely fabricated reference" |
| 9 | History (tab 2) | `/history` | Tìm kiếm, nhóm Today / This week / Earlier, đổi tên, xoá; loading / empty / error |
| 10 | Notifications | `/notifications` | Danh sách thông báo nhận được, chấm chưa đọc; empty |
| 11 | Profile (tab 3) | `/profile` | Tài khoản, Sign out, mặc định "AI-assisted check", **khu Firebase demo**: thông báo, export & upload, giá trị Remote Config, nút Crashlytics |
| — | Overlay | | Sheet "Export report" (generating / uploading % / success + link / error), dialog Likely fabricated, Cancel analysis?, Delete check?, Rename check, Test crash? |

Tổng cộng 12 màn, đạt yêu cầu ≥ 8 của Lab 3.

**Luồng mở app:** Sign-in → (lần đầu, chưa lưu server) Connect server → Analyze.
Chỉ màn Analyze (lúc bắt đầu phân tích) và Connect cần tới BE. Mọi màn xem kết quả đều đọc từ Firestore, nên **vẫn xem được khi laptop tắt**.

### A.2 Ba user flow (mỗi flow có nhánh thay thế và nhánh lỗi)

**Flow A — Phân tích một bài báo** (P01 Linh)
- **Happy path:** [2] nhập `1706.03762` → "Analyze" → [3] stepper: Extracting references → Verifying against databases → Hallucination check → Fetching reference text → Finding topics → "View overview" → [4].
- **Nhánh thay thế:**
  - A1: bài đã được phân tích trước đó thì mở [4] ngay.
  - A2: share link arXiv từ trình duyệt vào app thì [2] được điền sẵn ID.
  - A3: rời màn [3], nhận push "Analysis complete", chạm vào thì mở [4].
- **Nhánh lỗi:**
  - A-E1: sai định dạng → lỗi hiện ngay dưới ô nhập.
  - A-E2: không tìm thấy bài hoặc phân tích thất bại → "Try again" / "Edit input".
  - A-E3: mất mạng → banner "You're offline", tự cập nhật lại khi có mạng.
  - A-E4: "Cancel" → dialog xác nhận.
  - A-E5: không tới được server (Tailscale tắt, BE không chạy) → banner "Can't reach the server" + gợi ý kiểm tra Tailscale → "Retry" / "Change server".

**Flow B — Tìm chủ đề yếu** (P01, P02 TS. Hùng)
- **Happy path:** [4] "Explore topics" → [5] bật "Weak only" → chạm một chủ đề yếu → [6] → chạm một reference → [8] đọc Cited / Actual → "Copy fix", hoặc dialog Likely fabricated → "Open closest match".
- **Nhánh thay thế:**
  - B1: chạm thẳng vào chủ đề yếu trên thẻ Topics của [4].
  - B2: đi xuống các chủ đề con.
  - B3: từ [8] nhảy sang một topic khác chứa reference đó.
- **Nhánh lỗi / rỗng:**
  - B-E1: không có chủ đề yếu → empty state "No weak topics".
  - B-E2: reference không lấy được nội dung → nằm trong "Unclassified" kèm giải thích lý do.
  - B-E3: lỗi tải → error + "Retry".

**Flow C — Xem lại và xuất báo cáo** (P02, P01)
- **Happy path:** [9] chạm một check → [4] "Report" → sheet: Generating PDF → Uploading 64% → "Uploaded" + link → "Copy link" / "Share".
- **Nhánh thay thế:**
  - C1: tìm trong History.
  - C2: đổi tên check.
  - C3: mở từ [10] Notifications.
- **Nhánh lỗi:**
  - C-E1: upload thất bại → "Retry".
  - C-E2: không tải được lịch sử → "Retry".
  - C-E3: chưa có lịch sử → "No checks yet" + "Analyze your first paper".
  - C-E4: xoá → dialog xác nhận.

### A.3 Quy trình trên Stitch (giống Lab 2, ghi đủ vào `ai-design-log.md`)

| Bước | Việc | Đầu ra |
|---|---|---|
| S0 | Tạo **project mới** trên stitch.withgoogle.com, chế độ **Mobile · Standard** (bắt buộc chế độ này mới dùng được *Copy to Figma*) | Project Stitch |
| S1 | Chạy Prompt 1 → 2 → 3 (mục A.4), mỗi prompt đủ 5 thành phần: persona, task, nền tảng mobile, constraints, style | Bản **v1** |
| S2 | Phản biện v1: ≥ 5 phát hiện (F1…), mỗi phát hiện kèm ảnh. Lab 2 cho thấy AI hay bịa số liệu, bỏ sót yêu cầu, thiếu trạng thái lỗi | Mục "Phản biện v1" |
| S3 | Prompt 1b: bù những màn còn thiếu (Stitch thường bỏ sót khi một prompt có nhiều màn) | Đủ 12 màn |
| S4 | Tinh chỉnh **R0 → R3**, mỗi vòng một mục tiêu (mục A.5); sau mỗi vòng đối chiếu bằng **chữ trong code HTML**, không chỉ nhìn ảnh | Bản **v2** |
| S5 | Export `screen.png` + `code.html` của từng màn vào `ux/stitch/v1/`, `ux/stitch/v2/`; lưu `DESIGN.md` của Stitch | Thư mục `ux/stitch/` |
| S6 | Ghi `design-decisions.md`: mỗi gợi ý của AI ghi rõ chấp nhận / sửa / bỏ, kèm lý do; bảng contrast | Quyết định thiết kế |
| S7 | Chép **nguyên văn** mọi prompt vào `ai-design-log.md` (Lab 3 bắt buộc khai báo mọi AI tool đã dùng) | Log |

### A.4 Prompt Stitch

Bản chuẩn (nguyên văn, dùng đúng chuỗi UI trong `app/design/user-flow.md`) nằm ở **[app/design/ai-design-log.md](app/design/ai-design-log.md) mục 1**: Prompt 1 (màn 0–4), Prompt 2 (màn 5–8), Prompt 3 (màn 9–11 + overlay). Chỉ sửa prompt ở file đó để không bị lệch.

### A.5 Bốn vòng tinh chỉnh (mỗi vòng một mục tiêu)

| Vòng | Mục tiêu | Kiểm tra |
|---|---|---|
| R0 | Nội dung trung thực, khớp backend | Không còn số liệu bịa; các chữ trên UI khớp với dữ liệu thật RefChecker/Saffron trả về (chủ đề là cụm từ khoá tiếng Anh, có nhóm Unclassified) |
| R1 | Phân cấp thông tin | Overview: cảnh báo nặng nhất lên đầu, Topics ngay sau; Topic map đọc được ở 360 dp; cây sâu thì tách thành màn con |
| R2 | Accessibility | Contrast ≥ 4.5:1, vùng chạm ≥ 48dp, chữ ≥ 14sp, mọi trạng thái đều có icon + chữ, thử cỡ chữ 130% |
| R3 | Trạng thái lỗi / rỗng / tải | Đủ loading, empty, error cho mọi màn có dữ liệu; đủ nhánh lỗi của Flow A, B, C |

---

## Phần B — Đẩy sang Figma (6 page)

| Page | Nội dung | Cách làm |
|---|---|---|
| **01 User Flow** | Sitemap 12 màn + sơ đồ 3 flow (happy / alternate / error) | Vẽ bằng connector; mỗi nút ghi số màn [n] và nhãn nút thật |
| **02 Wireframe** | Bản low-fi của 12 màn (xám, chưa có màu) | Vẽ tay từ layout v2, hoặc duplicate frame rồi bỏ style |
| **03 Final UI** | Toàn bộ màn v2 + mọi biến thể trạng thái | Trong Stitch chọn màn → **Copy to Figma** → dán vào page; đặt tên frame `03-[n] Tên màn / trạng thái`; chia section theo flow |
| **04 Design System** | Variables: màu (bảng token), spacing 4/8/16/24/32, radius 6/8/12/24; Text styles (Source Serif 4, Inter, JetBrains Mono); Effect styles (elevation) | Gắn lại màu và chữ của frame ở page 03 vào Variables/Styles (Copy to Figma chỉ dán giá trị cứng) |
| **05 Components** | Mỗi component một bộ variant theo trạng thái (danh sách bên dưới) | Tạo component, thay các bản sao trong page 03 bằng instance |
| **06 Prototype** | Nối tương tác cho Flow A, B, C, **gồm cả nhánh thay thế và nhánh lỗi**; đặt 3 starting point | Chạy thử Present mode, quay video ngắn làm bằng chứng |

**Components cần có (page 05):**
- **Lấy lại từ Lab 2:** Button (filled / outlined / text: default, disabled, loading, destructive), Text field (default, focused, error), Card, Reference card (full, compact, flagged), History card (full, in progress, failed), Status chip (5 trạng thái + Checking), Filter chip, Bottom nav (3 tab), App bar (title, back, action), Section header, Dialog, Banner (error, warning, success, info, offline), StateView (loading, empty, error), Stacked bar.
- **Thêm mới:** **Topic tree node** (collapsed, expanded, weak, leaf, unclassified), **Topic chip**, **Notification tile** (unread, read), **Export sheet** (generating, uploading, success, error), **Remote Config row**, **Stepper 5 bước** (pending, active, done, failed).

**Hoàn thành khi:**
- [ ] Đủ 6 page, link Figma để chế độ **ai có link cũng xem được**, đã dán vào README.
- [ ] Mọi màu, chữ ở page 03 đều gắn Variables/Styles; không còn bản sao component lẻ.
- [ ] Prototype chạy hết 3 flow, gồm cả nhánh lỗi.
- [ ] Có ảnh chụp: bước Copy to Figma, từng page, prototype (lưu vào `evidence/design/`).
- [ ] Đã viết `flutter-handoff.md` (6 mục mỗi màn: Layout, Components, States, Interactions, Navigation, UI constraints) + **Bảng 1: token → Flutter** + **Bảng 2: component → widget**.

> Lab 3 quy định: sau này hễ app khác Figma ở đâu thì **phải ghi vào `docs/design-traceability.md` kèm lý do và sửa lại Figma**. Lệch mà không ghi lại sẽ bị tính là lỗi.

---

## Phần C — App Flutter theo 8 stage của Lab 3

Git history phải đi đúng thứ tự stage. Mình đặt tiền tố commit `[S1]`…`[S8]`.
**Không** chép cả app Lab 2 vào một commit đầu tiên. Mang từng phần sang đúng stage của nó: theme và widget ở S2, các màn hình ở S4.

### S1 — Design traceability (`docs/design-traceability.md`)
- [ ] Bảng: mỗi màn / flow / component trong Figma ↔ route, widget, ViewModel, nguồn dữ liệu (Firestore path) ↔ trạng thái (Todo / Done).
- [ ] Mục "Deviations": để trống sẵn, ghi dần trong quá trình làm.

### S2 — Kiến trúc & theme
- [ ] `flutter create --platforms=android --org vn.fpt.prm393 refcheck`; khoá hướng dọc, `minSdk 23`; ghim version trong `pubspec.yaml`.
- [ ] Quản lý state: **Provider + ChangeNotifier**. Lab 3 cho phép Provider hoặc Riverpod; Lab 2 đã dùng Provider nên giữ để đỡ phải học lại.
- [ ] `lib/theme/`: chuyển `tokens.dart` + `app_theme.dart` từ Lab 2, cập nhật theo page 04.
- [ ] `lib/widgets/`: chuyển `StatusChip`, `ReferenceTile`, `StateView`, `InfoBanner`, `AppCard`, `SectionLabel`, `StackedBar` từ Lab 2; viết mới `TopicTreeNode`, `NotificationTile`, `ExportSheet`, `RemoteConfigRow`, `AnalysisStepper`.
- [ ] `lib/viewmodels/view_state.dart`: `sealed class ViewState<T>` gồm `Loading`, `Empty`, `Error(message, retry)`, `Data(T)`.
- [ ] `docs/architecture.md`: cây thư mục (mỗi thư mục 1 dòng), sơ đồ tầng (Mermaid), sequence diagram cho Flow A, bảng ViewModel ↔ service (bên dưới).

```
lib/
├── main.dart              # khởi tạo Firebase, MultiProvider (inject service), runApp
├── app_router.dart        # go_router + chuyển màn theo auth state
├── theme/                 # tokens.dart, app_theme.dart
├── models/                # Analysis, RefItem, RefStatus, Topic, TopicNode, LibraryItem, AppNotification
├── services/              # ApiClient (Dio → BE qua Tailscale, gắn Firebase ID token), ServerSettings (địa chỉ server),
│                          # AnalysisRepository, LibraryRepository, ReportService (pdf), ShareIntentService, ClipboardService
├── firebase/              # AuthService, FirestoreService, StorageService, MessagingService,
│                          # AnalyticsService, CrashlyticsService, RemoteConfigService
├── viewmodels/            # 1 ViewModel cho mỗi màn + view_state.dart
├── screens/               # chỉ dựng UI từ state, không có logic nghiệp vụ, không gọi SDK
├── widgets/               # component Lab 2/3
└── utils/                 # arxiv_id.dart (kiểm tra/chuẩn hoá ID), formatters
```

| ViewModel | Màn | Service được inject |
|---|---|---|
| `AuthViewModel` | Sign-in, router | AuthService, AnalyticsService, CrashlyticsService |
| `ConnectViewModel` | Connect server | ApiClient, ServerSettings, CrashlyticsService |
| `AnalyzeViewModel` | Analyze | ApiClient, AnalysisRepository, LibraryRepository, RemoteConfigService, ShareIntentService, AnalyticsService |
| `ProgressViewModel` | Analysis in progress | AnalysisRepository, ApiClient (cancel) |
| `OverviewViewModel` | Paper overview | AnalysisRepository, RemoteConfigService, AnalyticsService |
| `TopicMapViewModel` | Topic map | AnalysisRepository, RemoteConfigService, AnalyticsService |
| `TopicDetailViewModel` | Topic detail | AnalysisRepository, AnalyticsService |
| `ReferenceListViewModel` | Reference list | AnalysisRepository |
| `ReferenceDetailViewModel` | Reference detail | AnalysisRepository, ClipboardService, AnalyticsService |
| `HistoryViewModel` | History | LibraryRepository |
| `NotificationsViewModel` | Notifications | FirestoreService, MessagingService, AnalyticsService |
| `ExportViewModel` | Export sheet | ReportService, StorageService, AnalyticsService, CrashlyticsService |
| `ProfileViewModel` | Profile / demo | AuthService, RemoteConfigService, CrashlyticsService |

**Logic đặt trong ViewModel** (thầy sẽ kiểm tra): dựng cây từ danh sách topic phẳng, tính tỷ lệ lỗi, xác định chủ đề yếu theo ngưỡng Remote Config, lọc, sắp xếp theo mức nghiêm trọng, kiểm tra arXiv ID.
`build()` chỉ đọc state, không tính toán gì.

### S3 — Firebase & đăng nhập
- [ ] `flutterfire configure --platforms=android`; thêm SHA-1 debug + release vào Firebase (thiếu thì Google Sign-In báo `ApiException: 10`).
- [ ] `AuthService`: đăng nhập Google; khi người dùng hủy thì trả lỗi riêng để hiện banner "Sign-in was cancelled."; đăng xuất thì xoá dữ liệu cục bộ (cache provider, `setUserId(null)`).
- [ ] Router: chưa đăng nhập → `/sign-in`; đã đăng nhập nhưng chưa lưu server → `/connect`; còn lại → `/analyze`. Người chưa đăng nhập không vào được màn nào khác.
- [ ] Màn Connect: chuyển `ConnectScreen` từ Lab 2 sang MVVM (`ConnectViewModel`); `android/app/src/main/res/xml/network_security_config.xml` cho phép HTTP tới dải IP Tailscale (giống Lab 2).
- [ ] Lần đăng nhập đầu tạo `users/{uid}`.

### S4 — Tính năng (3 flow, đủ trạng thái)
- [ ] **Flow A:** Analyze kiểm tra `analyses/{arxivId}` trên Firestore. Đã có thì mở ngay; chưa có thì `ApiClient.startAnalysis()` → `POST /api/analyses` qua Tailscale. Ghi `users/{uid}/library`.
  - Progress nghe `analyses/{id}.progress` trên Firestore; Cancel → `POST /api/analyses/{id}/cancel`.
  - Không tới được server thì hiện banner kèm "Retry" / "Change server".
  - Nhận link được share (`receive_sharing_intent`).
- [ ] **Flow B:** Overview (thẻ cảnh báo, stacked bar, thẻ Topics) → Topic map → Topic detail → Reference list/detail, Copy fix, dialog Likely fabricated.
- [ ] **Flow C:** History (`users/{uid}/library`, tìm kiếm, đổi tên, xoá) → Overview → "Report":
  - `ReportService` tạo PDF bằng package `pdf`, nội dung là những gì đang hiển thị trên Overview.
  - Lưu PDF trên máy, có "Open" và "Share" (nhóm dùng gói Spark, không có bucket).
  - Khi bật `enable_cloud_upload`: `StorageService` upload lên `reports/{uid}/...`, có thanh tiến độ, download URL và "Copy link".
- [ ] Mọi màn có dữ liệu: loading / empty / error + Retry; nút Back hoạt động ở mọi màn; mất mạng không crash (dùng Firestore offline cache + `connectivity_plus` để hiện banner).
- [ ] **Không** để dữ liệu giả trong bản nộp. Khi BE chưa xong thì dùng các bài nhóm BE đã phân tích sẵn trên Firestore.

### S5 — Instrumentation (code phía app)
- [ ] `AnalyticsService` + ≥ 7 sự kiện theo `docs/analytics-plan.md` (viết plan **trước** khi code); `setUserId` sau khi đăng nhập.
- [ ] `CrashlyticsService`: handler lỗi Flutter, user ID, custom key `arxiv_id` / `screen`; non-fatal từ lỗi thật (upload thất bại, parse dữ liệu lỗi); nút Test crash có dialog xác nhận.
- [ ] `RemoteConfigService`: giá trị mặc định trong app; `weak_topic_threshold`, `max_recent_checks`, `enable_report_export` làm thay đổi UI thật sự (không chỉ in giá trị ra).
- [ ] `MessagingService`: xin quyền thông báo (Android 13+); lưu token vào `users/{uid}.fcmTokens`; nhận ở cả foreground (`flutter_local_notifications`), background, terminated; lưu vào màn Notifications; chạm vào mở đúng Overview.
- [ ] Chụp bằng chứng: DebugView cho từng sự kiện, dashboard Crashlytics, Remote Config trước/sau, thông báo ở 3 trạng thái.

### S6 — Hỗ trợ ARTEMIS
- [ ] Thêm `Semantics(label: ...)` cho nút, item danh sách, node cây, stacked bar (label kiểu "2 hallucinated, 3 error, 29 verified").
- [ ] Bật analytics debug mode cho bản dùng để test.
- [ ] Unit test cho ViewModel dùng service giả (`mocktail`): dựng cây, tính chủ đề yếu, kiểm tra arXiv ID.

### S7 — Sửa theo AI code review
- [ ] Sửa ≥ 3 finding được chấp nhận, mỗi finding một commit `fix(CR-xx): ...`.

### S8 — Build `.apk`
- [ ] Tạo keystore (không commit), cấu hình `signingConfigs`, thêm SHA-1 release vào Firebase, tải lại `google-services.json`.
- [ ] `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`.
- [ ] Cài lên điện thoại thật, chạy lại 3 flow; kiểm tra ở 360dp và 412dp, cỡ chữ 130%, không có sọc overflow.

---

## Phần D — Cần gì từ đồng đội

| Cần | Từ ai | Khi nào |
|---|---|---|
| Firebase project + quyền Editor | Người phụ trách Firebase | Trước S3 |
| Được thêm vào tailnet của nhóm + địa chỉ BE (IP `100.x` hoặc MagicDNS) | BE | Trước S3 |
| Hợp đồng API đã chốt (`/api/health`, `POST /api/analyses`, `/cancel`, kiểu lỗi trả về) | BE + mình | Trước S4; xem P.5 trong kế hoạch chung |
| Schema Firestore đã chốt (`analyses`, `references`, `topics`, `users/{uid}/library`, `notifications`) | BE + mình | Trước S4; xem mục 2 của kế hoạch chung |
| 5–10 bài đã phân tích thật trên Firestore | BE | Giữa S4 |
| BE gửi FCM khi phân tích xong | BE | S5 |
| Danh sách test case để gắn Semantics label đúng chỗ | QA | S6 |
| Kết quả AI code review | QA | S7 |

## Phần E — Mốc của mình

1. **D1:** Stitch v1 xong (12 màn) + phản biện ≥ 5 phát hiện.
2. **D2:** Stitch v2 xong sau R0–R3; `ai-design-log.md` + `design-decisions.md` hoàn chỉnh.
3. **D3:** Đủ 6 page Figma + prototype + `flutter-handoff.md`.
4. **D4:** S1–S3: traceability, architecture, theme, widget, đăng nhập Google.
5. **D5:** S4: cả 3 flow chạy được với dữ liệu thật.
6. **D6:** S5: đủ bằng chứng cho 6 dịch vụ Firebase.
7. **D7:** S6–S8: Semantics, sửa theo review, `app-release.apk` chạy trên máy thật.
