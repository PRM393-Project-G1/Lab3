# Architecture: Realtron

> MVVM + Provider. Phụ thuộc chỉ đi xuống; một tầng không bao giờ import tầng trên nó.
> Mô hình dữ liệu Firestore và hợp đồng API của backend ở mục 7 và 8.

## 1. Cây thư mục

```
lib/
├── main.dart        # Khởi tạo, khoá màn dọc, inject service, chạy app
├── theme/           # Token, ThemeData, ThemeExtension (màu trạng thái, chữ mono)
├── models/          # Dữ liệu thuần: RefStatus, StatusCounts, Analysis, Topic…
├── utils/           # Hàm thuần không phụ thuộc UI: kiểm tra và chuẩn hoá arXiv ID, định dạng thời gian
├── firebase/        # Bọc Firebase SDK: Auth, Firestore, Storage, Messaging, Analytics, Crashlytics, Remote Config
├── services/        # Backend qua Tailscale, repository, tạo PDF, nhận link share
├── viewmodels/      # Một ViewModel mỗi màn + ViewState; chứa toàn bộ logic nghiệp vụ
├── screens/         # Dựng UI từ state của ViewModel; không có logic, không gọi SDK
└── widgets/         # Component của design system, trạng thái truyền qua tham số
test/                # Unit test ViewModel (service giả), widget test design system
e2e_test/            # Test ARTEMIS (pytest)
backend/             # Orchestrator FastAPI: chạy RefChecker, Saffron; ghi Firestore, gửi FCM
firebase/            # storage.rules, firestore.rules, indexes, remote-config-defaults.json
design/              # Persona, flow, DESIGN.md, nhật ký AI, ảnh Stitch
handoff/             # flutter-handoff.md
docs/                # Traceability, architecture, analytics, test plan, code review
evidence/            # Ảnh Console, DebugView, Crashlytics, trace ARTEMIS
```

Khác cấu trúc gợi ý của đề ở hai điểm:
- `lib/theme/` được tách riêng, đúng yêu cầu mục 5 của đề.
- Có thêm `design/` và `handoff/` ở gốc, vì đề coi chúng là đặc tả của app.

Backend (Orchestrator) nằm ở `backend/`, tách khỏi code Flutter, và gọi RefChecker, Saffron như công cụ bên ngoài: mã nguồn của hai dự án đó không nằm trong repo. Đề không có thư mục này trong cấu trúc gợi ý; thêm vào vì đề tài cần một service riêng.

## 2. Sơ đồ tầng

```mermaid
flowchart TD
    subgraph UI
        S[screens/] --> W[widgets/]
    end
    S --> VM[viewmodels/]
    VM --> SV[services/]
    VM --> FB[firebase/]
    SV --> FB
    SV --> BE[(Backend qua Tailscale)]
    FB --> SDK[(Firebase SDK)]
    VM --> M[models/]
    SV --> M
    FB --> M
    W --> M
    W --> T[theme/]
    S --> T
    VM --> U[utils/]
```

**Quy tắc (đề chấm trực tiếp):**
1. Widget và screen không gọi `http`, `dio`, `FirebaseAuth.instance`, `FirebaseAnalytics.instance` hay SDK nào. Mọi lời gọi ra ngoài đi qua service.
2. Lọc, sắp xếp, tổng hợp, kiểm tra hợp lệ nằm trong ViewModel hoặc service, không nằm trong `build()`.
3. Mỗi màn có tải dữ liệu có `ViewState<T>` (`Loading` / `Empty` / `Failure` / `Data`), do ViewModel giữ.
4. Service được inject qua Provider, nên ViewModel test được bằng service giả.
5. Không có biến toàn cục thay đổi được.
6. Màu, cỡ chữ, khoảng cách lấy từ theme và token, không ghi cứng trong screen.

## 3. Sequence diagram: Flow A (phân tích bài mới)

```mermaid
sequenceDiagram
    actor U as Linh
    participant S as AnalyzeScreen
    participant VM as AnalyzeViewModel
    participant R as AnalysisRepository
    participant API as ApiClient
    participant BE as Backend (Tailscale)
    participant FS as Firestore
    participant P as ProgressViewModel

    U->>S: Nhập 1706.03762, bấm Analyze
    S->>VM: submit()
    VM->>VM: Kiểm tra và chuẩn hoá arXiv ID
    VM->>R: getAnalysis(id)
    R->>FS: analyses/{id}
    FS-->>R: Chưa có
    VM->>API: startAnalysis(id, aiAssisted)
    API->>BE: POST /api/analyses + ID token
    BE-->>API: { analysisId, status: queued }
    VM->>FS: addOrTouch(uid, id), qua LibraryRepository
    VM-->>S: Điều hướng tới /analyses/id/progress
    S->>P: watch(id)
    P->>FS: Nghe analyses/{id}
    BE->>FS: Ghi progress, rồi kết quả
    FS-->>P: status, progress
    P-->>S: ViewState cập nhật stepper
    BE->>FS: status = done, notification
    FS-->>P: done
    P-->>S: Hiện "View results"
```

## 4. ViewModel ↔ service

| ViewModel | Màn | Service được inject |
|---|---|---|
| `AuthViewModel` | Sign-in, router | `AuthService`, `AnalyticsService`, `CrashlyticsService`, `FirestoreService`, `MessagingService` |
| `ConnectViewModel` | Connect server | `ApiClient`, `ServerSettings`, `DeviceActions`, `CrashlyticsService` |
| `AnalyzeViewModel` | Analyze | `ApiClient`, `AnalysisRepository`, `LibraryRepository`, `LibraryFeed`, `AuthService`, `ServerSettings`, `RemoteConfigService`, `AnalyticsService`, `CrashlyticsService`, `DeviceActions` |
| `ProgressViewModel` | Analyzing | `AnalysisRepository`, `ApiClient`, `ServerSettings` |
| `OverviewViewModel` | Paper Overview | `AnalysisRepository`, `RemoteConfigService`, `AnalyticsService`, `CrashlyticsService` |
| `TopicMapViewModel` | Topics | `AnalysisRepository`, `RemoteConfigService`, `AnalyticsService` |
| `TopicDetailViewModel` | Topic | `AnalysisRepository`, `RemoteConfigService`, `AnalyticsService` |
| `ReferenceListViewModel` | References | `AnalysisRepository` |
| `ReferenceDetailViewModel` | Reference | `AnalysisRepository`, `DeviceActions`, `AnalyticsService` |
| `HistoryViewModel` | History | `LibraryRepository`, `LibraryFeed`, `AuthService`, `CrashlyticsService` |
| `NotificationsViewModel` | Notifications | `FirestoreService`, `AuthService`, `AnalyticsService` |
| `ExportViewModel` | Sheet Export report | `ReportService`, `StorageService`, `FirestoreService`, `AnalysisRepository`, `RemoteConfigService`, `AuthService`, `AnalyticsService`, `CrashlyticsService`, `DeviceActions` |
| `ProfileViewModel` | Profile | `AuthService`, `ServerSettings`, `RemoteConfigService`, `AnalyticsService`, `CrashlyticsService`, `LibraryFeed` |

`ShareIntentService` và `MessagingService` được nghe ở `RealtronApp` trong `main.dart`, vì link share hay push có thể tới khi đang ở bất kỳ màn nào. App chuyển tới `/analyze?shared=…` hoặc `/analyses/:id`.

## 5. Design system trong code

- **Token:** `theme/app_tokens.dart` (palette, spacing, radius, size, elevation).
- **Theme:** `theme/app_theme.dart` dựng `ColorScheme`, `TextTheme` và theme của từng component.
- **Ngoài chuẩn Material:** `theme/app_theme_extensions.dart` có `StatusColors` và `AppTextExtras`. Đọc qua `context.status(...)`, `context.mono`, `context.muted`.
- **Component:** mỗi component trong Figma page 05 là một widget trong `widgets/` (`handoff/flutter-handoff.md` Bảng 2).
- **Kiểm chứng:** `test/widgets/design_system_test.dart` kiểm tra không tràn ở 360 / 412 dp với chữ 100% và 130%, vùng chạm và contrast theo guideline của Flutter.

## 6. Quyết định

| Quyết định | Lý do |
|---|---|
| Provider + `ChangeNotifier` | Đề cho phép Provider hoặc Riverpod; nhóm đã dùng Provider ở Lab 2 |
| go_router | Cần deep link từ push và chuyển màn theo auth state |
| Kết quả đọc từ Firestore, không qua REST | Có realtime và offline cache; xem lại được khi backend tắt |
| App chỉ gọi backend để ra lệnh | Backend chạy trên laptop, có thể tắt bất cứ lúc nào |
| Cây chủ đề và ngưỡng "chủ đề yếu" nằm trong `models/topic_tree.dart` | Overview, Topics, Topic và báo cáo PDF dùng chung một cách tính; đổi được qua Remote Config mà không build lại |
| Số đếm của chủ đề cha tính lại từ `refIds` của cả nhánh | Một reference nằm trong hai chủ đề con chỉ được đếm một lần |
| Chủ đề yếu: (Hallucinated + Error) / tổng ≥ `weak_topic_threshold` và tổng ≥ `weak_topic_min_refs` | Warning không tính, vì chỉ là khác biệt nhỏ về metadata |
| Push khi app đang mở hiện bằng snackbar | Không cần thêm thư viện local notification |
| Backend chạy một job mỗi lần, lệnh dừng diệt cả tiến trình con | Mỗi job tốn nhiều bộ nhớ và dễ chạm rate limit của API bên ngoài |
| Khởi động lại backend thì job đang chạy thành `failed` | Không thì app chờ mãi một job không còn tồn tại |
| Mỗi reference chỉ thuộc tối đa 5 chủ đề mạnh nhất (theo tf-idf) | Toàn văn nhắc đến hầu hết các thuật ngữ; nếu giữ hết thì chủ đề nào cũng chứa gần đủ reference và "chủ đề yếu" mất ý nghĩa |
| Saffron dùng model thay thế (POS tải lại, mô hình dựng cây train lại) | Máy chủ model gốc đã ngừng hoạt động; xem `backend/README.md` |
| Gói Spark: PDF lưu trên máy, không upload (`enable_cloud_upload = false`) | Spark không có bucket Cloud Storage. Code upload vẫn giữ và có test, bật lại được qua Remote Config |
| `kotlin.incremental=false`, `compileSdk = 37` | Pub cache ở ổ C, dự án ở ổ D; `receive_sharing_intent` yêu cầu SDK 37 |

## 7. Firestore

| Đường dẫn | Trường | Ai ghi |
|---|---|---|
| `users/{uid}` | `displayName`, `photoUrl`, `createdAt`, `fcmTokens[]`, `role` | App |
| `users/{uid}/library/{arxivId}` | `customTitle`, `addedAt`, `lastOpenedAt` | App |
| `users/{uid}/reports/{id}` | `analysisId`, `storagePath`, `downloadUrl`, `sizeKb`, `createdAt`. Chỉ ghi khi `enable_cloud_upload` bật | App |
| `users/{uid}/notifications/{id}` | `title`, `body`, `type`, `analysisId`, `createdAt`, `read` | Backend; app chỉ đổi `read` |
| `analyses/{arxivId}` | `requestedBy`, `aiAssisted`, `createdAt`, `status` (`queued`, `processing`, `done`, `failed`, `cancelled`), `paperTitle`, `paperAuthors[]`, `progress`, `summary`, `finishedAt`, `error` | Backend |
| `analyses/{id}/references/{refId}` | `index`, `title`, `authors[]`, `year`, `venue`, `url`, `status`, `issues[]`, `hallucination`, `textSource`, `topicIds[]` | Backend |
| `analyses/{id}/topics/{topicId}` | `term`, `parentId`, `depth`, `score`, `refIds[]`, `counts` | Backend |

**Các trường app đọc mà backend phải ghi đúng tên:**

| Trường | Giá trị | Dùng ở |
|---|---|---|
| `progress.stage` | `references`, `verify`, `fabrication`, `fulltext`, `topics` | Stepper |
| `progress.percent`, `progress.processedRefs` | Số nguyên | Thanh tiến độ, `18/41 refs` |
| `summary` | `totalRefs`, `verified`, `warning`, `error`, `hallucinated`, `unverified` | Overview, thanh trạng thái |
| `references.status` | `verified`, `warning`, `error`, `hallucinated`, `unverified`; giá trị lạ được coi là `unverified` | Mọi nơi hiện trạng thái |
| `issues[]` | `type`, `message`, `cited`, `actual` | Bảng Cited / Actual, `Copy fix` |
| `hallucination` | `explanation`, `closestMatchTitle`, `closestMatchUrl` | Dialog `Likely fabricated` |
| Dữ liệu push FCM | `analysisId` trong `data` | Chạm push mở Overview |
| `fcmTokens[]` | Bỏ qua và xoá token không còn hợp lệ | App xoá token của máy khi đăng xuất |

Luật truy cập nằm ở `firebase/firestore.rules` và `firebase/storage.rules`. Người dùng chỉ đọc và ghi dữ liệu của mình, không tự đổi được `role`, không ghi được `analyses/**`. File PDF chỉ nhận `application/pdf` dưới 10 MB.

## 8. API backend (qua Tailscale)

App chỉ gọi backend để ra lệnh. Mọi lệnh `POST` gửi `Authorization: Bearer <Firebase ID token>`.

| Lệnh | Body | Trả về |
|---|---|---|
| `GET /api/health` | | `{ "status": "ok", "version": "…" }`. Thiếu `status: ok` thì app báo `Not a Realtron server` |
| `POST /api/analyses` | `{ "arxivId", "aiAssisted" }` | `{ "analysisId", "status" }`, mã 2xx |
| `POST /api/analyses/{id}/cancel` | `{}` | Mã 2xx |

## 9. Remote Config

| Khoá | Mặc định | Tác động |
|---|---|---|
| `weak_topic_threshold` | `0.5` | Chủ đề nào là yếu; con số trong chân trang Topics |
| `weak_topic_min_refs` | `3` | Chủ đề quá nhỏ thì không xét yếu |
| `max_recent_checks` | `10` | Số thẻ ở mục Recent |
| `enable_report_export` | `true` | Ẩn hoặc hiện nút `Report` ở Overview |
| `enable_cloud_upload` | `false` | Bật thì upload PDF lên Cloud Storage. Tắt thì chỉ lưu trên máy (gói Spark) |
