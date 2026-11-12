# Chạy web admin và thử gửi thông báo

Làm theo tài liệu này để mở web admin, gửi một thông báo thật và kiểm tra ở app Android. Lệnh có sẵn cho **Ubuntu/Linux** và **Windows PowerShell**.

## 1. Cần chạy những gì?

| Phần | Chạy ở đâu? | Dùng để làm gì? |
|---|---|---|
| Web admin | Terminal 1: `npm run dev` | Mở giao diện quản trị bằng trình duyệt |
| Backend (BE) | Terminal 2: lệnh Python ở mục 4 | Xử lý yêu cầu gửi, lưu hộp thư và gửi push |
| App Android | Điện thoại người nhận | Đọc thông báo và nhận push |

**Giữ cả hai terminal chạy trong lúc thử. Chỉ cần một máy của nhóm chạy BE.** Nếu nhóm đã có BE chạy source mới, bạn chỉ cần chạy web trên máy mình, có thể bỏ qua mục 4.

Thư mục gốc repo là thư mục có `README.md`, `admin-web/` và `backend/`. Các lệnh `cd admin-web` hoặc `cd backend` bên dưới bắt đầu từ thư mục gốc này; thay đường dẫn clone theo máy bạn.

## 2. Chuẩn bị một lần

- Clone repo và lấy bản code mới của nhánh được nhóm bàn giao, hiện là `feat/admin-dashboard`.
- Máy chạy web cần **Node.js 20.19 trở lên** và npm.
- Máy chạy BE cần **Python 3.12**, khóa service account của Firebase và kết nối mạng.
- Cả web và BE dùng cùng Firebase project **`realtron-874ac`**.

Nhờ người quản trị Firebase kiểm tra các mục sau; nếu nhóm đã cấu hình thì không phải làm lại:

1. **Firestore Database → Rules và Indexes:** đã publish bản mới của [firebase/firestore.rules](firebase/firestore.rules) và [firebase/firestore.indexes.json](firebase/firestore.indexes.json), ví dụ `cd firebase && npx firebase-tools deploy --only firestore:rules,firestore:indexes --project realtron-874ac`.
2. **Authentication:** đã bật Google Sign-In; Authorized domains có `localhost` và `127.0.0.1` nếu dùng địa chỉ đó.
3. Tài khoản mở web có `users/{uid}.role = "admin"`.
4. Có ít nhất một tài khoản người nhận trong `users` với `role = "user"`. Admin không xuất hiện trong danh sách nhận.

Chưa có hồ sơ admin? Đăng nhập Google trên web một lần để tạo hồ sơ mặc định, rồi nhờ người quản trị sửa role thành `admin` trong Firestore Console.

## 3. Terminal 1 — chạy web admin

Từ thư mục gốc repo:

```bash
cd admin-web
npm ci
```

Tạo file **`admin-web/.env.local`** bằng cách copy `.env.example` trong cùng thư mục. Điền cấu hình của **Firebase Web app**:

```dotenv
VITE_FIREBASE_API_KEY=gia_tri_apiKey
VITE_FIREBASE_AUTH_DOMAIN=realtron-874ac.firebaseapp.com
VITE_FIREBASE_PROJECT_ID=realtron-874ac
VITE_FIREBASE_APP_ID=gia_tri_appId_co_doan_web
VITE_FIREBASE_MESSAGING_SENDER_ID=1089055864452
VITE_FIREBASE_STORAGE_BUCKET=realtron-874ac.firebasestorage.app
```

Hai giá trị `gia_tri_...` phải thay bằng giá trị thật, giữ nguyên từng ký tự. Lấy tại **Firebase Console → Project settings → General → Your apps → Web app → SDK setup and configuration → Config**, hoặc xin file `.env.local` của web từ người bàn giao. `appId` phải có đoạn `:web:`.

Sau đó chạy, vẫn ở thư mục `admin-web/`:

```bash
npm run dev
```

Mở **http://localhost:5173** → **Continue with Google** → đăng nhập tài khoản admin. Nếu Vite báo port khác vì 5173 đang được dùng, mở đúng URL Vite in ra.

**Thành công:** thấy Overview và menu Notifications. Cứ giữ terminal này chạy.

Chỉ muốn xem giao diện mẫu? Mở **http://localhost:5173/demo/notifications**. Demo không cần BE hoặc cấu hình Firebase, không gửi thông báo thật. Muốn gửi thật thì dùng **`/notifications`**.

## 4. Terminal 2 — chạy backend

### 4.1. Cài dependency lần đầu

Mở terminal mới, vào thư mục gốc repo rồi chọn đúng nhóm lệnh cho hệ điều hành.

**Ubuntu/Linux:**

```bash
cd backend
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
```

`python3` cần là Python 3.12. Nếu tạo venv báo thiếu `ensurepip` hoặc `venv`, cài gói `python3.12-venv` tương ứng trên máy rồi chạy lại.

**Windows PowerShell:**

```powershell
cd backend
py -3.12 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

### 4.2. Cấu hình khóa Firebase

Xin khóa service account từ người quản trị nhóm qua kênh riêng. Nếu bạn quản trị Firebase, lấy tại **Project settings → Service accounts → Generate new private key**. Khóa phải thuộc project `realtron-874ac` và được lưu ngoài repo.

Nếu chưa có file **`backend/.env`**, tạo file với dòng sau, thay bằng đường dẫn thật tới khóa trên máy:

**Ubuntu/Linux — ví dụ:**

```dotenv
GOOGLE_APPLICATION_CREDENTIALS=/home/ten-cua-ban/keys/realtron-service-account.json
```

**Windows — ví dụ, dùng dấu `/`:**

```dotenv
GOOGLE_APPLICATION_CREDENTIALS=C:/keys/realtron-service-account.json
```

Nếu máy đã có `.env` để chạy phân tích paper thì giữ các cấu hình hiện có và kiểm tra lại đường dẫn khóa. Không cần sao chép đường dẫn Saffron/GROBID từ máy của thành viên khác chỉ để thử thông báo.

### 4.3. Bật BE

Vẫn trong thư mục `backend/`:

**Ubuntu/Linux:**

```bash
.venv/bin/python -m uvicorn --factory orchestrator.main:build_app --env-file .env --host 0.0.0.0 --port 8000
```

**Windows PowerShell:**

```powershell
.\.venv\Scripts\python.exe -m uvicorn --factory orchestrator.main:build_app --env-file .env --host 0.0.0.0 --port 8000
```

**Thành công:** terminal hiện `Uvicorn running ... port 8000`. Mở **http://localhost:8000/api/health** trên máy chạy BE và thấy JSON có **`"status": "ok"`**.

Worker thông báo tự chạy cùng BE; không phải bật thêm lệnh worker. Giữ terminal này mở. Cảnh báo `No CLOUDINARY_* settings: report uploads are off` chỉ nói chức năng upload PDF chưa cấu hình, không chặn gửi thông báo.

Các bước này đủ để bật API và thử thông báo. **Phân tích paper mới còn cần cấu hình Saffron và GROBID hoặc LLM** theo [backend/README.md](backend/README.md). Nếu nhóm đã có máy phân tích chạy ổn, dùng máy đó với source mới thay vì cài lại pipeline trên mọi máy.

## 5. Gửi thử một thông báo

1. Trên web, mở **Notifications** tại **http://localhost:5173/notifications**.
2. Chờ danh sách user xuất hiện. Worker đồng bộ ngay khi khởi động và khoảng mỗi 60 giây sau đó.
3. Chọn **Selected users**, chọn đúng một người thử trước.
4. Nhập Title và Message → **Review message** → kiểm tra người nhận/nội dung → **Confirm send**.
5. Xem **Recent announcements** phía dưới. Khi worker rảnh, yêu cầu thường được lấy trong khoảng 10 giây. `Queued` là đang chờ, `Processing` là đang xử lý, `Completed` là xử lý xong.
6. Nhờ người nhận mở **Notifications** trong app và kiểm tra thanh thông báo điện thoại.

Khi cần gửi cả nhóm, chọn **All users**. Chế độ này lấy mọi user thường tại thời điểm worker xử lý, không gửi admin.

| Kết quả | Cách hiểu |
|---|---|
| `Inbox stored = 1` | Đã lưu thông báo vào hộp thư của một user |
| `FCM accepted = 1` | FCM đã chấp nhận gửi tới một token thiết bị; chưa xác nhận điện thoại hiển thị hoặc user đã đọc |
| `Without device = 1` | User vẫn có thông báo trong inbox nhưng không có token để gửi push |

Người nhận cần APK từ **source mới**, đăng nhập bằng tài khoản được chọn, có token FCM và cấp quyền thông báo để thử đầy đủ hành vi push. Bấm một mục thông báo admin trong app sẽ mở nội dung đầy đủ và đánh dấu đã đọc.

Nếu cài app lần đầu: kết nối điện thoại và máy BE qua Tailscale, nhập **`http://IP_TAILSCALE_CUA_MAY_BE:8000`** ở màn Connect → Test → Continue. Thay phần IP bằng địa chỉ thật do người chạy BE cung cấp; không nhập `localhost` hoặc `0.0.0.0` trên điện thoại. Xem [hướng dẫn app Android](HUONG_DAN_CHAY.md) nếu cần cài APK.

## 6. Những lần mở sau

Đã cài dependency và điền cấu hình rồi thì chỉ cần mở hai terminal và chạy lại hai lệnh bật web/BE ở mục 3 và 4.3. Không phải tạo lại venv hoặc file cấu hình mỗi lần. Sau khi kéo code mới, chạy `npm ci` hoặc cài lại requirements nếu dependency đã đổi.

Bấm **Ctrl+C** ở từng terminal để dừng. BE tắt thì yêu cầu mới nằm chờ `Queued`. App đã thiết lập Connect vẫn đọc được kết quả và hộp thư đã lưu từ Firebase; phân tích mới cần BE.

Nếu một thành viên khác đang chạy BE source mới của cùng project, người đó có thể xử lý yêu cầu gửi từ web của bạn. Web gửi yêu cầu qua Firestore nên không cần nhập địa chỉ BE vào web.

## 7. Lỗi thường gặp

| Hiện tượng | Cách xử lý |
|---|---|
| Web hiện Setup needed | Kiểm tra `admin-web/.env.local`, điền đủ cấu hình Web app rồi chạy lại Vite |
| `API_KEY_INVALID` | Copy lại `apiKey` dạng text từ Firebase Console; không chép từ ảnh; chạy lại Vite |
| Google Sign-In báo `unauthorized-domain` | Thêm hostname đang mở vào Authentication → Settings → Authorized domains |
| `Admin access required` | Kiểm tra role `admin` trên hồ sơ của đúng tài khoản đăng nhập |
| `Access was denied` ở Notifications | Publish Rules mới vào đúng project `realtron-874ac`, kiểm tra role rồi Retry hoặc reload |
| `No users synced yet` | Kiểm tra log BE/worker, khóa đúng project và có tài khoản role `user`; admin không nằm trong danh sách |
| `Set GOOGLE_APPLICATION_CREDENTIALS...` | Kiểm tra `backend/.env` và đường dẫn tới file khóa có tồn tại trên máy này |
| `No module named uvicorn` hoặc `orchestrator` | Chạy bằng Python của `.venv`, cài requirements và đứng trong thư mục `backend/` |
| Request nằm `Queued` lâu | Kiểm tra BE vẫn chạy và log worker không báo lỗi; kiểm tra web/BE cùng project |
| `Needs review`, `Failed` hoặc `Interrupted` | Đọc lỗi và bộ đếm trong lịch sử; kiểm tra log BE trước khi chủ động gửi lại |
| Có inbox nhưng không hiện push | Kiểm tra đúng tài khoản người nhận, token thiết bị, mạng và quyền thông báo; `FCM accepted` chưa chứng minh điện thoại đã hiển thị |
| App không qua được Connect | Cần BE đầy đủ đang chạy, địa chỉ Tailscale đúng, thiết bị truy cập được port 8000 và firewall cho phép |

## File cấu hình khi bàn giao

`admin-web/.env.local`, `backend/.env` và khóa service account **không đi theo Git**. Người nhận code phải tự tạo cấu hình trên máy mình hoặc nhận qua kênh riêng từ người bàn giao. Đường dẫn khóa trong `.env` phải được sửa theo máy nhận; không đặt khóa service account trong web.
