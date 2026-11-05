# Analytics plan: Realtron

> 9 sự kiện, tất cả gửi qua `lib/firebase/analytics_service.dart`. Không gửi tên, email hay nội dung cá nhân. `search_term` chỉ là arXiv ID công khai.
> Trạng thái: đã có trong code và có test bằng service giả. **Chưa kiểm tra trên DebugView**, vì chưa có project Firebase thật.

| Sự kiện | Tham số | Khi nào | Câu hỏi trả lời được | Nơi gửi |
|---|---|---|---|---|
| `login` | `method` | Đăng nhập Google thành công | Có bao nhiêu lượt đăng nhập? | `AuthViewModel` |
| `search` | `search_term`, `cache_hit` | Bấm `Analyze` với ID hợp lệ | Bao nhiêu lượt dùng lại kết quả có sẵn? | `AnalyzeViewModel` |
| `view_analysis` | `analysis_id`, `ref_count`, `weak_topic_count` | Mở Overview | Bài được xem có bao nhiêu chủ đề yếu? | `OverviewViewModel` |
| `view_topic` | `topic_id`, `topic_name`, `is_weak` | Mở Topic | Người dùng có đi vào chủ đề yếu không? | `TopicDetailViewModel` |
| `view_reference` | `reference_id`, `status` | Mở Reference | Trạng thái nào được xem nhiều nhất? | `ReferenceDetailViewModel` |
| `filter_weak_topics` | `analysis_id` | Chọn chip `Weak` | Bộ lọc có được dùng không? | `TopicMapViewModel` |
| `export_report` | `analysis_id`, `file_size_kb` | Lưu PDF xong (và upload xong, nếu bật `enable_cloud_upload`) | Báo cáo có được xuất không? | `ExportViewModel` |
| `notification_open` | `notification_type` | Chạm thông báo hoặc push | Push có kéo người dùng quay lại không? | `NotificationsViewModel`, `RealtronApp` |
| `logout` | | Bấm `Sign out` | Có bao nhiêu lượt đăng xuất? | `ProfileViewModel` |
