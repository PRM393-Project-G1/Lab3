# Flutter handoff: Realtron

> Bàn giao cho lập trình viên Flutter chưa biết dự án. Mỗi màn có **6 mục**: Layout · Components · States · Interactions · Navigation · UI constraints. Cuối file có **2 bảng mapping**: token → Flutter và component → widget.
> Liên quan: [persona](../design/persona.md) · [user-flow](../design/user-flow.md) (chuỗi chữ chuẩn) · [DESIGN.md](../design/DESIGN.md) · [design-decisions](../design/design-decisions.md) · Figma: [Realtron](https://www.figma.com/design/gPn3Z9LnTN8Js3QxbrH5Gu/Realtron) page 03 Final UI / 04 Design System / 05 Components.

---

## 0. Quy ước chung

| Mục | Quy ước |
|---|---|
| Nền tảng | Android, Material 3, 360–412 dp, chỉ màn dọc |
| Kiến trúc | MVVM + Provider. Xem [`docs/architecture.md`](../docs/architecture.md) |
| Màu, chữ, khoảng cách | **Không ghi cứng trong màn hình.** Đọc từ `Theme.of(context)`, `context.status(...)`, `AppSpacing`, `AppRadius`, `AppSizes` |
| Trạng thái màn | Mỗi màn có `ViewState<T>`: `Loading` / `Empty` / `Failure` / `Data`, do ViewModel giữ |
| Trạng thái reference | Luôn hiển thị bằng `StatusChip`. Thứ tự **Hallucinated > Error > Warning > Unverified > Verified** |
| Chữ | Dùng đúng chuỗi trong `user-flow.md`. Không ghi tên backend hay công cụ |
| Nguồn dữ liệu | Kết quả đọc từ Firestore. Chỉ `Connect server` và lúc bắt đầu / dừng phân tích mới gọi backend qua Tailscale |
| Trợ năng | Nút, item danh sách, node cây, thanh trạng thái có `Semantics` label (cũng để ARTEMIS đọc) |

---

## Màn 0: Connect server · `screens/connect_screen.dart`

| Mục | Nội dung |
|---|---|
| **Layout** | `AppTopBar` "Connect server". `AppCard` chứa ô URL. Dưới là banner kết quả, rồi nút `Test` và `Continue` xếp dọc |
| **Components** | `AppTextField` (label `Server URL`, helper `e.g. http://100.x.x.x:8000`, nút Paste) · `AppButton.secondary` `Test` · `AppButton.primary` `Continue` / `Save` · `InfoBanner` |
| **States** | `idle` · `testing` (nút `Testing…`, có spinner) · `connected` (banner `Connected · 84 ms`) · `failed` (`Can't reach server` + chip `Tailscale on?` `Backend running?` `Using http://?` + `Retry`; hoặc `Timed out`; hoặc `Not a Realtron server`; ô trống: `Enter a server URL`) |
| **Interactions** | `Test` gọi `GET /api/health`. Tự thêm `http://` khi thiếu. Gõ lại thì quay về `idle` |
| **Navigation** | `/connect` khi chưa lưu server → `Continue` → `/analyze`. Từ Profile: `/profile/server`, `Save` → quay lại Profile |
| **UI constraints** | `Continue` **chỉ bật sau khi test thành công**. Lỗi phải đúng nguyên nhân, không ghi chung "network error" (P03) |

## Màn 1: Sign-in · `screens/sign_in_screen.dart`

| Mục | Nội dung |
|---|---|
| **Layout** | Giữa màn: logo, `Realtron` (`headline-lg`), `Know what a paper stands on.`, nút Google. Không có bottom nav |
| **Components** | `AppButton.secondary` có logo Google `Continue with Google` · `InfoBanner` |
| **States** | `default` · `signing in` (nút loading) · `cancelled` (banner `Sign-in cancelled`) · `offline` (banner `You're offline`) |
| **Interactions** | Google Sign-In qua `AuthService`. Hủy ở account picker không tính là lỗi hệ thống |
| **Navigation** | Thành công: chưa lưu server → `/connect`; đã lưu → `/analyze`. Router chặn mọi route khác khi chưa đăng nhập |
| **UI constraints** | Không có câu giới thiệu dài. Banner nằm ngay trên nút |

## Màn 2: Analyze (tab) · `screens/analyze_screen.dart`

| Mục | Nội dung |
|---|---|
| **Layout** | `AppTopBar` `Analyze` + chuông. `AppCard` nhập liệu → section `Recent` + `See all` → tối đa `max_recent_checks` thẻ gần đây |
| **Components** | `AppTextField` (label `arXiv ID or link`, helper `e.g. 1706.03762`, Paste) · chip `Try 1706.03762` · switch `AI check` · `AppButton.primary` `Analyze` · `HistoryCard(compact)` · `InfoBanner` |
| **States** | Bình thường · `invalid` (`Not a valid arXiv ID`, viền đỏ, nút khoá) · `server unreachable` (`Can't reach server` — `Check Tailscale and backend.` + `Retry` `Change server`) · `first use` (không có Recent, dòng `No checks yet`) · nhận link share (đã điền sẵn) |
| **Interactions** | `AnalyzeViewModel` chuẩn hoá ID (`1706.03762`, `arxiv.org/abs/…`, `/pdf/…`). Có `analyses/{id}` với status `done` → mở Overview ngay. Chưa có → `POST /api/analyses` |
| **Navigation** | Tab 1. `Analyze` → `/analyses/:id/progress` hoặc `/analyses/:id`. Chuông → `/notifications`. `See all` → `/history` |
| **UI constraints** | Một nút Paste duy nhất. Placeholder không bị cắt ở 360 dp. Kiểm tra định dạng trên máy, không gửi lên server |

## Màn 3: Analyzing · `screens/progress_screen.dart`

| Mục | Nội dung |
|---|---|
| **Layout** | `AppTopBar` `Analyzing…`. Tên bài + arXiv ID → thanh tiến độ `18/41 refs` → stepper 5 bước → `Run in background` và `Stop`. **Không có bottom nav** |
| **Components** | `AnalysisStepper` (`References` · `Verify` · `Fabrication check` · `Full text` · `Topics`) · `LinearProgressIndicator` · `AppButton` · `InfoBanner` · `AppDialog` |
| **States** | `running` · `done` (`Done`, 5 bước xong, `View results`) · `failed` (`Analysis failed` + lý do + `Retry` `Edit`) · `offline` (`Offline · will resume`) · dialog `Stop analysis?` (`Progress will be lost.` — `Keep going` / `Stop`) |
| **Interactions** | `ProgressViewModel` nghe `analyses/{id}` trên Firestore. `Stop` → `POST /api/analyses/{id}/cancel` |
| **Navigation** | `Run in background` / Back → về `/analyze`, job vẫn chạy. `View results` → thay bằng `/analyses/:id`. `Edit` → `/analyze` |
| **UI constraints** | Stepper không có mô tả con. Mỗi bước có Semantics `"<bước>: Done / In progress / Pending / Failed"` |

## Màn 4: Overview · `screens/overview_screen.dart`

| Mục | Nội dung |
|---|---|
| **Layout** | `AppTopBar` `Paper Overview` + action `Report`. Thứ tự: tên bài, tác giả → thẻ cảnh báo nặng nhất → thanh trạng thái 5 màu + số đếm → thẻ `Topics` (`9 topics · 2 weak`, các chủ đề yếu, `Explore`) |
| **Components** | `AppCard` · `InfoBanner` · `StatusBar` · `StatusChip` (chạm để lọc) · `TopicTreeNode` · `AppButton` · `SkeletonList` · `StateView` |
| **States** | `loading` (skeleton) · `error` (`Couldn't load` + `Retry`) · thẻ cảnh báo theo mức: `2 may be fabricated` + `Review`; không có thì lỗi metadata; sạch thì không hiện · có / không có chủ đề yếu |
| **Interactions** | `OverviewViewModel` đọc `summary` + `topics`, tính chủ đề yếu theo `weak_topic_threshold`. Log `view_analysis` |
| **Navigation** | `Review` / chip → `/analyses/:id/references?filter=`. `Explore` → `/analyses/:id/topics`. Chạm chủ đề yếu → `/analyses/:id/topics/:topicId`. `Report` → sheet Export. Mở từ push không có lịch sử → Back về `/history` |
| **UI constraints** | Tin nặng nhất luôn ở trên cùng. `Report` ẩn khi `enable_report_export = false` |

## Màn 5: Topics · `screens/topic_map_screen.dart`

| Mục | Nội dung |
|---|---|
| **Layout** | `AppTopBar` `Topics` + tên bài. Chip `All` / `Weak` → cây → nhóm `Unclassified · 3` → chân trang `Weak: ≥ 50% refs have issues` |
| **Components** | `AppFilterChip` · `TopicTreeNode` · `AppCard` · `StateView` · `SkeletonList` |
| **States** | `loading` · `error` · `All` · `Weak` · rỗng ở `Weak` (`No weak topics` + `Show all`) |
| **Interactions** | `TopicMapViewModel` dựng cây từ danh sách phẳng, cộng dồn số đếm, lọc yếu. Chạm chevron mở / đóng; chạm hàng mở Topic. Log `filter_weak_topics` |
| **Navigation** | → `/analyses/:id/topics/:topicId`. `Unclassified` → `/analyses/:id/references?filter=unclassified` |
| **UI constraints** | Thụt lề có giới hạn; **từ cấp 4 trở xuống mở màn con**. Tên không bị cắt, tối đa 2 dòng. Chevron ≥ 48 dp. Con số phần trăm trong chân trang lấy từ Remote Config |

## Màn 6: Topic · `screens/topic_detail_screen.dart`

| Mục | Nội dung |
|---|---|
| **Layout** | Breadcrumb → tên chủ đề (`headline-md`) + `Weak` → thanh trạng thái + số đếm → `Subtopics` → chip lọc → danh sách reference |
| **Components** | `StatusBar` · `WeakTag` · `TopicTreeNode` · `AppFilterChip` · `ReferenceCard` |
| **States** | `loading` · `error` · có / không có Subtopics · lọc rỗng (`Nothing here`) |
| **Interactions** | Danh sách sắp theo mức nghiêm trọng. Log `view_topic` |
| **Navigation** | Subtopic → Topic con. Reference → `/analyses/:id/references/:refId` |
| **UI constraints** | Phần reference được dài hơn (là nội dung kết quả). Mỗi thẻ cả khối chạm được |

## Màn 7: References · `screens/reference_list_screen.dart`

| Mục | Nội dung |
|---|---|
| **Layout** | `AppTopBar` `References`. Tên bài, `41 refs` → ô `Search` → chip lọc có số đếm → danh sách |
| **Components** | `AppTextField` · `AppFilterChip` · `ReferenceCard` · `StateView` |
| **States** | `loading` · `error` · có bộ lọc · rỗng `Nothing here` |
| **Interactions** | Lọc theo `?filter=`, tìm trong tên và tác giả. Sắp Hallucinated > Error > Warning > Unverified > Verified |
| **Navigation** | Thẻ → `/analyses/:id/references/:refId` |
| **UI constraints** | Thẻ có status + tên + tác giả + năm + một dòng lỗi. Không có nút phụ trong thẻ |

## Màn 8: Reference · `screens/reference_detail_screen.dart`

| Mục | Nội dung |
|---|---|
| **Layout** | Banner trạng thái → tên reference → bảng `Cited` / `Actual` → `Copy fix` → `Topics` (chip) → `Source` |
| **Components** | `InfoBanner` · `CitedActualTable` · `AppButton` · chip chủ đề · `AppDialog` (Likely fabricated) |
| **States** | error/warning (`Copy fix`) · verified · hallucinated (dialog tự mở: `Likely fabricated`, `Closest match`, `Open` / `Search web`, lưu ý `May be wrong — check the source.`) |
| **Interactions** | `Copy fix` → snackbar `Fix copied`. Log `view_reference` |
| **Navigation** | Chip → Topic. `Source` / `Open` → trình duyệt ngoài |
| **UI constraints** | Ô lệch được tô màu **và** có nhãn. Không khẳng định chắc chắn là bịa |

## Màn 9: History (tab) · `screens/history_screen.dart`

| Mục | Nội dung |
|---|---|
| **Layout** | `AppTopBar` `History`. Ô `Search` → nhóm `Today` / `This week` / `Earlier` → thẻ |
| **Components** | `AppTextField` · `SectionLabel` · `HistoryCard` · `AppDialog` · `SkeletonList` · `StateView` |
| **States** | `loading` · `empty` (`No checks yet` + `Analyze a paper`) · `error` (`Couldn't load` + `Retry`) · `no results` (`No results`) · thẻ chip `Running` |
| **Interactions** | Đọc `users/{uid}/library`. Menu `Rename` / `Delete` (`Delete check?` — `Removed from your history.`), snackbar `Deleted`. Kéo xuống để làm mới |
| **Navigation** | Thẻ → Overview; thẻ `Running` → Analyzing. `Analyze a paper` → `/analyze` |
| **UI constraints** | Xoá chỉ ảnh hưởng lịch sử của người dùng này, không xoá kết quả dùng chung |

## Màn 10: Notifications · `screens/notifications_screen.dart`

| Mục | Nội dung |
|---|---|
| **Layout** | `AppTopBar` `Notifications` + Back → danh sách |
| **Components** | `NotificationTile` · `StateView` |
| **States** | có dữ liệu · chưa đọc (chấm + nhãn trợ năng) · `empty` (`No notifications`) |
| **Interactions** | `NotificationsViewModel` đọc `users/{uid}/notifications`. Chạm: đánh dấu đã đọc, log `notification_open` |
| **Navigation** | Mục `Analysis done` → `/analyses/:id` |
| **UI constraints** | Chỉ có loại thông báo "Analysis done" |

## Màn 11: Profile (tab) · `screens/profile_screen.dart`

| Mục | Nội dung |
|---|---|
| **Layout** | Avatar, tên, `Sign out` → switch `AI check` → `Server` + địa chỉ + `Change` → khu `Firebase demo` |
| **Components** | `AppCard` · `AppButton` · `RemoteConfigRow` · `AppDialog` · sheet Export |
| **States** | Bình thường · dialog `Test crash?` (`The app will close.` — `Cancel` / `Crash`) |
| **Interactions** | `Log error` ghi non-fatal; `Test crash` gây crash thử; `Export report` mở sheet. Giá trị Remote Config đọc qua `RemoteConfigService` |
| **Navigation** | `Change` → `/profile/server`. `Notifications` → `/notifications`. `Sign out` → xoá dữ liệu cục bộ → `/sign-in` |
| **UI constraints** | Key Remote Config dùng font mono. Không có nhãn "Verified Member" |

## Overlay: Sheet Export report · `widgets/export_sheet.dart`

| Mục | Nội dung |
|---|---|
| **Layout** | Bottom sheet bo `xl`, nền là Overview làm mờ. Icon trạng thái → tiêu đề → tên file (mono) → nút |
| **Components** | `ExportSheet` · `LinearProgressIndicator` · `AppButton` |
| **States** | `creating` (`Creating PDF…`) · `uploading` (`Uploading 64%`) · `uploaded` (`Uploaded`, `realtron_1706.03762.pdf · 214 KB`, `Copy link`, `Share`) · `saved` (`Saved on device`, tên file, `Open`, `Share`) · `failed` (`Export failed` + `Retry`) |
| **Interactions** | `ExportViewModel`: `ReportService` tạo PDF → `StorageService` upload `reports/{uid}/…` → lưu metadata. Log `export_report`. Lỗi upload ghi non-fatal |
| **Navigation** | Đóng sheet quay lại Overview |
| **UI constraints** | Luôn có phản hồi tiến độ. `Copy link` → snackbar `Link copied` |

---

## Bảng 1: Token → Flutter

| Nhóm | Token (Figma Variable) | Giá trị | Flutter |
|---|---|---|---|
| Color | `primary` / `on-primary` | `#1E3A8A` / `#FFFFFF` | `colorScheme.primary` / `onPrimary` |
| | `primary-container` / `on-primary-container` | `#DCE1FF` / `#00164E` | `colorScheme.primaryContainer` / `onPrimaryContainer` |
| | `background` | `#F8FAFC` | `scaffoldBackgroundColor` |
| | `surface` | `#FFFFFF` | `colorScheme.surface` |
| | `surface-container` / `-high` | `#F1F5F9` / `#E2E8F0` | `colorScheme.surfaceContainer` / `surfaceContainerHigh` |
| | `outline` / `outline-variant` | `#64748B` / `#E2E8F0` | `colorScheme.outline` / `outlineVariant` |
| | `text-primary` / `-secondary` | `#0F172A` / `#475569` | `colorScheme.onSurface` / `onSurfaceVariant` |
| | `text-muted` | `#64748B` | `AppTextExtras.muted`, đọc bằng `context.muted` |
| | `error` / `error-container` | `#B91C1C` / `#FEF2F2` | `colorScheme.error` / `errorContainer` |
| Status | Hallucinated · Error · Warning · Unverified · Verified | xem DESIGN.md mục 3 | `ThemeExtension<StatusColors>`; đọc bằng `context.status(RefStatus.x)` → `.foreground` `.icon` `.container` `.border` |
| Typography | `headline-lg` · `headline-md` | Source Serif 4, 28 · 22 / 600 | `textTheme.headlineLarge` · `headlineMedium` |
| | `paper-title` | Source Serif 4, 18 / 600 | `textTheme.titleLarge` |
| | `title-md` | Inter, 16 / 600 | `textTheme.titleMedium` |
| | `body-lg` · `body-md` | Inter, 16 · 14 / 400 | `textTheme.bodyLarge` · `bodyMedium` |
| | `label` | Inter, 14 / 600 | `textTheme.labelLarge` |
| | `overline` | Inter, 12 / 600, tracking 0.8 | `textTheme.labelMedium` |
| | `chip` | Inter, 12 / 600 | `textTheme.labelSmall` |
| | `mono` | JetBrains Mono, 13 | `context.mono` (`ThemeExtension<AppTextExtras>`) |
| Spacing | `space-xs` · `-sm` · `-md` · `-lg` · `-xl` | 4 · 8 · 16 · 24 · 32 | `AppSpacing.xs` · `sm` · `md` · `lg` · `xl`; lề trang `AppSpacing.page` |
| Radius | `sm` · `md` · `lg` · `xl` | 6 · 8 · 12 · 24 | `AppRadius.sm` · `md` · `lg` · `xl` |
| Elevation | Level 1 · Level 2 | xem DESIGN.md mục 5 | `AppElevation.card` · `raised` |
| Size | Vùng chạm · ô nhập | 48 · 56 | `AppSizes.minTap` · `inputHeight` |

## Bảng 2: Component (Figma) → Widget (Flutter)

| Figma component (page 05) | Variants / states | Widget | File |
|---|---|---|---|
| **Button** | primary · secondary · text · destructive × default · disabled · loading | `AppButton` | `widgets/app_button.dart` |
| **Text field** | default · focused · error · có nút Paste | `AppTextField` | `widgets/app_text_field.dart` |
| **Card** | default · tappable · viền theo trạng thái | `AppCard` | `widgets/app_card.dart` |
| **App bar** | title · back · action · subtitle | `AppTopBar` | `widgets/app_top_bar.dart` |
| **Bottom nav** | Analyze · History · Profile | `AppBottomNav` | `widgets/app_bottom_nav.dart` |
| **Dialog** | xác nhận · destructive | `showAppDialog` | `widgets/app_dialog.dart` |
| **Loading** | skeleton danh sách / thẻ | `SkeletonList` | `widgets/skeleton_list.dart` |
| **Empty / Error** | empty · error + Retry | `StateView` | `widgets/state_view.dart` |
| **Banner** | error · warning · success · info · offline | `InfoBanner` | `widgets/info_banner.dart` |
| **Section label** | có / không có action | `SectionLabel` | `widgets/section_label.dart` |
| **Status chip** | 5 trạng thái · có số đếm | `StatusChip` | `widgets/status_chip.dart` |
| **Weak tag** | — | `WeakTag` | `widgets/weak_tag.dart` |
| **Filter chip** | selected · unselected · có số đếm | `AppFilterChip` | `widgets/app_filter_chip.dart` |
| **Stacked status bar** | có / không có chú thích | `StatusBar` | `widgets/status_bar.dart` |
| **Reference card** | full · compact | `ReferenceCard` | `widgets/reference_card.dart` |
| **History card** | full · compact · running · failed | `HistoryCard` | `widgets/history_card.dart` |
| **Topic tree node** | collapsed · expanded · weak · leaf · unclassified | `TopicTreeNode` | `widgets/topic_tree_node.dart` |
| **Stepper** | pending · active · done · failed | `AnalysisStepper` | `widgets/analysis_stepper.dart` |
| **Notification tile** | unread · read | `NotificationTile` | `widgets/notification_tile.dart` |
| **Export sheet** | creating · uploading · uploaded · failed | `ExportSheet` | `widgets/export_sheet.dart` |
| **Remote Config row** | — | `RemoteConfigRow` | `widgets/remote_config_row.dart` |
| **Cited / Actual table** | khớp · lệch | `CitedActualTable` | `widgets/cited_actual_table.dart` |
