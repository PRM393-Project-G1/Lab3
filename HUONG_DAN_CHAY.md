# Hướng dẫn chạy Realtron

**Muốn chạy web admin và gửi thông báo?** Đọc [CHAY_ADMIN.md](CHAY_ADMIN.md) trước: chuẩn bị cấu hình, chạy web + backend trên hai terminal và gửi thử. Tài liệu bên dưới tập trung vào app Android và máy phân tích paper.

Realtron gồm hai phần:

- **App Android:** đăng nhập Google, đọc kết quả từ Firestore.
- **Backend trên laptop:** chạy RefChecker và Saffron, nhận lệnh từ app qua Tailscale.

Bài đã phân tích thì mở được khi backend tắt, nhưng app vẫn cần backend ở lần đầu qua màn Connect và khi phân tích bài mới.

## Chỉ muốn dùng app (cách nhanh nhất)

Không cần build gì. Xin người giữ backend file `app-release.apk` và địa chỉ server.

1. Cài APK lên điện thoại Android. APK không nằm trong repo.
2. Cài Tailscale, rồi vào cùng tailnet với máy chạy backend, hoặc nhờ chủ máy chia sẻ máy đó cho bạn.
3. Mở app, chọn `Continue with Google`.
4. Ở màn Connect, nhập `http://100.114.197.87:8000`, bấm `Test`, rồi `Continue`.
5. Nhập `1706.03762` rồi bấm `Analyze`. Paper Overview sẽ mở ngay vì bài này đã có kết quả.

Máy chạy backend phải đang bật, và backend phải đang chạy. Bài chưa có kết quả mất khoảng 2–10 phút, xong sẽ có push.

## Chạy backend trên máy đã cài sẵn

Áp dụng cho máy đang giữ thư mục `lab3/`, với `.venv`, `.env`, `tools/` và `keys/` đã có. Chạy theo thứ tự:

1. Mở Docker Desktop và Tailscale.
2. Bật GROBID:

   ```bash
   docker start realtron-grobid
   ```

3. Vào thư mục backend:

   ```bash
   cd D:/EXERCISE/learnfpt/fall2026/PRM/lab3/app/backend
   ```

4. Chạy service, và giữ cửa sổ này mở:

   ```bash
   .venv/Scripts/uvicorn --factory orchestrator.main:build_app --env-file .env --host 100.114.197.87 --port 8000
   ```

Thấy `Uvicorn running on http://100.114.197.87:8000` là được. Bấm `Ctrl+C` để dừng. Nếu `tailscale ip -4` ra địa chỉ khác, hãy thay trong lệnh trên và trong màn Connect.

### Lệnh hay dùng

Chạy trong `app/backend/`. Hai lệnh đầu không cần service đang chạy.

Phân tích trước bài demo, kết quả thật được ghi lên Firestore:

```bash
.venv/Scripts/python -m orchestrator.seed 1706.03762 1409.0473
```

Gửi lại push `Analysis done` cho bài đã xong:

```bash
.venv/Scripts/python -m orchestrator.push 1706.03762
```

Chạy test của backend:

```bash
.venv/Scripts/python -m pytest
```

## Build APK

Cần Flutter 3.47.4 và một JDK đầy đủ. Chạy trong `app/`, bằng PowerShell:

```bash
$env:JAVA_HOME = "C:\Users\fanan\.jdks\temurin-25.0.4.1"
```

```bash
flutter pub get
```

```bash
flutter test
```

```bash
flutter build apk --release
```

File ra ở `build/app/outputs/flutter-apk/app-release.apk`.

**Build trên máy khác:** APK được ký bằng khoá debug của máy đó. Phải thêm SHA-1 của máy đó vào Firebase (Project settings → app Android), nếu không Google Sign-In sẽ báo lỗi. Lấy SHA-1 bằng lệnh:

```bash
& "$env:JAVA_HOME\bin\keytool" -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android
```

## Cài backend trên máy khác

Mất nhiều công, và thường không cần: chỉ một máy chạy backend là đủ. Làm theo [`backend/README.md`](backend/README.md), gồm build Saffron (khoảng 3,3 GB) và GROBID qua Docker.

Khoá service account **không có trong repo**. Xin trực tiếp người giữ project, không gửi qua chat hay commit.

## Cấu hình Firebase hiện tại

| Mục | Giá trị |
|---|---|
| Project | `realtron-874ac`, gói Spark |
| Remote Config | `enable_cloud_upload`: `false` thì chỉ lưu PDF trên máy; `true` thì upload thêm lên Cloudinary qua backend |
| Xuất báo cáo | PDF lưu trên máy, có `Open` và `Share`. Khi bật upload: có thanh tiến độ, link và `Copy link`. Spark không có Cloud Storage nên tạm dùng Cloudinary |

Hướng dẫn tạo lại từ đầu: [`firebase/README.md`](firebase/README.md).

## Chạy test E2E

Test ARTEMIS cần thêm máy chủ ARTEMIS, API key của model và tài khoản Google riêng. Xem [`e2e_test/README.md`](e2e_test/README.md). **Suite này chưa chạy với thiết bị thật.**

## Khi gặp lỗi

| Hiện tượng | Nguyên nhân thường gặp | Cách xử lý |
|---|---|---|
| Màn Connect báo `Can't reach server` hoặc `Timed out` | Tailscale chưa bật ở một trong hai máy, backend chưa chạy, hoặc firewall chặn | Kiểm tra lần lượt; cho phép Python qua Windows Firewall |
| Google Sign-In báo `Sign-in failed` | SHA-1 của máy build chưa có trên Firebase | Thêm SHA-1, tải lại `google-services.json`, build lại |
| App hiện `Setup needed` | APK build khi chưa có `android/app/google-services.json` | Thêm file đó rồi build lại |
| `Report` báo `Export failed` khi upload | Backend tắt, hoặc `.env` thiếu `CLOUDINARY_*` (backend log `report uploads are off`) | Bật backend, điền `CLOUDINARY_*`; hoặc đổi `enable_cloud_upload` thành `false` trên Console |
| Phân tích báo `Couldn't read this paper's references.` | GROBID chưa chạy và không có key LLM | `docker start realtron-grobid`; xem `work/{arxivId}/refchecker.log` |
| Phân tích báo `Couldn't extract topics.` | Saffron lỗi | Xem `work/{arxivId}/saffron.log` |
| Phân tích báo `Topic extraction isn't set up on the server.` | `.env` thiếu `SAFFRON_COMMAND` | Điền theo `.env.example` |
| Lệnh `.venv/Scripts/...` báo `not recognized` | Đang đứng sai thư mục | `cd` vào `app/backend` trước |
| Service báo `Set GOOGLE_APPLICATION_CREDENTIALS` | `.env` thiếu đường dẫn khoá | Điền đường dẫn khoá service account |
| Không có push khi app đã tắt | Máy Xiaomi/Redmi chặn, hoặc đã `Force stop` app | Bật Autostart cho Realtron; không dùng `Force stop` |

## Giới hạn hiện tại

- Chỉ nhận bài trên arXiv, chưa nhận file PDF.
- Chưa có key LLM thì không kiểm tra được reference bịa: số `Hallucinated` sẽ luôn là 0.
- Chất lượng cây chủ đề chưa được đánh giá: Saffron dùng model thay thế, vì máy chủ model gốc đã ngừng hoạt động. Xem [`backend/README.md`](backend/README.md).
