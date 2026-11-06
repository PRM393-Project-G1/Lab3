# Test plan: Realtron

Công cụ: **Google ARTEMIS**, commit `351ca8422f7b5b54e80a9c1ce03a222e02415b6b`, profile Flash cho test hồi quy và Pro cho phiên khám phá. Code test và cách chạy: [`e2e_test/`](../e2e_test/README.md).

> **Trạng thái: chưa chạy trên thiết bị thật.** Suite cần điện thoại, project Firebase, backend và API key của model. Mục 4 và 5 sẽ được điền từ log thật, không điền tay.

Ngoài E2E còn có unit test và widget test trong `test/`, dùng service giả.

## 1. Luồng quan trọng

| Luồng | Màn hình | Test |
|---|---|---|
| Đăng nhập, đăng xuất | 1, 0, 2, 11 | TC-01, TC-02, TC-13 |
| A. Phân tích bài báo | 2, 3, 4 | TC-03, TC-04, TC-05, TC-08, TC-10, TC-14, TC-15, TC-16 |
| B. Tìm chủ đề yếu | 4, 5, 6, 7, 8 | TC-06, TC-07, TC-18 |
| C. Xem lại và xuất báo cáo | 9, 4, sheet Export | TC-09, TC-17, TC-19 |
| Tab và Profile | 2, 9, 11 | TC-11, TC-12 |

## 2. Test case

Mỗi test gửi một chỉ dẫn qua `ArtemisClient`, yêu cầu agent kết thúc bằng một object JSON, rồi so sánh các giá trị đó. Mỗi test tự mở lại app từ trạng thái đã đóng, nên không phụ thuộc thứ tự chạy. Chỉ dẫn đầy đủ nằm trong code test.

| ID | Flow | Điều kiện đầu | Chỉ dẫn (tóm tắt) | Kết quả mong đợi (giá trị agent báo) | Kiểu | Kết quả |
|---|---|---|---|---|---|---|
| TC-01 | Đăng nhập | Đã đăng xuất | Continue with Google → chọn tài khoản test | Tab đang chọn `Analyze`; các tab `Analyze, History, Profile` | Native | Chưa chạy |
| TC-02 | Đăng nhập | Đã đăng xuất | Continue with Google → Back ở account picker | `Sign-in cancelled`; vẫn còn nút đăng nhập | Lỗi, Native | Chưa chạy |
| TC-03 | A1 | Đã đăng nhập, bài đã phân tích | Nhập `1706.03762` → Analyze | `Paper Overview`, đúng tên bài, số reference > 0, dòng `N topics · M weak`; có sự kiện `search` | Happy | Chưa chạy |
| TC-04 | A-E1 | Đã đăng nhập | Nhập `abc123` | `Not a valid arXiv ID`; nút Analyze bị tắt | Lỗi | Chưa chạy |
| TC-05 | A2 | Đã đăng nhập | Chrome → Share → Realtron | Màn `Analyze`, ô nhập chứa `1706.03762`; nút Analyze bật | Thay thế, Native | Chưa chạy |
| TC-06 | B | Đã đăng nhập, bài đã phân tích | Overview → Explore → chip Weak | Mọi dòng đều có nhãn Weak và chân trang đúng ngưỡng, hoặc `No weak topics`; có sự kiện `filter_weak_topics` | Happy | Chưa chạy |
| TC-07 | B | Đã đăng nhập, bài đã phân tích | Explore → chủ đề đầu → reference đầu | Có tên chủ đề, trạng thái hợp lệ, bảng Cited/Actual; có sự kiện `view_topic`, `view_reference` | Happy | Chưa chạy |
| TC-08 | Mất mạng | Đã đăng nhập, bật chế độ máy bay | Nhập bài chưa có → Analyze | `Can't reach server`; có Retry; vẫn ở màn Analyze | Lỗi | Chưa chạy |
| TC-09 | C | Đã đăng nhập, bài đã phân tích | Overview → Report | `Saved on device`; `realtron_1706.03762.pdf · N KB`; nút `Open, Share`; có sự kiện `export_report` | Happy | Chưa chạy |
| TC-10 | A3 | Đã đăng nhập, app chạy nền | Backend gửi push → mở từ notification shade | `Paper Overview`, đúng tên bài | Native | Chưa chạy |
| TC-11 | Profile | Đã đăng nhập, Console chưa đổi giá trị | Profile → mục Remote Config | 5 giá trị khớp `remote-config-defaults.json` | Happy | Chưa chạy |
| TC-12 | Tab | Đã đăng nhập | Lần lượt mở 3 tab | Đúng tiêu đề từng tab | Happy | Chưa chạy |
| TC-13 | Đăng xuất | Đã đăng nhập | Profile → Sign out | Về màn đăng nhập, không còn tab; có sự kiện `logout` | Happy | Chưa chạy |
| TC-14 | A-E5 | Đã đăng nhập | Profile → Change → nhập `http://100.1.2.3:8000` → Test | `Can't reach server` kèm 3 gợi ý, hoặc `Timed out`; nút Save bị tắt | Lỗi | Chưa chạy |
| TC-15 | A-E4 | Đã đăng nhập, bài chưa có kết quả | Analyze → Stop → xác nhận | Đúng 5 bước; dialog `Stop analysis?`; rời màn Analyzing | Lỗi | Chưa chạy |
| TC-16 | A | Đã đăng nhập, 3 bài chưa phân tích | Analyze → đợi xong → View results | `Paper Overview`, số reference > 0 | Happy | Chưa chạy |
| TC-17 | C, C1 | Đã đăng nhập, bài đã phân tích | History → tìm chuỗi không khớp → xoá → mở thẻ | `No results`; mở được `Paper Overview` đúng bài | Thay thế | Chưa chạy |
| TC-18 | B | Đã đăng nhập, bài đã phân tích | Overview → References (N) → đếm | Tiêu đề `References`; số đếm bằng N | Happy | Chưa chạy |
| TC-19 | C | Đã đăng nhập, máy có app đọc PDF | Report → Open | PDF hiện ra, đúng tên bài và `arXiv:1706.03762` | Native | Chưa chạy |

## 3. Độ phủ theo yêu cầu đề

| Yêu cầu | Test |
|---|---|
| Đăng nhập | TC-01, TC-02 |
| Hành động chính | TC-03, TC-16 |
| Mỗi tab | TC-12 |
| Mỗi loại màn chi tiết | Overview TC-03; Topic, Reference TC-07; danh sách Reference TC-18 |
| Xuất báo cáo | TC-09, TC-19 |
| Giá trị Remote Config | TC-11 |
| Đăng xuất | TC-13 |
| Nhánh lỗi | TC-02, TC-04, TC-08, TC-14, TC-15 |
| Tương tác native | TC-01, TC-02, TC-05, TC-10, TC-19 |
| Kiểm tra sự kiện Analytics (Logcat) | TC-03, TC-06, TC-07, TC-09, TC-13 |

**Không có test E2E, và lý do:**

| Mục | Lý do | Thay thế |
|---|---|---|
| Upload lên Cloudinary | Chưa viết test E2E; cần backend có `CLOUDINARY_*` và bật `enable_cloud_upload` | Unit test `CloudinaryStorageService`, chữ ký ở backend; widget test với service giả |
| C-E1 xuất thất bại | Không gây lỗi ghi file được trên máy thật | Unit test và widget test |
| A-E2 phân tích thất bại, A-E3 mất mạng giữa chừng | Phải điều khiển backend hoặc canh đúng thời điểm | Unit test `ProgressViewModel` |
| B-E2 Unclassified, B3 reference bịa | Phụ thuộc dữ liệu thật của bài | Widget test; phiên khám phá |
| Nhận push khi app đang mở hoặc đã tắt | Cần quan sát ở Console và trên máy | Bằng chứng trong `evidence/fcm/` |

## 4. Kết quả

Chưa có. Sau khi chạy `uv run pytest --count=3`, dán bảng do `uv run python summarize.py` in ra vào đây. Log gốc và trace ID nằm trong `evidence/e2e/results.jsonl`.

Test nào không đạt 3/3 hoặc bị bỏ qua thì giải thích ở đây: nguyên nhân là app, thời điểm hay chỉ dẫn mơ hồ, và đã sửa thế nào.

## 5. Phiên khám phá

Chưa chạy. `uv run python exploratory.py` chạy một phiên bằng profile Pro và ghi báo cáo vào `evidence/e2e/exploratory.md`. Liệt kê các vấn đề tìm được ở đây.
