# Realtron Admin — Web Dashboard

Admin là website riêng trong [`admin-web/`](../admin-web/), mở bằng trình duyệt laptop. App Flutter Android tiếp tục phục vụ user. Web dùng cùng Firebase Authentication, Firestore và quy tắc phân quyền của dự án. Theo dõi bài báo không cần backend đang chạy; chức năng gửi thông báo cần worker xử lý hàng đợi Firestore.

[Ảnh preview web](images/admin-dashboard-web-preview.png) được chụp bằng Chromium với dữ liệu minh họa, không phải kết quả Firebase thật.

## 1. Chạy thử ngay, chưa cần cấu hình Firebase

Tại thư mục gốc repo:

```bash
cd admin-web
npm ci
npm run dev
```

Mở **http://localhost:5173**, chọn **Explore demo workspace**, hoặc vào thẳng **http://localhost:5173/demo**.

Máy cần Node.js 20.19+; Node đang có trên máy lúc triển khai là 20.20.2. Không cần Flutter, Android SDK, điện thoại, Tailscale hay backend để thử chế độ demo này.

Demo có 12 bản ghi minh họa và nhãn **Sample data** trên mọi màn. Dữ liệu mẫu nằm riêng trong memory, không đọc/ghi Firebase, không đăng nhập giả vào project thật. Exit demo hoặc Connect real data đưa về màn kết nối/đăng nhập thật.

## 2. Tính năng

| Phần | Hành vi |
|---|---|
| Bốn thẻ thống kê | Tổng số analyses, Completed, Running, Failed. Running gồm Queued và Processing |
| Bảng phân tích | Tên bài, arXiv ID, tác giả đầu tiên, trạng thái, số reference khi hoàn thành, ngày yêu cầu |
| Tìm kiếm/lọc | Theo tên hoặc ID, kết hợp trạng thái; tổng thống kê vẫn tính toàn hệ thống |
| Phân trang | 8 bản ghi mỗi trang; tìm kiếm hoặc đổi bộ lọc đưa về trang 1 |
| Chi tiết | Thông tin bài, trạng thái hoặc lý do lỗi; kết quả hoàn thành có phân bố trạng thái reference, cây chủ đề và danh sách references |
| Reference detail | Mở từng reference để xem lỗi, bảng Cited/Actual và link nguồn nếu có |
| Trạng thái giao diện | Loading, rỗng, không khớp tìm kiếm, lỗi + Retry, dữ liệu cache, ID không hợp lệ và trang không tồn tại |
| Bố cục | Sidebar và bảng cho laptop, menu thu gọn và danh sách card trên màn nhỏ |
| Notifications | Gửi tất cả user hoặc chọn tối đa 100 người; xem lại trước khi gửi và theo dõi lịch sử xử lý |

Phần bài báo chỉ theo dõi và đọc kết quả. Web không chạy phân tích, dừng job, retry job, sửa role hay xóa bài. Công việc phân tích vẫn do app user và backend hiện tại xử lý. Phần [Notifications và hosting](ADMIN_NOTIFICATIONS.md) có hướng dẫn riêng, gồm worker nhẹ để thử gửi mà không cần chạy toàn bộ pipeline phân tích.

## 3. Kết nối Firebase thật sau

Chưa có Web app config thì chế độ demo vẫn chạy đầy đủ. Để nối dữ liệu thật:

1. Firebase Console → chọn project **`realtron-874ac`** → Project settings → Your apps → Add app → **Web** (`</>`).
2. Đăng ký Web app, ví dụ tên `realtron-admin-web`. Không cần bật Firebase Hosting để chạy localhost.
3. Copy object `firebaseConfig` của Web app.
4. Trong `admin-web/`, tạo file cấu hình local:

   ```bash
   cp .env.example .env.local
   ```

5. Điền các trường tương ứng:

   ```dotenv
   VITE_FIREBASE_API_KEY=<firebaseConfig.apiKey>
   VITE_FIREBASE_AUTH_DOMAIN=<firebaseConfig.authDomain>
   VITE_FIREBASE_PROJECT_ID=<firebaseConfig.projectId>
   VITE_FIREBASE_APP_ID=<firebaseConfig.appId>
   VITE_FIREBASE_MESSAGING_SENDER_ID=<firebaseConfig.messagingSenderId>
   VITE_FIREBASE_STORAGE_BUCKET=<firebaseConfig.storageBucket>
   ```

   Bốn trường đầu là bắt buộc. `appId` phải là Web app ID có đoạn `:web:`, không dùng Android app ID. Không đặt service account, private key hoặc secret backend vào file Vite.

6. Firebase Authentication → Sign-in method → bật Google. Settings → Authorized domains → thêm **`localhost`**, và **`127.0.0.1`** nếu dùng URL đó.
7. Dừng và chạy lại `npm run dev` để Vite nhận biến mới. Mở `/` và chọn Continue with Google.
8. Cấp quyền admin và publish Rules theo mục tiếp theo.

Sau khi build, các giá trị `VITE_*` được đóng gói vào frontend. `.env.local` được gitignore; cấu hình Web là cấu hình client, quyền truy cập vẫn phải được thực thi bằng Rules.

## 4. Cấp quyền admin

- Đăng nhập Google một lần. Nếu hồ sơ chưa tồn tại, web chỉ tạo `users/{uid}` với role mặc định `user`.
- Tài khoản chưa có quyền sẽ thấy **Admin access required** và UID của mình; không query danh sách phân tích.
- Người quản trị Firebase sửa `users/{uid}.role` thành chuỗi **`admin`** viết thường trong Console.
- Web theo dõi role realtime; sau khi cấp quyền, tài khoản được vào dashboard. Đổi role về `user` sẽ đóng dashboard và hủy theo dõi danh sách.
- Đăng xuất hoặc đổi tài khoản sẽ bỏ dữ liệu đang hiển thị. Callback role đến muộn từ tài khoản cũ không được dùng để cấp quyền cho tài khoản mới.

## 5. Firestore Rules

Publish nội dung [`firebase/firestore.rules`](../firebase/firestore.rules) lên đúng project trước khi demo dữ liệu thật. Việc sửa file trong repo không tự deploy Rules.

| Thao tác | Quyền |
|---|---|
| Query collection `analyses` | Chỉ role `admin` |
| Đọc một analysis theo ID, references và topics | Người dùng đã đăng nhập, giữ luồng Android hiện có |
| Ghi/xóa analysis hoặc kết quả | Mọi client đều bị từ chối; backend Admin SDK ghi như trước |
| Đọc hồ sơ/lịch sử của người khác | Bị từ chối, kể cả admin |
| Tự cấp hoặc đổi role | Bị từ chối |
| Đọc danh sách user đã đồng bộ và lịch sử thông báo admin | Chỉ admin; danh sách không chứa token hoặc toàn bộ hồ sơ riêng |
| Tạo yêu cầu gửi thông báo | Chỉ admin, chỉ tạo trạng thái `queued` cho chính mình; backend ghi kết quả |

Web không giữ service account và không gọi Firebase Admin SDK. Role được đọc từ Firestore, không dựa vào email viết cứng hoặc một nút bật admin trong trình duyệt.

## 6. Cấu trúc code

```text
admin-web/
├── src/App.tsx                 Đăng nhập, kiểm tra quyền, layout và routing
├── src/hooks/useAccess.ts      Theo dõi tài khoản/role, bỏ callback cũ
├── src/domain/analysis.ts      Contract dữ liệu, thống kê, lọc và quy tắc Weak
├── src/domain/notifications.ts Contract thông báo, người nhận và thống kê gửi
├── src/services/
│   ├── gateway.ts              Interface dùng chung cho dữ liệu thật và demo
│   ├── firebaseConfig.ts       Kiểm tra cấu hình Web
│   ├── firebaseGateway.ts      Firebase Auth, Firestore, Remote Config
│   └── demoGateway.ts          Fixture riêng, không kết nối Firebase
├── src/pages/                  Dashboard, chi tiết analysis và Notifications
├── src/components/             Trạng thái, badge và định dạng ngày
├── tests/                      Unit/component test
└── e2e/                        Test trình duyệt Playwright
```

Số reference của topic cha tính từ hợp các `refIds` ở cả nhánh, loại trùng. Weak dùng cùng công thức với app Android: `(Error + Hallucinated) / tổng >= threshold` và đủ `minRefs`; Warning không nằm trong tử số. Web lấy ngưỡng từ Remote Config, fallback về 50% và 3 reference nếu cấu hình chưa tải được.

## 7. Kiểm tra và build

Chạy trong `admin-web/`:

```bash
npm test
npm run build
```

Build tạo `admin-web/dist/`. Xem bản build bằng `npm run preview`, mặc định port 4173.

Kiểm tra bằng trình duyệt:

```bash
npx playwright install chromium
npm run test:e2e
```

Playwright mở server tạm trên port 5174 bằng mode `e2e`, vô hiệu hóa cấu hình Firebase thật trong bundle test dù `.env.local` đã được điền. Các test kiểm tra fixture demo trên viewport laptop/mobile: lọc, tìm kiếm, phân trang, xem topic/reference, lỗi analysis, reload URL chi tiết, trang không tồn tại và gửi thông báo ở cả hai chế độ. Không xác nhận Google OAuth hoặc dữ liệu Firebase thật.

Kết quả kiểm tra ngày 11/11/2026: build production và TypeScript pass; 21 unit/component tests pass; 6 browser tests trên Chromium desktop/mobile pass. Lỗi `API_KEY_INVALID` ở lần kết nối đầu tiên được đối chiếu với config dạng text: API key đã bị chép nhầm một ký tự từ ảnh và đã sửa trong `.env.local`. Người dùng đã xác nhận kết nối hoạt động sau khi sửa; các test tự động vẫn dùng adapter giả hoặc demo.

### Khi đăng nhập gặp lỗi cấu hình

- `API_KEY_INVALID` / `auth/invalid-api-key`: copy nguyên giá trị `apiKey` từ Project settings → Your apps → Web app → SDK setup and configuration → Config vào `.env.local`. Ưu tiên copy text để tránh nhầm ký tự trong ảnh. Khởi động lại Vite và reload trang.
- `auth/unauthorized-domain`: thêm domain đang mở vào Authentication → Settings → Authorized domains.
- `auth/popup-blocked`: cho phép popup trên trang hiện tại rồi bấm Continue with Google một lần nữa.

Firestore Rules chỉ được xét khi truy cập database; sửa Rules không khắc phục được API key không hợp lệ ở bước đăng nhập.

Test Rules giữ tại `firebase/tests/`, chạy bằng `npm run test:rules` sau khi cài dependencies trong thư mục `firebase/`. Suite này dùng emulator và project demo riêng.

## 8. Giới hạn

Để giữ dashboard nhỏ cho bài demo, web theo dõi toàn bộ collection `analyses`, tính thống kê và phân trang hiển thị tại client. Khi dữ liệu lớn cần phân trang truy vấn và thống kê phía server. Trang chi tiết tải snapshot theo lần mở; quay lại overview để xem tiến độ realtime.

Đã chuẩn bị `admin-web/firebase.json` cho Firebase Hosting, có SPA fallback về `index.html` để reload URL chi tiết hoạt động. Xem [hướng dẫn hosting](ADMIN_NOTIFICATIONS.md#6-host-web-lên-firebase-hosting). Chưa deploy website hoặc publish Rules mới lên Firebase thật trong lần triển khai tính năng thông báo này.
