# Realtron Admin Web

React + TypeScript + Vite. Dùng cùng Firebase/Firestore với app Android và backend hiện tại.

```bash
npm ci
npm run dev
```

Mở **http://localhost:5173/demo** để thử ngay bằng dữ liệu minh họa. Chế độ demo không cần Firebase, backend hoặc tài khoản Google.

Để dùng dữ liệu thật, copy `.env.example` thành `.env.local`, điền cấu hình Firebase **Web app**, restart Vite và mở `/`. Tài khoản cần `users/{uid}.role = "admin"`; Firestore Rules phải được publish trước.

Hướng dẫn cấp role, cấu hình Firebase và demo: [docs/ADMIN_DASHBOARD.md](../docs/ADMIN_DASHBOARD.md).

**Notifications:** mở `/demo/notifications` để thử gửi tất cả hoặc chọn user bằng dữ liệu mẫu. Để gửi thật tại `/notifications`, publish Rules mới và chạy backend worker. Xem [gửi thông báo và Firebase Hosting](../docs/ADMIN_NOTIFICATIONS.md) để cấu hình; `firebase.json` trong thư mục này đã có SPA fallback và target hosting `admin-web`, chưa deploy.

```bash
npm test
npm run build
npx playwright install chromium
npm run test:e2e
```

Font được đóng gói cùng web. Không cần cài Flutter hoặc Android SDK để phát triển phần admin.
