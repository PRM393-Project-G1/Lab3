1. Các thành phần chính của dự án

| Thành phần / công nghệ | Hiểu đơn giản | Vai trò trong Realtron |
|---|---|---|
| Flutter + Dart | Bộ công cụ và ngôn ngữ viết app | Dựng giao diện Android: nhập bài, xem tiến độ, kết quả, lịch sử… |
| MVVM + Provider | Cách tổ chức code và cập nhật giao diện | Tách phần hiển thị khỏi logic xử lý; khi dữ liệu đổi thì giao diện cập nhật |
| go_router | Bộ điều hướng | Chuyển giữa các màn, kiểm tra đăng nhập, mở bài từ thông báo |
| Python + FastAPI | Ngôn ngữ và framework backend | Nhận yêu cầu từ app, điều phối việc phân tích |
| arXiv | Nguồn bài báo khoa học | Tìm bài đầu vào bằng ID/link, lấy thông tin phục vụ phân tích |
| RefChecker | Công cụ kiểm tra tài liệu tham khảo | Đọc reference và kiểm tra thông tin; hỗ trợ phát hiện nghi bịa khi có cấu hình AI |
| Saffron | Công cụ xử lý văn bản và chủ đề | Rút chủ đề từ văn bản của các reference rồi tổ chức thành cây |
| Firebase | Nhóm dịch vụ có sẵn của Google | Đăng nhập, lưu dữ liệu, gửi thông báo và theo dõi app |
| Tailscale | Mạng riêng kết nối các thiết bị | Cho app gọi được backend chạy trên laptop |
| PDF / Cloudinary | Tạo báo cáo / lưu file trên cloud | PDF được tạo và lưu trên thiết bị; có thể upload lên Cloudinary khi bật tính năng |

MVVM, Provider hay go_router giúp tổ chức và vận hành app; RefChecker và Saffron mới là các công cụ trực tiếp phục vụ phân tích.

2. Firebase gồm những gì ở đây?

Firebase không phải chỉ có database:

| Dịch vụ | Dự án dùng để làm gì? |
|---|---|
| Authentication | Đăng nhập Google, xác định người dùng |
| Cloud Firestore | Lưu kết quả phân tích, tiến độ, lịch sử riêng và thông báo |
| Cloud Messaging — FCM | Gửi push khi phân tích xong |
| Remote Config | Đổi một số cấu hình mà không cần build app lại, chẳng hạn ngưỡng Weak |
| Analytics | Ghi nhận thao tác sử dụng: tìm bài, xem chủ đề, xuất báo cáo… |
| Crashlytics | Ghi nhận lỗi và crash để người phát triển tìm nguyên nhân |

Repo cũng có phần hỗ trợ Firebase Storage, nhưng cấu hình hiện tại dùng Cloudinary cho việc upload báo cáo.

3. “Dựng cây chủ đề” là gì?

Nó là sắp xếp các chủ đề theo quan hệ cha–con, để người dùng dễ khám phá nhóm lớn và nhóm nhỏ.

Ví dụ minh họa:

Các chủ đề được tìm thấy
├── Machine Learning
│   ├── Neural Networks
│   └── Optimization
└── Natural Language Processing
    ├── Machine Translation
    └── Text Classification

- Nút cây: một chủ đề.
- Nhánh cha–con: quan hệ chủ đề rộng và chủ đề cụ thể hơn.
- Reference gắn với chủ đề: những tài liệu được hệ thống xếp vào nhóm đó.

Saffron tạo phần cấu trúc chủ đề. Sau đó hệ thống kết hợp với kết quả RefChecker để bạn xem: nhóm này có bao nhiêu reference, bao nhiêu reference có vấn đề, có đạt điều kiện gắn nhãn Weak không.

Cây này là cây chủ đề, không phải cây thư mục hay sơ đồ bài nào trích dẫn bài nào.

4. Ghép lại thành workflow

Bạn nhập ID/link arXiv
          ↓
App tìm kết quả trên Firestore
          ↓
Đã xong → mở kết quả
Chưa có → yêu cầu backend phân tích
          ↓
RefChecker: đọc và kiểm tra reference
          ↓
Backend tìm văn bản của từng reference
          ↓
Saffron: tìm chủ đề và dựng cây
          ↓
Backend ghép kết quả, lưu Firestore, gửi thông báo
          ↓
App hiển thị tổng quan → chủ đề → reference chi tiết
          ↓
Bạn có thể xuất PDF

Vì vậy khi đọc dự án, bạn có thể bám vào ba phần: Flutter để tương tác, backend để điều phối phân tích, Firebase để lưu dữ liệu và hỗ trợ app.