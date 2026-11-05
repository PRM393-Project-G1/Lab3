# Cấu hình Firebase

Code app đã sẵn sàng. Nhóm dùng gói **Spark**, nên **không bật Cloud Storage**: gói này không có bucket. App lưu PDF trên máy (`enable_cloud_upload = false`).

Làm đúng thứ tự: `google-services.json` chỉ có Web client ID khi đã bật Google Sign-In, thiếu nó thì app không đăng nhập được.

## Việc cần làm

1. Tạo project tại [Firebase Console](https://console.firebase.google.com), bật Google Analytics.
2. Thêm app Android:
   - Package: `vn.fpt.prm393.realtron`
   - SHA-1: `E2:51:5F:02:8D:DF:B8:97:C3:AB:0D:17:47:51:B6:9C:4F:38:DC:DD`

   Đây là khoá debug trên máy đang build APK. Thiếu SHA-1 hoặc build trên máy khác thì Google Sign-In báo lỗi `ApiException: 10`.
3. Authentication → Sign-in method → bật **Google**, chọn email hỗ trợ.
4. Firestore Database → tạo database ở chế độ production. Vào tab Rules, thay toàn bộ bằng nội dung [`firestore.rules`](firestore.rules), rồi Publish.
5. Remote Config → tạo 5 tham số theo [`remote-config-defaults.json`](remote-config-defaults.json), rồi Publish.
6. Crashlytics → bật. Cloud Messaging không cần bật thêm.
7. Project settings → tải `google-services.json` về, đặt vào `android/app/`. File này được commit, vì đề yêu cầu có trong repo.
8. Project settings → Service accounts → tạo khoá cho backend. Khoá này **không được commit**, nên hãy để nó ngoài repo.

Không cần cài Firebase CLI: `firestore.indexes.json` đang rỗng, nên không có index nào phải đưa lên.

## Backend phải ghi gì

Các trường Firestore và FCM ở [`docs/architecture.md`](../docs/architecture.md), mục 7 và 8.

## Ảnh bằng chứng trên Console

Project ID trong ảnh phải trùng với `google-services.json`.

| Dịch vụ | Ảnh | Thư mục |
|---|---|---|
| Authentication | Tab Users | `evidence/auth/` |
| Analytics | DebugView có đủ sự kiện | `evidence/analytics/` |
| Crashlytics | Non-fatal và test crash, có user ID và custom key | `evidence/crashlytics/` |
| Remote Config | Đổi giá trị, app đổi theo không cần build lại | `evidence/remote-config/` |
| Cloud Messaging | Nhận push ở 3 trạng thái của app | `evidence/fcm/` |

## Cloud Storage

Đề có mục này, nhưng Spark không dùng được. `storage.rules` vẫn nằm trong repo. Nếu sau này có bucket, chỉ cần đưa luật lên và đổi `enable_cloud_upload` thành `true`, không phải build lại.
