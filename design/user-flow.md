# User flow: Realtron (Lab 3)

> **Realtron** = tên app. Persona tham chiếu: [persona.md](persona.md). **P01 Linh** (Primary), **P02 TS. Hùng** (Secondary), **P03 Khoa** (Supporting).
> Mọi chuỗi trong `"…"` là **chữ thật trên UI**. Stitch, Figma và Flutter phải dùng đúng các chuỗi này.
> Sơ đồ trực quan nằm ở Figma page **01 User Flow** [Realtron](https://www.figma.com/design/gPn3Z9LnTN8Js3QxbrH5Gu/Realtron).

## 0. Nguyên tắc chữ trên UI (góp ý của thầy, 04/11/2026)

1. **Ngắn, dễ hiểu, dễ nhìn.**
   - Nút: 1–2 từ.
   - Tiêu đề: ≤ 3 từ.
   - Banner / empty state: 1 dòng tiêu đề + tối đa 1 dòng phụ (≤ 8 từ).
   - Không có đoạn giới thiệu, không có slogan dài.
2. **Ngoại lệ — phần kết quả sau khi phân tích:** tên reference, tác giả, bảng Cited / Actual, mô tả lỗi, giải thích "Likely fabricated" được phép dài hơn, vì đó là nội dung người dùng cần đọc.
3. **Không ghi tên backend hay công cụ** trên UI: không "RefChecker", "Saffron", "Semantic Scholar", "CrossRef"…, không số phiên bản, không huy hiệu kỹ thuật ("TLS", "Build 412", "Audit"…).
4. **Không có thanh "Simulate state / Preview state" trong màn hình thật.** Mỗi trạng thái là một frame riêng.
5. **Ưu tiên icon + nhãn ngắn** thay cho câu giải thích. Trạng thái luôn có icon + chữ + màu.

---

## 1. Sitemap / Kiến trúc thông tin

**12 màn hình chính** (dialog, sheet và biến thể trạng thái không tính):

```
[1] Sign-in  /sign-in                               ← chưa đăng nhập
 └─► [0] Connect server  /connect                   ← chỉ lần đầu: chưa lưu địa chỉ server
      └─► Bottom navigation: Analyze · History · Profile
           ├─ [2] Analyze   /analyze                    (chuông → [10] Notifications)
           │     └─► [3] Analyzing  /analyses/:id/progress          (ẩn bottom nav)
           │            └─► [4] Overview  /analyses/:id
           │                   ├─► [5] Topics  /analyses/:id/topics
           │                   │      └─► [6] Topic  /analyses/:id/topics/:topicId
           │                   │             └─► [8] Reference
           │                   ├─► [7] References  /analyses/:id/references?filter=
           │                   │      └─► [8] Reference  /analyses/:id/references/:refId
           │                   │             └─ (overlay) Dialog "Likely fabricated"
           │                   └─ (overlay) Sheet "Export report"
           ├─ [9] History   /history
           │     └─► [4] Overview → [5] / [7] → [6] / [8]
           └─ [11] Profile  /profile
                 ├─► [0] Connect server ("Change server")   /profile/server
                 ├─► [10] Notifications
                 └─ "Firebase demo": Export · Remote Config · Crashlytics
```

| Cấp | Màn hình | Vai trò |
|---|---|---|
| Cổng vào | 1 Sign-in · 0 Connect server | Router tự chuyển: chưa đăng nhập → [1]; chưa lưu server → [0] |
| Cấp cao (tab) | 2 Analyze · 9 History · 11 Profile | Phân tích bài mới · xem lại · tài khoản và cấu hình |
| Cấp con | 3 → 4 → 5 → 6 → 8; 4 → 7 → 8 | *bài dựa trên gì* → *mảng nào yếu* → *reference nào làm nó yếu* → *vì sao* |
| Phụ | 10 Notifications | Mở từ chuông ở [2], từ [11], hoặc chạm vào push |
| Overlay | Sheet Export report · Dialog Likely fabricated · Stop analysis? · Delete check? · Rename · Test crash? | Không tính vào 12 màn |

**Vì sao cấu trúc như vậy**
- **Giữ 3 tab như Lab 2.** Check đổi thành Analyze, Settings đổi thành Profile (Lab 3 yêu cầu profile + khu demo Firebase).
- **Overview: cảnh báo nặng nhất lên đầu, Topics ngay sau.** Topics là câu trả lời chính cho P01, nhưng reference bịa vẫn là tin nặng nhất.
- **[3] ẩn bottom nav.** Job chạy trên server, rời màn không mất gì; xong thì có push.
- **Chỉ [0] và việc bắt đầu phân tích cần tới backend.** Mọi màn kết quả đọc từ Firestore, nên xem được khi laptop tắt.
- **Không có ngõ cụt.** Mở [4] từ push mà không có lịch sử điều hướng thì Back đưa về [9].

---

## 2. Ba user flow

Ký hiệu: **[n]** = màn hình số n · `"…"` = chuỗi trên UI · ⚠ = nhánh lỗi · ↺ = phục hồi.

### Flow A: Phân tích một bài báo

- **Persona:** P01 Linh
- **Start:** tab Analyze **[2]** · **Goal:** có kết quả phân tích · **End:** **[4]** Overview

**Happy path**
1. **[2]** nhập `1706.03762` vào ô `"arXiv ID or link"` (helper `"e.g. 1706.03762"`), hoặc chạm chip `"Try 1706.03762"`.
2. Bật/tắt `"AI check"` → `"Analyze"`.
3. **[3]** `"Analyzing…"`, tên bài, stepper 5 bước:
   `"References"` → `"Verify"` → `"Fabrication check"` → `"Full text"` → `"Topics"`.
   Bên dưới có dòng `"18/41 refs"`.
4. Xong: `"Done"` → `"View results"`.
5. **[4]** tên bài, thẻ cảnh báo, thanh trạng thái 5 màu, thẻ `"Topics"` (`"9 topics · 2 weak"`).

**Alternate paths**
- **A1, đã phân tích trước:** sau bước 2 mở **[4]** ngay.
- **A2, share từ trình duyệt:** Chrome → Share → Realtron → **[2]** đã điền sẵn ID.
- **A3, chạy nền:** **[3]** `"Run in background"` → push `"Analysis done"` (*"Attention Is All You Need · 2 flagged"*) → chạm vào → **[4]**.

**Nhánh lỗi / phục hồi**
- ⚠ **A-E1, sai định dạng:** lỗi dưới ô `"Not a valid arXiv ID"`. ↺ Sửa lại; lỗi tự mất khi gõ.
- ⚠ **A-E2, phân tích thất bại:** banner `"Analysis failed"` + 1 dòng lý do. ↺ `"Retry"` / `"Edit"`.
- ⚠ **A-E3, điện thoại mất mạng:** banner `"Offline · will resume"`. ↺ Tự cập nhật khi có mạng.
- ⚠ **A-E4, dừng:** `"Stop"` → dialog `"Stop analysis?"` (*"Progress will be lost."*) → `"Keep going"` / `"Stop"`.
- ⚠ **A-E5, không tới được server:** banner `"Can't reach server"` (*"Check Tailscale and backend."*). ↺ `"Retry"` / `"Change server"`.

### Flow B: Tìm chủ đề yếu

- **Persona:** P01 Linh, P02 TS. Hùng
- **Start:** **[4]** · **Goal:** biết mảng nào yếu và vì sao · **End:** **[8]**

**Happy path**
1. **[4]** thẻ `"Topics"` → `"Explore"`.
2. **[5]** `"Topics"`. Mỗi dòng: tên chủ đề, `"8 refs"`, thanh trạng thái, nhãn `"Weak"`.
   Chân trang: `"Weak: ≥ 50% refs have issues"`.
3. Chip `"Weak"` → chỉ còn chủ đề yếu.
4. Chạm chủ đề → **[6]**: breadcrumb, thanh trạng thái + số đếm, `"Subtopics"`, danh sách reference (nặng nhất trước).
5. Chạm reference → **[8]**: banner trạng thái, bảng `"Cited"` / `"Actual"`, `"Topics"`, `"Source"`.
6. Reference sai metadata: `"Copy fix"` → snackbar `"Fix copied"`.

**Alternate paths**
- **B1:** chạm thẳng chủ đề yếu trong thẻ Topics ở **[4]** → **[6]**.
- **B2:** **[6]** chạm một Subtopic → **[6]** của chủ đề con.
- **B3 (P02):** **[8]** reference bịa → dialog `"Likely fabricated"` → `"Closest match"` → `"Open"` hoặc `"Search web"`. Dòng lưu ý: *"May be wrong — check the source."*
- **B4:** **[8]** chạm một chip trong `"Topics"` → **[6]** của chủ đề đó.

**Nhánh lỗi / rỗng / phục hồi**
- **B-E1, không có chủ đề yếu:** `"No weak topics"`. ↺ `"Show all"`.
- **B-E2, reference không đọc được:** cuối cây có `"Unclassified · 3"` (*"No readable text"*). Chạm vào → **[7]** lọc theo nhóm này.
- ⚠ **B-E3, lỗi tải:** `"Couldn't load"`. ↺ `"Retry"`.

### Flow C: Xem lại và xuất báo cáo

- **Persona:** P02 TS. Hùng, P01 Linh
- **Start:** tab History **[9]** · **Goal:** mở lại bài và mang báo cáo đi · **End:** đã mở hoặc chia sẻ file PDF

**Happy path**
1. **[9]** nhóm `"Today"` / `"This week"` / `"Earlier"`. Mỗi thẻ có tên bài, `arXiv:…`, thời gian, chip trạng thái.
2. Chạm thẻ → **[4]**.
3. App bar `"Report"` → sheet `"Export report"`:
   `"Creating PDF…"` → `"Saved on device"` + `realtron_1706.03762.pdf · 214 KB`.
4. `"Open"` hoặc `"Share"`. Không có app đọc PDF → snackbar `"No app can open PDF"`.

*Khi bật `enable_cloud_upload`:* `"Creating PDF…"` → `"Uploading 64%"` → `"Uploaded"`, có `"Copy link"` → snackbar `"Link copied"`, hoặc `"Share"`.

**Alternate paths**
- **C1:** ô `"Search"`; không khớp → `"No results"`.
- **C2:** menu ⋮ → `"Rename"` → dialog `"Rename"` → `"Save"`.
- **C3:** **[10]** chạm `"Analysis done"` → **[4]**.
- **C4:** thẻ có chip `"Running"` → **[3]**.

**Nhánh lỗi / phục hồi**
- ⚠ **C-E1, xuất thất bại:** `"Export failed"`. ↺ `"Retry"`.
- ⚠ **C-E2, lỗi tải:** `"Couldn't load"`. ↺ `"Retry"`; kéo xuống để làm mới.
- **C-E3, rỗng:** `"No checks yet"`. ↺ `"Analyze a paper"` → **[2]**.
- ⚠ **C-E4, xoá:** ⋮ → `"Delete"` → dialog `"Delete check?"` (*"Removed from your history."*) → `"Cancel"` / `"Delete"` → snackbar `"Deleted"`.

### Luồng phụ (phải có trong prototype)

- **Sign-in [1]:** logo + `"Realtron"` + 1 dòng `"Know what a paper stands on."` + nút `"Continue with Google"`.
  - Hủy → `"Sign-in cancelled"`.
  - Mất mạng → `"You're offline"`.
- **Connect server [0]:**
  - Ô `"Server URL"` (helper `"e.g. http://100.x.x.x:8000"`).
  - `"Test"` (đang chạy: `"Testing…"`) → `"Connected · 84 ms"` → `"Continue"` (lần đầu) / `"Save"` (từ Profile). Nút chỉ bật sau khi test thành công.
  - Lỗi:
    - `"Enter a server URL"`
    - `"Can't reach server"` + 3 gợi ý ngắn `"Tailscale on?"` · `"Backend running?"` · `"Using http://?"`
    - `"Timed out"`
    - `"Not a Realtron server"`
- **Profile [11]:**
  - Avatar, tên, `"Sign out"`.
  - `"AI check"` (switch).
  - `"Server"` + `"Change"`.
  - Khu `"Firebase demo"`: `"Notifications"`, `"Export report"`, `"Remote Config"`, `"Log error"`, `"Test crash"` → dialog `"Test crash?"` (*"The app will close."*) → `"Cancel"` / `"Crash"`.
- **Notifications [10]:** `"Notifications"`; mục `"Analysis done"` + tên bài · `"2 flagged"` + thời gian + chấm chưa đọc; rỗng `"No notifications"`.

---

## 3. Ánh xạ Flow → Screen

| Màn hình | Flow A | Flow B | Flow C | Trạng thái xuất hiện |
|---|:-:|:-:|:-:|---|
| 0 Connect server | ○ A-E5 | | | idle · testing · connected · failed |
| 1 Sign-in | | | | default · signing in · cancelled · offline |
| 2 Analyze | ● start | | | invalid (A-E1) · can't reach server (A-E5) · có / không Recent |
| 3 Analyzing | ● | | ○ C4 | running · done · failed (A-E2) · offline (A-E3) · stop dialog (A-E4) |
| 4 Overview | ● end | ● start | ● | loading · error · hallucinated / error / clean · có / không chủ đề yếu |
| 5 Topics | | ● | | loading · error · All / Weak · empty Weak (B-E1) · Unclassified (B-E2) |
| 6 Topic | | ● | | loading · error · có / không Subtopics · lọc trạng thái |
| 7 References | | ○ B-E2 | | có bộ lọc · empty "Nothing here" |
| 8 Reference | | ● end | | error/warning (Copy fix) · hallucinated (dialog) · verified |
| 9 History | | | ● start | loading · error · empty · có dữ liệu · running |
| 10 Notifications | ○ A3 | | ○ C3 | có / không thông báo · chưa đọc |
| 11 Profile | | | | khu Firebase demo · dialog test crash |
| Sheet Export report | | | ● end | creating · saved · uploading · uploaded · failed (C-E1) |

● = nằm trên đường chính · ○ = nhánh thay thế / lỗi

## 4. Persona → Flow

| Persona | Flow dùng nhiều nhất | Điểm khác trên cùng flow |
|---|---|---|
| P01 Linh | A, B | Dùng "Run in background" và push nhiều nhất; kết thúc ở việc biết mảng nào yếu |
| P02 TS. Hùng | B (B3), C | Cần dialog Likely fabricated; kết thúc bằng link báo cáo PDF |
| P03 Khoa | Connect server, A-E5 | Cần lỗi kết nối phân biệt được nguyên nhân |

## 5. Flow dễ thất bại nhất

**Flow A:** lâu, và phụ thuộc vào laptop chạy backend qua Tailscale. Cách chống thất bại:
1. Kiểm tra định dạng trên máy (A-E1).
2. Bài đã phân tích thì mở ngay (A1).
3. Job chạy trên server, app chỉ nghe tiến độ (A-E3, A3).
4. Không tới được server thì nói rõ và có đường sửa (A-E5).

**Rủi ro hiểu sai ở Flow B:** "Weak" có thể bị hiểu thành "bài sai". Vì vậy:
- Luôn có dòng định nghĩa ngắn ở chân màn [5].
- Ngưỡng lấy từ Remote Config.
- "Unclassified" được hiện công khai, không bị bỏ đi lặng lẽ.
