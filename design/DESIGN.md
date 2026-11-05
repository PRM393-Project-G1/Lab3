# DESIGN.md — Realtron

> Design system **"Academic Verifier"**, kế thừa từ Lab 2 và do Stitch dựng lại cho sản phẩm Realtron.
> File này là nguồn chuẩn cho Figma page 04 / 05 và `lib/theme/`. Ánh xạ sang Flutter nằm ở [`handoff/flutter-handoff.md`](../handoff/flutter-handoff.md).
> Chữ trên UI: xem [`user-flow.md`](user-flow.md) mục 0.

## 1. Sản phẩm

- **Persona:** P01 Linh (Primary), P02 TS. Hùng (Secondary), P03 Khoa (Supporting). Chi tiết ở [`persona.md`](persona.md).
- **Tiêu chí thành công:** ≥ 4/5 người thử tự hoàn thành "phân tích bài → nói ra 3 mảng chính và chủ đề yếu nhất → mở một reference có vấn đề", phần này ≤ 2 phút kể từ khi Overview hiện ra.
- **3 flow:** A phân tích bài báo · B tìm chủ đề yếu · C xem lại và xuất báo cáo.
- **Nền tảng:** Android, Material 3, 360–412 dp, chỉ màn dọc.

## 2. Phong cách

Học thuật, đáng tin, yên tĩnh. Nền nhạt, card trắng, navy làm điểm neo. Tiêu đề serif, nội dung sans. Chữ ít, nhiều khoảng trắng, ưu tiên icon + nhãn ngắn.

## 3. Màu

### Thương hiệu và bề mặt

| Token | Giá trị | Dùng cho |
|---|---|---|
| `primary` / `on-primary` | `#1E3A8A` / `#FFFFFF` | Nút chính, mục đang chọn, link |
| `primary-container` / `on-primary-container` | `#DCE1FF` / `#00164E` | Indicator của bottom nav, nền icon |
| `background` | `#F8FAFC` | Nền màn hình |
| `surface` | `#FFFFFF` | Card, app bar, bottom nav |
| `surface-container` / `-high` | `#F1F5F9` / `#E2E8F0` | Nền nhóm, nền thanh tiến độ, skeleton |
| `outline` | `#64748B` | **Viền ô nhập** (đạt 3:1) |
| `outline-variant` | `#E2E8F0` | Viền card, divider (trang trí) |
| `text-primary` / `-secondary` / `-muted` | `#0F172A` / `#475569` / `#64748B` | Chữ. `text-muted` không dùng trên `surface-container` |

### Trạng thái reference (luôn đi kèm icon + chữ)

Thứ tự ưu tiên: **Hallucinated > Error > Warning > Unverified > Verified**.

| Trạng thái | Chữ | Icon | Nền | Viền | Icon Material |
|---|---|---|---|---|---|
| Hallucinated | `#7E22CE` | `#7E22CE` | `#FAF5FF` | `#E9D5FF` | `gpp_bad` |
| Error | `#B91C1C` | `#B91C1C` | `#FEF2F2` | `#FECACA` | `error` |
| Warning | `#92400E` | `#D97706` | `#FFFBEB` | `#FDE68A` | `warning_amber` |
| Unverified | `#475569` | `#475569` | `#F8FAFC` | `#E2E8F0` | `help` |
| Verified | `#15803D` | `#15803D` | `#F0FDF4` | `#BBF7D0` | `check_circle` |

Nhãn **"Weak"** dùng bộ màu Error, kèm icon cảnh báo và chữ "Weak".

## 4. Chữ

| Token | Font | Cỡ / đậm | Dùng cho |
|---|---|---|---|
| `headline-lg` | Source Serif 4 | 28 / 600 | Tên app ở Sign-in |
| `headline-md` | Source Serif 4 | 22 / 600 | Tiêu đề màn, tên chủ đề ở Topic |
| `paper-title` | Source Serif 4 | 18 / 600 | Tên bài báo, tên reference |
| `title-md` | Inter | 16 / 600 | Tiêu đề card, banner |
| `body-lg` | Inter | 16 / 400 | Nội dung chính |
| `body-md` | Inter | 14 / 400 | Nội dung phụ (mức tối thiểu của nội dung) |
| `label` | Inter | 14 / 600 | Nhãn nút |
| `overline` | Inter | 12 / 600, tracking 0.8 | Nhãn nhóm |
| `chip` | Inter | 12 / 600 | Chip trạng thái, nhãn tab |
| `mono` | JetBrains Mono | 13 / 400 | arXiv ID, DOI, URL, tên file, key Remote Config |

## 5. Khoảng cách, bo góc, bóng, kích thước

| Nhóm | Token | Giá trị |
|---|---|---|
| Spacing | `space-xs` · `-sm` · `-md` · `-lg` · `-xl` | 4 · 8 · 16 · 24 · 32 dp; lề trang 16 dp |
| Radius | `sm` (chip) · `md` (nút, ô nhập) · `lg` (card) · `xl` (dialog, sheet) | 6 · 8 · 12 · 24 dp |
| Elevation | Level 1 (card) · Level 2 (thanh đáy, sheet) | `0 1 3 rgba(15,23,42,.05)` · `0 4 12 rgba(15,23,42,.08)` |
| Size | Vùng chạm tối thiểu · chiều cao ô nhập | 48 · 56 dp |

## 6. Component

Danh sách đầy đủ và ánh xạ sang widget: [`flutter-handoff.md`](../handoff/flutter-handoff.md) Bảng 2. Gồm:
Button · Text field · Card · Reference card · History card · Status chip · Weak tag · Filter chip · Stacked status bar · Topic tree node · Analysis stepper · Banner · Empty / Error / Loading · Dialog · Export sheet · Notification tile · Remote Config row · Section label · App bar · Bottom nav.

## 7. Checklist accessibility

Tỉ lệ dưới đây tính bằng công thức relative luminance của WCAG 2.1.

| Cặp màu | Tỉ lệ | Yêu cầu | Kết quả |
|---|---|---|---|
| `#FFFFFF` trên `primary` | 10.36:1 | 4.5:1 | Đạt |
| `primary` trên `background` | 9.90:1 | 4.5:1 | Đạt |
| `text-primary` trên `surface` | 17.85:1 | 4.5:1 | Đạt |
| `text-secondary` trên `surface` | 7.58:1 | 4.5:1 | Đạt |
| `text-secondary` trên `surface-container` | 6.92:1 | 4.5:1 | Đạt |
| `text-muted` trên `background` / `surface` | 4.55:1 / 4.76:1 | 4.5:1 | Đạt |
| `text-muted` trên `surface-container` | 4.34:1 | 4.5:1 | **Không đạt → cấm dùng cặp này** |
| Hallucinated chữ / nền | 6.51:1 | 4.5:1 | Đạt |
| Error chữ / nền | 5.91:1 | 4.5:1 | Đạt |
| Warning chữ / nền | 6.84:1 | 4.5:1 | Đạt |
| Verified chữ / nền | 4.79:1 | 4.5:1 | Đạt |
| Unverified chữ / nền | 7.24:1 | 4.5:1 | Đạt |
| Icon Warning trên nền của nó | 3.07:1 | 3:1 (đồ hoạ) | Đạt, chỉ dùng cho icon |
| Viền ô nhập `outline` trên `background` | 4.55:1 | 3:1 (WCAG 1.4.11) | Đạt (Lab 2 dùng `#CBD5E1`, chỉ 1.42:1, nên đã đổi) |

Quy tắc bắt buộc, phải đúng cả trên Figma lẫn trong app:
- [ ] Vùng chạm ≥ 48×48 dp, cách nhau ≥ 8 dp.
- [ ] Nội dung ≥ 14 sp; chỉ nhãn chip và overline được 12 sp.
- [ ] Không truyền đạt ý nghĩa chỉ bằng màu: trạng thái có icon + chữ; thanh trạng thái có số đếm hoặc nhãn trợ năng.
- [ ] Bố cục đúng ở 360 dp và 412 dp, không tràn khi cỡ chữ hệ thống 130%.
- [ ] Tên chủ đề không bị cắt "…"; xuống dòng tối đa 2 dòng.
