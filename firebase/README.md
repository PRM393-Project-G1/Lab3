# Cấu hình Firebase (dành cho bạn phụ trách Firebase)

Code app đã sẵn sàng. Nhóm dùng gói **Spark**, nên **không bật Cloud Storage**: gói này không có bucket. App lưu PDF trên máy (`enable_cloud_upload = false`).

## Việc cần làm

1. Tạo project, bật Google Analytics.
2. Thêm app Android:
   - Package: `vn.fpt.prm393.realtron`
   - SHA-1: `E2:51:5F:02:8D:DF:B8:97:C3:AB:0D:17:47:51:B6:9C:4F:38:DC:DD`

   Đây là khoá debug trên máy đang build APK. Thiếu SHA-1 hoặc build trên máy khác thì Google Sign-In báo lỗi `ApiException: 10`.
3. Bật Authentication (Google), Firestore, Cloud Messaging, Crashlytics, Remote Config.
4. Đưa luật Firestore lên, chạy từ thư mục `firebase/`:

   ```bash
   firebase deploy --only firestore:rules,firestore:indexes --project <project-id>
   ```

5. Tạo 5 tham số Remote Config theo [`remote-config-defaults.json`](remote-config-defaults.json).
6. Tạo service account cho backend. Khoá này **không được commit** và chỉ đưa cho bạn làm backend.
7. Gửi `google-services.json` để đặt vào `android/app/`. File này được commit, vì đề yêu cầu có trong repo.

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

Đề có mục này, nhưng Spark không dùng được. `storage.rules` vẫn nằm trong repo. Nếu sau này có bucket, chỉ cần deploy luật và đổi `enable_cloud_upload` thành `true`, không phải build lại.
