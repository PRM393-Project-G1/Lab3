# AI code review: Realtron

- **Công cụ:** Claude Code, lệnh `/code-review` mức high, chạy ngày 05/11/2026 trên `lib/`.
- **Giới hạn:** đề khuyên review theo pull request. Lần này review cả `lib/` vì thư mục chưa phải git repo. Công cụ review cũng là AI đã viết phần lớn code này.
- **Output:** cột Finding dưới đây là nội dung công cụ trả về, đã rút gọn và dịch.

> **Trạng thái:** cột Quyết định mới là **đề xuất**, người nộp cần tự xem lại và giải thích được khi thầy hỏi. Đã sửa cả 10 finding. CR-01 nằm trong commit `6c95c84` (`small fix`), nên tin nhắn commit không ghi mã finding. CR-02 đến CR-10 nằm chung trong commit `be3ab33` (`fixed 10 bugs`), không tách riêng từng fix như đề yêu cầu.

## Findings

| ID | Tool | File:line | Kind | Finding | Quyết định | Lý do | Fix |
|---|---|---|---|---|---|---|---|
| CR-01 | Claude Code | `lib/viewmodels/analyze_view_model.dart:135` | Bug | `await` một lệnh ghi Firestore. Khi mất mạng, lệnh này không hoàn tất, nên nút Analyze quay mãi và bài đã có cache không mở được | Accepted | Bảng điểm trừ lỗi "Spinner forever"; kiến trúc hứa kết quả xem được khi backend tắt | `6c95c84` |
| CR-02 | Claude Code | `lib/viewmodels/analyze_view_model.dart:144` | Bug | Mất mạng rơi vào `catch` chung: hiện `Couldn't start` và ghi non-fatal, thay vì banner `Can't reach server` | Accepted | Đề yêu cầu lỗi có thông báo rõ; TC-08 sẽ không đạt nếu không sửa | `be3ab33` |
| CR-03 | Claude Code | `lib/viewmodels/auth_view_model.dart:74` | Bug | Không đăng ký lại token FCM khi đổi tài khoản, cũng không gỡ token khi đăng xuất. Tài khoản sau không nhận được push, tài khoản trước vẫn nhận | Accepted | Đề yêu cầu đăng xuất xoá dữ liệu của user; thông báo gửi nhầm người | `be3ab33` |
| CR-04 | Claude Code | `lib/viewmodels/auth_view_model.dart:71` | Bug | `ensureUser` chạy trước khi bật messaging. Mạng yếu thì nó treo hoặc lỗi, nên không có listener push cho cả phiên | Accepted | Đề yêu cầu nhận push ở cả 3 trạng thái app | `be3ab33` |
| CR-05 | Claude Code | `lib/utils/arxiv_id.dart:2` | Bug | ID kiểu cũ có dấu `/` (`hep-th/9901001`) qua được kiểm tra, rồi hỏng đường dẫn Firestore, route và tên file | Modified | Từ chối ID kiểu cũ ngay ở ô nhập, không sửa cả 3 nơi. Giới hạn phạm vi: backend chưa thống nhất cách mã hoá ID | `be3ab33` |
| CR-06 | Claude Code | `lib/viewmodels/connect_view_model.dart:76` | Bug | Chỉ bắt `ApiException`. URL `ftp://…` hoặc chứng chỉ https lỗi làm màn hình kẹt ở `Testing…` | Accepted | Bảng điểm trừ lỗi "Spinner forever" | `be3ab33` |
| CR-07 | Claude Code | `lib/viewmodels/notifications_view_model.dart:52` | Bug | Đợi ghi trạng thái đã đọc rồi mới chuyển màn, nên mất mạng thì chạm thông báo không có tác dụng | Accepted | Đề yêu cầu chạm thông báo phải chuyển màn | `be3ab33` |
| CR-08 | Claude Code | `lib/services/api_client.dart:78` | Bug | Lỗi làm mới token không được đổi thành `ApiException`, nên Stop thất bại mà không có thông báo | Accepted | Đề yêu cầu lỗi có thông báo rõ, không crash | `be3ab33` |
| CR-09 | Claude Code | `lib/services/library_feed.dart:40` | Bug | Lỗi theo dõi một bài làm cả History thành `Couldn't load` | Modified | Giữ danh sách, chỉ bài đó không có trạng thái. Danh sách vẫn đọc được thì không nên ẩn | `be3ab33` |
| CR-10 | Claude Code | `lib/viewmodels/progress_view_model.dart:31` | Bug | Không có document `analyses/{id}` thì màn Analyzing ở 0% mãi, không có lỗi hay Retry | Accepted | Bảng điểm trừ lỗi "Spinner forever" | `be3ab33` |

## AI đã dùng trong Lab 3

| Công cụ | Mục đích |
|---|---|
| Google Stitch | Sinh UI |
| Claude (Claude Code) | Viết prompt, viết code và test, viết tài liệu, code review |
