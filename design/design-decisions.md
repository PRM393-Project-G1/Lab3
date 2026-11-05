# Design decisions: Realtron

> Mỗi quyết định ghi **đề xuất của AI → nhóm làm gì → lý do → persona**.
> Persona: [persona.md](persona.md) · Nhật ký AI: [ai-design-log.md](ai-design-log.md) (mã F1–F13, vòng 1b, R0–R3) · Flow: [user-flow.md](user-flow.md)

**Nguyên tắc dùng để quyết định:**
1. Giao diện không được hứa điều hệ thống không làm được.
2. Chữ ngắn, dễ quét (góp ý của thầy, 04/11/2026). Riêng kết quả phân tích được dài hơn.
3. Tin nặng nhất hiện trước.
4. Kết luận tự động phải có bằng chứng và cách nói thận trọng.
5. Khi có lỗi, người dùng biết nguyên nhân và cách phục hồi.

## Bảng quyết định

| ID | Loại | Đề xuất của AI (Stitch) | Bản cuối | Lý do | Persona | Nguồn |
|---|---|---|---|---|---|---|
| D1 | **Accept** | Design system "Academic Verifier": navy, Source Serif 4 + Inter | Giữ, kế thừa từ Lab 2 | Đã kiểm tra contrast, hợp bối cảnh đọc tài liệu khoa học | P01, P02 | Prompt 1 |
| D2 | **Accept** | Cây chủ đề thụt lề, có nhãn Weak + icon, nhóm Unclassified | Giữ | Đúng câu hỏi cốt lõi "bài dựa trên gì, mảng nào yếu". Nhóm Unclassified nói thật về giới hạn dữ liệu | P01 | Prompt 2 |
| D3 | **Accept** | Trạng thái luôn có icon + chữ + màu | Giữ | Không phụ thuộc màu | Tất cả | Prompt 1 |
| D4 | **Accept** | Bảng Cited / Actual tô đúng ô lệch | Giữ | P01 sửa nhanh, P02 có bằng chứng | P01, P02 | Prompt 2 |
| D5 | **Reject** | Thanh "Simulate state / Preview state / QA Mode" nằm trong màn hình | Bỏ. Mỗi trạng thái là một frame riêng | Đây là công cụ xem trước, không phải chức năng. Người dùng không cần, và làm rối giao diện | Tất cả | F2, R0 |
| D6 | **Reject** | "54.2", "92.7% audited", "Integrity Score 78%", "TLS 1.3 Certified", "Build 412", "4.2 req/s", "Est. time remaining" | Bỏ hết | Số không có nguồn. App kiểm tra trích dẫn bịa thì không được hiện số bịa | P02 | F3, R0 |
| D7 | **Modify** | App bar "Audit Inspection", nút "ANALYZE CITATION GRAPH", "Audit Pipeline" | Tên app **Realtron**, nút "Analyze", không có từ "audit" | Giọng kỹ thuật, sai tên. Nhóm đổi tên dự án thành Realtron | P01 | F4, R0, R1b |
| D8 | **Reject** | Chip "Crossref · arXiv · DBLP", "Semantic Scholar & Crossref Cache", "Validated via CrossRef" | Không ghi tên backend hay công cụ ở bất kỳ đâu | Yêu cầu của nhóm: người dùng không cần biết phần nào do backend nào làm | Tất cả | F5, R0, R1b |
| D9 | **Modify** | Đoạn giới thiệu, khối "Institutional assurance", mô tả dưới mỗi bước stepper | Nút 1–2 từ, tiêu đề ≤ 3 từ, tối đa 1 dòng phụ; stepper chỉ còn tên bước | Thầy góp ý giao diện quá nhiều chữ. Riêng phần kết quả giữ nguyên độ dài | Tất cả | F6, R1, R1b |
| D10 | **Reject** | Khối "Rigorous verification in seconds", "High Density Ingestion", nhãn "Recommended" | Bỏ | Trang trí, không phục vụ flow nào | P01 | F7, R0, R1b |
| D11 | **Reject** | Thông báo "Backend server connected", "PDF Export ready", "Automated sync" | Chỉ còn thông báo "Analysis done" | Flow chỉ có thông báo khi phân tích xong | P01 | F8, R1b |
| D12 | **Reject** | Nhãn "Verified Member" ở Profile | Bỏ | Hệ thống không có khái niệm thành viên xác minh | Tất cả | F10, R3-fix |
| D13 | **Modify** | Empty/error state có câu giải thích dài ("Failed to load paper details… Check your network…") | Chỉ giữ tiêu đề + nút theo `user-flow.md`. Sửa tay trên Figma | Vi phạm quy tắc chữ ngắn | Tất cả | F12 |
| D14 | **Modify** | App bar của frame trạng thái hiện cả tên frame ("Sign In — Cancelled") | App bar chỉ ghi tên màn. Sửa tay trên Figma | Tên frame là nhãn nội bộ, không phải chữ trên UI | Tất cả | F13 |
| D15 | **Modify** | Viền ô nhập `#CBD5E1` (kế thừa từ Lab 2) | `outline` = `#64748B` | Chỉ đạt 1.42:1, dưới mức 3:1 của WCAG 1.4.11. Đo lại ở Lab 3 | P02 | DESIGN.md mục 7 |

## Tồn tại (chưa giải quyết)

| ID | Vấn đề | Hướng xử lý |
|---|---|---|
| T1 | Stitch báo đã đạt accessibility ở R2, nhưng ảnh chụp không đo được vùng chạm và cỡ chữ | Đo bằng plugin trên Figma; đo lại trong app ở 360 / 412 dp |
| T2 | Ngưỡng "Weak ≥ 50%" là giả định (A3) | Để trong Remote Config, kiểm chứng khi thử nghiệm |
| T3 | Tên chủ đề là cụm từ tiếng Anh do máy sinh (A4) | Chấp nhận ở Lab 3; bài Final dự kiến dùng Gemini sinh tên dễ hiểu |
