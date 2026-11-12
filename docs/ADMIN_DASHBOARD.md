# Realtron Admin — Web Dashboard

Admin là website riêng trong [`admin-web/`](../admin-web/), mở bằng trình duyệt laptop. App Flutter Android tiếp tục phục vụ user. Web dùng cùng Firebase Authentication, Firestore và quy tắc phân quyền của dự án. Theo dõi bài báo không cần backend đang chạy; chức năng gửi thông báo cần worker xử lý hàng đợi Firestore.

[Ảnh preview web](images/admin-dashboard-web-preview.png) và [ảnh trang Insights](images/admin-insights-web-preview.png) được chụp bằng Chromium với dữ liệu minh họa, không phải kết quả Firebase thật.

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
| Lọc theo người yêu cầu và chế độ | Chọn một user hoặc AI-assisted/Standard; cột ngày hiển thị người yêu cầu |
| Xuất CSV | Xuất đúng các dòng đang lọc (mọi trang), UTF-8, chặn ô bắt đầu bằng `=`, `+`, `-`, `@` |
| Job bị treo | Nhãn **No progress** khi bài Processing không có tiến độ 40 phút hoặc Queued quá 2 giờ; nút lọc **Stalled** |
| Insights | Bộ lọc 7/30/90 ngày hoặc toàn bộ; số bài, tỷ lệ thành công, tỷ lệ reference bịa, thời gian xử lý trung bình; biểu đồ số bài theo ngày, phân bố trạng thái reference, chủ đề yếu hay gặp, lý do lỗi hay gặp, các bài chạy lâu nhất; mỗi biểu đồ có bảng số liệu |
| Thao tác trên bài | Ở trang chi tiết: dừng bài đang chạy, chạy lại bài lỗi/đã dừng/đã ẩn, ẩn kết quả sai kèm lý do, hiện lại, xóa vĩnh viễn |
| Users | Danh sách mọi hồ sơ với role, trạng thái, lần đăng nhập cuối, số bài; trang từng user có các bài của họ, cấp/thu quyền admin, khóa/mở khóa tài khoản |
| Trạng thái backend | Header hiển thị Backend và Notification worker online/offline theo heartbeat; Overview và Notifications báo khi việc đang chờ một tiến trình đã tắt |
| Notifications | Gửi tất cả user hoặc tối đa 100 người, có nhóm chọn nhanh; gắn link tới một bài; gửi ngay hoặc hẹn giờ; hủy yêu cầu chưa xử lý; xem tỷ lệ đã mở |
| Activity log | Dòng thời gian mọi thao tác admin và thông báo: ai làm, với bài/user/tin nào, lý do và kết quả; lọc theo loại và admin; xuất CSV |

Web không gọi backend trực tiếp. Mỗi thao tác là một tài liệu `adminActions/{id}` trạng thái `queued`; tiến trình API của backend (chạy cùng job manager) đọc hàng đợi khoảng 10 giây một lần, kiểm tra lại role của người yêu cầu, thực hiện bằng Admin SDK rồi ghi kết quả. Backend tắt thì yêu cầu nằm ở **Waiting for backend** và header báo Backend offline. Phần [Notifications và hosting](ADMIN_NOTIFICATIONS.md) có hướng dẫn riêng.

| Thao tác | Điều kiện backend kiểm tra |
|---|---|
| Stop analysis | Bài đang Queued/Processing; app của người yêu cầu hiện "Stopped by an administrator." |
| Run again | Bài Failed, Cancelled hoặc Completed đã ẩn; giữ người yêu cầu và chế độ AI ban đầu |
| Hide results / Show results again | Chỉ bài Completed; app hiện "Removed" ở lịch sử và lý do ở trang Overview |
| Delete analysis | Không đang chạy; xóa analysis, references và topics; user có thể yêu cầu lại |
| Make admin / Remove admin access | Không tự đổi role của mình; luôn còn ít nhất một admin; tài khoản bị khóa phải mở khóa trước |
| Disable / Enable account | Không khóa admin; khóa bằng Firebase Auth và thu hồi phiên, user bị đăng xuất trong vòng một giờ, API từ chối token của họ |

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
- Admin đầu tiên phải được cấp trong Console: sửa `users/{uid}.role` thành chuỗi **`admin`** viết thường. Từ admin thứ hai trở đi, dùng trang **Users → Make admin** (cần backend đang chạy).
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
| Hủy yêu cầu thông báo | Chỉ admin, chỉ khi còn `queued`, chỉ đổi sang `cancelled` |
| Tạo thao tác `adminActions` | Chỉ admin, đúng loại và đích (arXiv ID hoặc UID), không nhắm vào chính mình; không sửa/xóa sau khi tạo |
| Đọc `workerStatus` | Chỉ admin; chỉ backend ghi |

Sau khi cập nhật code, publish cả Rules và index (index collection group cho tỷ lệ đã đọc):

```bash
cd firebase
npx firebase-tools deploy --only firestore:rules,firestore:indexes --project realtron-874ac
```

Web không giữ service account và không gọi Firebase Admin SDK. Role được đọc từ Firestore, không dựa vào email viết cứng hoặc một nút bật admin trong trình duyệt.

## 6. Cấu trúc code

```text
admin-web/
├── src/App.tsx                 Đăng nhập, kiểm tra quyền, layout và routing
├── src/hooks/useAccess.ts      Theo dõi tài khoản/role, bỏ callback cũ
├── src/domain/analysis.ts      Contract dữ liệu, thống kê, lọc, job treo và quy tắc Weak
├── src/domain/insights.ts      Số liệu cho trang Insights
├── src/domain/actions.ts       Hàng đợi thao tác admin: loại, kiểm tra, thao tác hợp lệ
├── src/domain/users.ts         Danh sách user và hoạt động theo người
├── src/domain/audit.ts         Gộp thao tác và thông báo thành Activity log
├── src/domain/segments.ts      Nhóm chọn nhanh người nhận
├── src/domain/workers.ts       Heartbeat và trạng thái online/offline
├── src/domain/csv.ts           Xuất CSV an toàn
├── src/domain/notifications.ts Contract thông báo, người nhận và thống kê gửi
├── src/services/
│   ├── gateway.ts              Interface dùng chung cho dữ liệu thật và demo
│   ├── firebaseConfig.ts       Kiểm tra cấu hình Web
│   ├── firebaseGateway.ts      Firebase Auth, Firestore, Remote Config
│   └── demoGateway.ts          Fixture riêng, không kết nối Firebase
├── src/pages/                  Overview, Insights, chi tiết analysis, Users, Notifications, Activity log
├── src/components/             Biểu đồ, khung thao tác admin, trạng thái backend, badge
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

Kết quả kiểm tra ngày 12/11/2026, sau khi thêm các tính năng quản trị: TypeScript pass; 65 unit/component tests pass; 8 browser tests trên Chromium desktop/mobile pass. Ngày 11/11/2026: build production pass; 21 unit/component tests và 6 browser tests pass. Lỗi `API_KEY_INVALID` ở lần kết nối đầu tiên được đối chiếu với config dạng text: API key đã bị chép nhầm một ký tự từ ảnh và đã sửa trong `.env.local`. Người dùng đã xác nhận kết nối hoạt động sau khi sửa; các test tự động vẫn dùng adapter giả hoặc demo.

### Khi đăng nhập gặp lỗi cấu hình

- `API_KEY_INVALID` / `auth/invalid-api-key`: copy nguyên giá trị `apiKey` từ Project settings → Your apps → Web app → SDK setup and configuration → Config vào `.env.local`. Ưu tiên copy text để tránh nhầm ký tự trong ảnh. Khởi động lại Vite và reload trang.
- `auth/unauthorized-domain`: thêm domain đang mở vào Authentication → Settings → Authorized domains.
- `auth/popup-blocked`: cho phép popup trên trang hiện tại rồi bấm Continue with Google một lần nữa.

Firestore Rules chỉ được xét khi truy cập database; sửa Rules không khắc phục được API key không hợp lệ ở bước đăng nhập.

Test Rules giữ tại `firebase/tests/`, chạy bằng `npm run test:rules` sau khi cài dependencies trong thư mục `firebase/`. Suite này dùng emulator và project demo riêng.

## 8. Giới hạn

Để giữ dashboard nhỏ cho bài demo, web theo dõi toàn bộ collection `analyses`, tính thống kê, biểu đồ và phân trang tại client. Khi dữ liệu lớn cần phân trang truy vấn và thống kê phía server. Trang chi tiết tải snapshot theo lần mở và tải lại khi một thao tác admin kết thúc; quay lại overview để xem tiến độ realtime.

- Thao tác admin và thông báo cần backend đang chạy; web chỉ xếp hàng yêu cầu.
- Chủ đề yếu cần `topicSummary` do backend ghi khi phân tích xong. Bài phân tích trước bản cập nhật cần chạy `python -m orchestrator.backfill` một lần trong `backend/`.
- Job treo dựa trên `updatedAt` mà backend ghi từ bản này; bài cũ dùng thời điểm yêu cầu.
- Mỗi analysis chỉ lưu người yêu cầu gần nhất, nên "bài của user" là các bài họ yêu cầu lần cuối.
- Activity log hiển thị 100 thao tác và 30 thông báo gần nhất. Thay đổi làm trực tiếp trong Firebase Console không đi qua hàng đợi nên không có trong log.
- Khóa tài khoản có hiệu lực ngay với API backend; phiên đang mở trong app hết hạn trong vòng một giờ.

Đã chuẩn bị `admin-web/firebase.json` cho Firebase Hosting, có SPA fallback về `index.html` để reload URL chi tiết hoạt động. Xem [hướng dẫn hosting](ADMIN_NOTIFICATIONS.md#6-host-web-lên-firebase-hosting). Chưa deploy website hoặc publish Rules mới lên Firebase thật trong lần triển khai tính năng thông báo này.
