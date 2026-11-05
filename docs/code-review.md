# AI code review: Realtron

- **Công cụ:** Claude Code, lệnh `/code-review` mức high, chạy ngày 05/11/2026 trên `lib/`.
- **Giới hạn:** đề khuyên review theo pull request. Lần này review cả `lib/` vì thư mục chưa phải git repo. Công cụ review cũng là AI đã viết phần lớn code này.
- **Output:** cột Finding dưới đây là nội dung công cụ trả về, đã rút gọn và dịch.

> **Trạng thái:** cột Quyết định mới là **đề xuất**, người nộp cần tự xem lại và giải thích được khi thầy hỏi. Chưa sửa finding nào. Mỗi fix sẽ là một commit riêng ghi mã finding.

## Findings

| ID | Tool | File:line | Kind | Finding | Quyết định | Lý do | Fix |
|---|---|---|---|---|---|---|---|
| CR-01 | Claude Code | `lib/viewmodels/analyze_view_model.dart:135` | Bug | `await` một lệnh ghi Firestore. Khi mất mạng, lệnh này không hoàn tất, nên nút Analyze quay mãi và bài đã có cache không mở được | Accepted | Bảng điểm trừ lỗi "Spinner forever"; kiến trúc hứa kết quả xem được khi backend tắt | Chưa |
| CR-02 | Claude Code | `lib/viewmodels/analyze_view_model.dart:144` | Bug | Mất mạng rơi vào `catch` chung: hiện `Couldn't start` và ghi non-fatal, thay vì banner `Can't reach server` | Accepted | Đề yêu cầu lỗi có thông báo rõ; TC-08 sẽ không đạt nếu không sửa | Chưa |
| CR-03 | Claude Code | `lib/viewmodels/auth_view_model.dart:74` | Bug | Không đăng ký lại token FCM khi đổi tài khoản, cũng không gỡ token khi đăng xuất. Tài khoản sau không nhận được push, tài khoản trước vẫn nhận | Accepted | Đề yêu cầu đăng xuất xoá dữ liệu của user; thông báo gửi nhầm người | Chưa |
| CR-04 | Claude Code | `lib/viewmodels/auth_view_model.dart:71` | Bug | `ensureUser` chạy trước khi bật messaging. Mạng yếu thì nó treo hoặc lỗi, nên không có listener push cho cả phiên | Accepted | Đề yêu cầu nhận push ở cả 3 trạng thái app | Chưa |
| CR-05 | Claude Code | `lib/utils/arxiv_id.dart:2` | Bug | ID kiểu cũ có dấu `/` (`hep-th/9901001`) qua được kiểm tra, rồi hỏng đường dẫn Firestore, route và tên file | Modified | Từ chối ID kiểu cũ ngay ở ô nhập, không sửa cả 3 nơi. Giới hạn phạm vi: backend chưa thống nhất cách mã hoá ID | Chưa |
| CR-06 | Claude Code | `lib/viewmodels/connect_view_model.dart:76` | Bug | Chỉ bắt `ApiException`. URL `ftp://…` hoặc chứng chỉ https lỗi làm màn hình kẹt ở `Testing…` | Accepted | Bảng điểm trừ lỗi "Spinner forever" | Chưa |
| CR-07 | Claude Code | `lib/viewmodels/notifications_view_model.dart:52` | Bug | Đợi ghi trạng thái đã đọc rồi mới chuyển màn, nên mất mạng thì chạm thông báo không có tác dụng | Accepted | Đề yêu cầu chạm thông báo phải chuyển màn | Chưa |
| CR-08 | Claude Code | `lib/services/api_client.dart:78` | Bug | Lỗi làm mới token không được đổi thành `ApiException`, nên Stop thất bại mà không có thông báo | Accepted | Đề yêu cầu lỗi có thông báo rõ, không crash | Chưa |
| CR-09 | Claude Code | `lib/services/library_feed.dart:40` | Bug | Lỗi theo dõi một bài làm cả History thành `Couldn't load` | Modified | Giữ danh sách, chỉ bài đó không có trạng thái. Danh sách vẫn đọc được thì không nên ẩn | Chưa |
| CR-10 | Claude Code | `lib/viewmodels/progress_view_model.dart:31` | Bug | Không có document `analyses/{id}` thì màn Analyzing ở 0% mãi, không có lỗi hay Retry | Accepted | Bảng điểm trừ lỗi "Spinner forever" | Chưa |

## AI đã dùng trong Lab 3

| Công cụ | Mục đích |
|---|---|
| Google Stitch | Sinh UI |
| Claude (Claude Code) | Viết prompt, viết code và test, viết tài liệu, code review |
