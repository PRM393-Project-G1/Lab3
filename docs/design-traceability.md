# Design traceability: Realtron

> Ánh xạ mọi màn hình, flow và component trong Figma sang route, widget và nguồn dữ liệu Flutter.
> Figma: [Realtron](https://www.figma.com/design/gPn3Z9LnTN8Js3QxbrH5Gu/Realtron) · Đặc tả: [`design/user-flow.md`](../design/user-flow.md), [`handoff/flutter-handoff.md`](../handoff/flutter-handoff.md).
> **Quy tắc:** app khác Figma ở đâu thì ghi vào mục 4 kèm lý do và sửa lại Figma. Lệch mà không ghi lại bị tính là lỗi.

Trạng thái: `Todo` · `Doing` · `Done`.

`Doing` ở mục 1 và 2 nghĩa là đã có code và widget test bằng service giả (`test/screens/app_flow_test.dart`), **chưa chạy trên máy thật với Firebase và backend thật**. Chỉ đổi sang `Done` khi có bằng chứng trong `evidence/`.

## 1. Màn hình

| # | Màn (Figma page 03) | Route | Screen / ViewModel | Nguồn dữ liệu | Trạng thái |
|---|---|---|---|---|---|
| 0 | Connect server | `/connect`, `/profile/server` | `ConnectScreen` / `ConnectViewModel` | `GET /api/health` (Tailscale); `ServerSettings` (máy) | Doing |
| 1 | Sign-in | `/sign-in` | `SignInScreen` / `AuthViewModel` | Firebase Auth | Doing |
| 2 | Analyze | `/analyze` | `AnalyzeScreen` / `AnalyzeViewModel` | `POST /api/analyses`; `analyses/{id}`; `users/{uid}/library`; Remote Config | Doing |
| 3 | Analyzing | `/analyses/:id/progress` | `ProgressScreen` / `ProgressViewModel` | `analyses/{id}` (realtime); `POST /api/analyses/{id}/cancel` | Doing |
| 4 | Paper Overview | `/analyses/:id` | `OverviewScreen` / `OverviewViewModel` | `analyses/{id}`, `analyses/{id}/topics`; Remote Config | Doing |
| 5 | Topics | `/analyses/:id/topics` | `TopicMapScreen` / `TopicMapViewModel` | `analyses/{id}/topics`; Remote Config | Doing |
| 6 | Topic | `/analyses/:id/topics/:topicId` | `TopicDetailScreen` / `TopicDetailViewModel` | `topics/{topicId}`, `analyses/{id}/references` | Doing |
| 7 | References | `/analyses/:id/references` | `ReferenceListScreen` / `ReferenceListViewModel` | `analyses/{id}/references` | Doing |
| 8 | Reference | `/analyses/:id/references/:refId` | `ReferenceDetailScreen` / `ReferenceDetailViewModel` | `references/{refId}` | Doing |
| 9 | History | `/history` | `HistoryScreen` / `HistoryViewModel` | `users/{uid}/library`, `analyses/{id}` | Doing |
| 10 | Notifications | `/notifications` | `NotificationsScreen` / `NotificationsViewModel` | `users/{uid}/notifications`; FCM | Doing |
| 11 | Profile | `/profile` | `ProfileScreen` / `ProfileViewModel` | Firebase Auth; Remote Config; Crashlytics | Doing |
| — | Sheet Export report | (overlay của 4, 11) | `ExportSheet` / `ExportViewModel` | `ReportService` (PDF); `ReportFiles` (máy). Khi bật `enable_cloud_upload`: Cloudinary `reports/{uid}/…` (backend ký), `users/{uid}/reports` | Doing |

## 2. Flow

| Flow | Bước | Màn | Sự kiện Analytics | Test ARTEMIS | Trạng thái |
|---|---|---|---|---|---|
| A. Phân tích bài báo | Happy | 2 → 3 → 4 | `search`, `view_analysis` | TC-16 | Doing |
| | A1 đã phân tích | 2 → 4 | `search` (`cache_hit`) | TC-03 | Doing |
| | A2 share từ trình duyệt | Chrome → 2 | — | TC-05 | Doing |
| | A3 chạy nền + push | 3 → push → 4 | `open_notification` | TC-10 | Doing |
| | A-E1 sai định dạng | 2 | — | TC-04 | Doing |
| | A-E2 thất bại | 3 | — | — | Doing |
| | A-E3 offline | 3 | — | — | Doing |
| | A-E4 dừng | 3 + dialog | — | TC-15 | Doing |
| | Mất mạng khi bấm Analyze | 2 | — | TC-08 | Doing |
| | A-E5 không tới được server | 2 → 0 | — | TC-14 | Doing |
| B. Tìm chủ đề yếu | Happy | 4 → 5 → 6 → 8 | `filter_weak_topics`, `view_topic`, `view_reference` | TC-06, TC-07 | Doing |
| | B1, B2, B4 | 4 → 6; 6 → 6; 8 → 6 | `view_topic` | — | Doing |
| | B3 reference bịa | 8 + dialog | `view_reference` | — | Doing |
| | B-E1 không có chủ đề yếu | 5 | — | — | Doing |
| | B-E2 Unclassified | 5 → 7 | — | — | Doing |
| | Danh sách reference | 4 → 7 | — | TC-18 | Doing |
| | B-E3 lỗi tải | 5, 6 | — | — | Doing |
| C. Xem lại và xuất báo cáo | Happy | 9 → 4 → sheet | `export_report` | TC-09, TC-17, TC-19 | Doing |
| | C1–C4 | 9; 10 → 4; 9 → 3 | — | TC-17 | Doing |
| | C-E1 xuất báo cáo thất bại | sheet | non-fatal Crashlytics | — | Doing |
| | C-E2, C-E3, C-E4 | 9 + dialog | — | — | Doing |
| Phụ | Đăng nhập, hủy, đăng xuất | 1, 11 | `login`, `logout` | TC-01, TC-02, TC-13 | Doing |
| | Các tab, Remote Config | 2, 9, 11 | — | TC-11, TC-12 | Doing |

## 3. Component

Tất cả đã có widget, đã qua test tràn ở 360 / 412 dp (chữ 100% và 130%), vùng chạm và contrast trong `test/widgets/design_system_test.dart`.

| Component (Figma page 05) | Widget | Trạng thái |
|---|---|---|
| Button | `AppButton` | Done |
| Text field | `AppTextField` | Done |
| Card | `AppCard` | Done |
| App bar | `AppTopBar` | Done |
| Bottom nav | `AppBottomNav` | Done |
| Dialog | `AppDialog`, `showAppDialog` | Done |
| Loading | `SkeletonList` | Done |
| Empty / Error | `StateView` | Done |
| Banner | `InfoBanner` | Done |
| Section label | `SectionLabel` | Done |
| Status chip | `StatusChip` | Done |
| Weak tag | `WeakTag` | Done |
| Filter chip | `AppFilterChip` | Done |
| Stacked status bar | `StatusBar` | Done |
| Reference card | `ReferenceCard` | Done |
| History card | `HistoryCard` | Done |
| Topic tree node | `TopicTreeNode` | Done |
| Stepper | `AnalysisStepper` | Done |
| Notification tile | `NotificationTile` | Done |
| Export sheet | `ExportSheet` | Done |
| Remote Config row | `RemoteConfigRow` | Done |
| Cited / Actual table | `CitedActualTable` | Done |

## 4. Khác biệt so với thiết kế (deviations)

### 4.1 So với thiết kế Lab 2

Thầy đã duyệt đổi sang sản phẩm RefCheck + Saffron, và nhóm làm lại thiết kế trên Stitch.

| Lab 2 | Lab 3 | Lý do |
|---|---|---|
| Flow B: kết nối server | Flow B: tìm chủ đề yếu. Connect server thành luồng phụ | Đề tài mới có cây chủ đề là chức năng chính |
| 8 màn | 12 màn: thêm Sign-in, Topics, Topic, Notifications | Lab 3 yêu cầu đăng nhập, FCM; đề tài mới cần cây chủ đề |
| Tab Settings | Tab Profile, có khu Firebase demo | Lab 3 yêu cầu profile và khu demo |
| Upload PDF ở màn Check | Bỏ. Thêm share link từ trình duyệt | Backend chạy trên laptop; bài Final bỏ Cloud Storage nên không có chỗ lưu PDF đầu vào |
| Tiến độ qua WebSocket | Tiến độ qua Firestore | Có realtime và offline cache; xem lại được khi backend tắt |
| API key nhập trên máy | Key nằm ở backend | Không để key trên điện thoại |
| Viền ô nhập `#CBD5E1` (1.42:1) | `#64748B` (4.55:1) | Đạt WCAG 1.4.11 |

### 4.2 Giữa Figma và app

| Màn / component | Figma | App | Lý do | Figma đã cập nhật? |
|---|---|---|---|---|
| Export | `Copy link` hiện snackbar `Link copied` | Sheet đóng lại rồi mới hiện snackbar | Snackbar nằm dưới sheet nên không thấy được | Không cần |
| Reference | Dialog `Likely fabricated` chỉ tự mở | Banner có thêm nút `Details` để mở lại | Đóng dialog xong không còn cách xem lại | Chưa |
| Analyzing | `Back` về `/analyze` | Quay lại màn trước; không có lịch sử thì về `/analyze` | Mở từ History thì nên về History | Không cần |
| Export | `Uploading` → `Uploaded`, có `Copy link` | Mặc định `Creating PDF…` → `Saved on device`, có `Open` và `Share`. Upload chỉ chạy khi bật `enable_cloud_upload`, và lên Cloudinary thay vì Cloud Storage | Nhóm dùng gói Spark, không có bucket Cloud Storage; thầy cho phép dùng Cloudinary thay thế | Có |
| Export | `Upload failed` | `Export failed` | Trên Spark, lỗi đến từ khâu tạo hoặc lưu PDF, không phải upload | Có |
| Export | Nút `Done`, `Cancel`, `×` trong sheet | Kéo xuống hoặc chạm ngoài sheet để đóng | Cùng tác dụng, ít chữ hơn | Không cần |
| Sign-in | Logo Google, logo Realtron | Icon Material thay thế | Chưa có file ảnh; cần thay trước khi nộp | Không cần |
| Topics, Topic | Chỉ có cây chủ đề và danh sách reference | Topics có thẻ `Key topics` (6 chủ đề điểm Saffron cao nhất, chạm để mở). Topic có dòng `31 mentions · #2 of 35 by Saffron score`, chip `Related topics` và danh sách `Key authors`. Tất cả ẩn khi phân tích chưa có dữ liệu này | Dùng phần đầu ra của Saffron trước đây bị bỏ (điểm, chủ đề liên quan, tác giả) | Chưa |
| Chữ mới | Không có trong `user-flow.md` | `Sign-in failed`, `Couldn't start`, `N with errors`, `Couldn't save`, `Couldn't delete`, `Error logged`, `Setup needed`, `No app can open PDF`, nút `View` trên snackbar push | Trường hợp lỗi thật mà thiết kế chưa có | Chưa |
