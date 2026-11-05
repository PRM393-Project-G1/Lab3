# Prototype map: Realtron

> Bảng tương tác của Figma page 06 Prototype. Mỗi dòng là một chạm trên frame nguồn dẫn tới frame đích.
> Trạng thái: `Todo` · `Done`. `Done` nghĩa là đã nối trên Figma, **chưa chạy thử bằng Present**.
>
> Điểm chạm thực tế khác bảng ở các dòng sau, vì frame không có phần tử đó:
> Connect Server — Failed dùng `Retry`; Topic Map sang No weak topics dùng chip `Weak`; Reference List — Empty dùng chip `All`; History — No results dùng `Clear search`; Export: Uploaded dùng `Done`; Notifications sang Empty dùng `Mark all read`; Paper Overview sang Export dùng icon cạnh tiêu đề (frame chưa có nút `Report`); Analyze sang Notifications dùng icon góc phải (frame chưa có chuông).

## Điểm bắt đầu (chưa đặt trên Figma)

| Starting point | Frame đầu | Luồng |
|---|---|---|
| Entry | Sign In | Đăng nhập, kết nối server |
| Flow A | Analyze | Phân tích bài báo |
| Flow B | Paper Overview | Tìm chủ đề yếu |
| Flow C | History | Xem lại và xuất báo cáo |

## Entry

| Frame nguồn | Chạm vào | Frame đích | Nhánh | Trạng thái |
|---|---|---|---|---|
| Sign In | Continue with Google | Connect Server | Chính | Done |
| Sign In | Know what a paper stands on. | Sign In — Cancelled | Lỗi: hủy đăng nhập | Done |
| Sign In — Cancelled | Continue with Google | Connect Server | Thử lại | Done |
| Connect Server | Test | Connect Server — Failed | Lỗi: không tới được server | Done |
| Connect Server — Failed | Test | Connect Server | Thử lại | Done |
| Connect Server | Continue | Analyze | Chính | Done |

## Flow A

| Frame nguồn | Chạm vào | Frame đích | Nhánh | Trạng thái |
|---|---|---|---|---|
| Analyze | Analyze | Analysis in Progress | Chính | Done |
| Analyze | Ô nhập | Analyze — Invalid | A-E1: sai định dạng | Done |
| Analyze — Invalid | Ô nhập | Analyze | Sửa lại | Done |
| Analyze | Recent | Analyze — First use | Chưa có lịch sử | Done |
| Analyze | See all | Analyze — Server unreachable | A-E5: mất server | Done |
| Analyze — Server unreachable | Change server | Connect Server | Sửa server | Done |
| Analyze — Server unreachable | Retry | Analyze | Thử lại | Done |
| Analysis in Progress | Run in background | History | A3: chạy nền | Done |
| Analysis in Progress | Stop | Analysis — Stop dialog | A-E4: dừng | Done |
| Analysis — Stop dialog | Keep going | Analysis in Progress | Ở lại | Done |
| Analysis — Stop dialog | Stop | Analyze | Dừng | Done |
| Analysis in Progress | Bước Verify | Analysis — Done | Chính | Done |
| Analysis in Progress | Bước Fabrication check | Analysis — Failed | A-E2: thất bại | Done |
| Analysis in Progress | Bước Full text | Analysis — Offline | A-E3: mất mạng | Done |
| Analysis — Failed | Retry | Analysis in Progress | Thử lại | Done |
| Analysis — Offline | Offline · will resume | Analysis in Progress | Có mạng lại | Done |
| Analysis — Done | View results | Paper Overview | Chính | Done |

## Flow B

| Frame nguồn | Chạm vào | Frame đích | Nhánh | Trạng thái |
|---|---|---|---|---|
| Paper Overview | Explore | Topic Map | Chính | Done |
| Paper Overview | Review | Reference List | Chính | Done |
| Paper Overview | Tiêu đề bài báo | Paper Overview — Error | Lỗi tải | Done |
| Paper Overview — Error | Retry | Paper Overview — Loading | Thử lại | Done |
| Paper Overview — Loading | Tự chuyển sau 1,5 giây | Paper Overview | Tải xong | Done |
| Topic Map | Thẻ chủ đề đầu | Topic Detail | Chính | Done |
| Topic Map | 9 topics · 2 weak | Topic Map — No weak topics | B-E1 | Done |
| Topic Map — No weak topics | Show all | Topic Map | Quay lại | Done |
| Topic Map | Tiêu đề bài báo | Topic Map — Error | B-E3 | Done |
| Topic Map — Error | Retry | Topic Map | Thử lại | Done |
| Topic Detail | Reference đầu | Reference Detail | Chính | Done |
| Reference Detail | Copy fix | Topic Detail | Xong | Done |
| Reference List | Thẻ Hallucinated đầu | Reference — Likely fabricated dialog | B3 | Done |
| Reference — Likely fabricated dialog | Open | Reference Detail | B3 | Done |
| Reference — Likely fabricated dialog | Search web | Reference List | B3 | Done |
| Reference List | Thẻ Error đầu | Reference Detail | Chính | Done |
| Reference List | Chip All | Reference List — Empty | Lọc không có kết quả | Done |
| Reference List — Empty | Show all | Reference List | Quay lại | Done |

## Flow C

| Frame nguồn | Chạm vào | Frame đích | Nhánh | Trạng thái |
|---|---|---|---|---|
| History | Thẻ đầu | Paper Overview | Chính | Done |
| History | Ô Search | History — No results | C1 | Done |
| History — No results | Tiêu đề No results | History | Xoá tìm kiếm | Done |
| History | ⋮ thẻ đầu | History — Delete dialog | C-E4 | Done |
| History — Delete dialog | Cancel | History | Giữ lại | Done |
| History — Delete dialog | Delete | History — Empty | Đã xoá | Done |
| History — Empty | Analyze a paper | Analyze | C-E3 | Done |
| History | ⋮ thẻ thứ hai | History — Rename dialog | C2 | Done |
| History — Rename dialog | Save | History | Đã đổi tên | Done |
| History | Tiêu đề History | History — Error | Lỗi tải | Done |
| History — Error | Retry | History — Loading | Thử lại | Done |
| History — Loading | Tự chuyển sau 1,5 giây | History | Tải xong | Cần kiểm tra trigger |
| Paper Overview | Nút Report trên app bar | Export: Creating PDF | Chính | Done |
| Export: Creating PDF | Tự chuyển sau 1,5 giây | Export: Uploading 64% | Chính | Done |
| Export: Uploading 64% | Tự chuyển sau 1,5 giây | Export: Uploaded | Chính | Done |
| Export: Uploading 64% | Cancel | Export — Upload failed | C-E1 | Done |
| Export — Upload failed | Retry | Export: Creating PDF | Thử lại | Done |
| Export: Uploaded | Share | Paper Overview | Xong | Done |

## Dùng chung

| Frame nguồn | Chạm vào | Frame đích | Trạng thái |
|---|---|---|---|
| Analyze | Tab History | History | Done |
| Analyze | Tab Profile | Profile | Done |
| Analyze | Chuông | Notifications | Done |
| Notifications | Dòng Analysis done | Paper Overview | Done |
| Notifications | Tiêu đề Notifications | Notifications — Empty | Done |
| Profile | Test crash | Profile — Test crash dialog | Done |
| Profile — Test crash dialog | Cancel | Profile | Done |
| Profile | Sign out | Sign In | Done |
| History | Tab Analyze | Analyze | Done |
| History | Tab Profile | Profile | Done |
| Profile | Tab Analyze | Analyze | Done |
| Profile | Tab History | History | Done |
