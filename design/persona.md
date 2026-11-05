# Persona: Realtron (Lab 3)

> Theo **Persona Guideline (Student Edition v1.0)** của môn: https://prm393-material.web.app/persona-guideline
> **Trạng thái: Proto-Persona.** Viết lại từ bộ persona Lab 2 (`../lab2/code/Lab2/ux/persona.md`) cho sản phẩm mới: **RefCheck + Saffron** ("Hiểu nhanh một bài báo qua danh sách tham khảo của nó").
> Nhóm **chưa** phỏng vấn người dùng thật. Mọi nội dung đều có nhãn nguồn. Kế hoạch kiểm chứng ở mục 7.

**Nhãn dữ liệu** (theo mục 06 của guideline)

| Nhãn | Nghĩa |
|---|---|
| `[Observed]` | Nhóm quan sát trực tiếp, có ngữ cảnh |
| `[Reported]` | Người tham gia tự kể, có mã nguồn (I01, I02, …) |
| `[Inferred]` | Nhóm suy ra từ một nguồn, có nêu lập luận |
| `[Assumed]` | Chưa có bằng chứng, phải kiểm chứng |

---

## 1. Phạm vi sản phẩm và nhiệm vụ cốt lõi

- **Sản phẩm:** **Realtron**, app Android. Người dùng nhập arXiv ID của một bài báo; backend của nhóm (chạy trên laptop, truy cập qua Tailscale) làm 3 việc:
  - **RefChecker** kiểm tra từng reference: bịa (hallucinated), sai metadata (error), lỗi nhẹ (warning), đúng (verified), không tìm thấy (unverified).
  - Lấy văn bản của các reference đọc được.
  - **Saffron** gom reference thành **cây chủ đề**.

  App hiển thị bài báo dựa trên những mảng kiến thức nào, mỗi mảng có bao nhiêu reference, bao nhiêu trong số đó lỗi hoặc bịa, và mảng nào **"yếu"**.
- **Nhiệm vụ cốt lõi:** gửi một bài báo → chờ phân tích → xem cây chủ đề → tìm chủ đề yếu → hiểu reference nào làm nó yếu và vì sao.
- **Ngoài phạm vi:** tóm tắt nội dung bài báo, viết bài, quản lý thư viện tài liệu (Zotero/Mendeley), upload PDF, iOS.

**Problem statement**
> Sinh viên phải đọc một bài báo lạ và người phản biện phải đánh giá nhanh một bài. Cả hai cần biết **bài dựa trên những mảng kiến thức nào** và **mảng nào có nền tảng đáng ngờ**.
> Hiện họ phải đọc lướt 40–60 reference từng dòng. Họ không biết nên đọc nền tảng nào trước, và không biết reference nào có thật.

**Tiêu chí thành công đo được (của cả sản phẩm)**
> Trong buổi thử nghiệm, **≥ 4/5 người tham gia** tự hoàn thành flow "phân tích bài bằng arXiv ID → nói ra 3 mảng kiến thức chính và chủ đề yếu nhất → mở một reference có vấn đề trong chủ đề đó" mà không cần trợ giúp.
> Phần này mất **≤ 2 phút** kể từ khi màn Paper overview hiện ra.

**Bằng chứng thứ cấp cho thấy vấn đề có thật** `[Inferred]`
- **Nguồn:** nghiên cứu *Phantom References* (arXiv 2607.00738) của nhóm tác giả RefChecker (`refcheck/refchecker/docs/PAPER.md`).
- **Kết quả:** năm 2025, khoảng **1/20** bài được nhận đăng tại NeurIPS và USENIX Security có ít nhất 2 reference khả năng cao là bịa.
- **Lập luận:** đọc một bài, kể cả bài đã qua peer review, không có nghĩa là toàn bộ nền tảng của nó đáng tin.
- **Giới hạn:** nguồn này **chỉ chứng minh vấn đề tồn tại**. Nó không chứng minh rằng người đọc cần xem nền tảng theo chủ đề.

---

## 2. Bản đồ người dùng và các bên liên quan

```
                    ┌──────────────────────── Người dùng trực tiếp ───────────────────────────┐
                    │  Người đọc bài lạ (SV năm cuối, học viên cao học, journal club)  → P01   │
                    │  Người phản biện / giảng viên hướng dẫn                          → P02   │
                    │  Người vận hành backend cho nhóm (laptop + Tailscale)            → P03   │
                    └─────────────────────────────────────────────────────────────────────────┘
   Gián tiếp: tác giả bài báo (bị đánh giá qua reference) · người nghe seminar · ban biên tập
   Dễ bị bỏ sót: người chưa quen thuật ngữ "hallucinated" · người dùng TalkBack / mù màu
              · người chỉ có 4G yếu · người đọc tiếng Anh chưa tốt (tên chủ đề là cụm từ tiếng Anh)
```

---

## 3. Số lượng persona và lý do

Đây là **bài nhóm**, nên theo guideline cần 3–5 persona. Nhóm giữ **3 persona: 1 Primary, 1 Secondary, 1 Supporting**, cùng tên với Lab 2 nhưng nhiệm vụ và nhu cầu đã viết lại cho sản phẩm mới.

**Thay đổi so với Lab 2:**
- **P01** chuyển từ "người tự kiểm tra bài của mình" sang **"người đọc hiểu bài lạ"**.
  Lý do: sản phẩm mới trả lời câu hỏi *bài này dựa trên gì*, không còn là *bài của tôi sai ở đâu*.
- **P02** giữ vai trò phản biện, thêm nhu cầu **nhận xét theo từng mảng nền tảng**.
- **P03** giữ nguyên vai trò, nhưng backend nặng hơn: thêm Saffron (Java, khoảng 3GB model).

**Đã cân nhắc nhưng chưa tách:** *"Người đọc tiếng Anh chưa tốt"*. Tên chủ đề do Saffron sinh ra là cụm từ tiếng Anh.
→ *Câu hỏi mở Q2:* nếu phỏng vấn cho thấy đây là rào cản lớn, nhóm sẽ tách thành P04. Bài Final dự kiến có tính năng Gemini sinh tên chủ đề dễ hiểu.

### Persona Coverage Matrix

| Archetype | Nhiệm vụ chính | Thiết bị / rào cản | Khác biệt thiết kế cần có | Bằng chứng |
|---|---|---|---|---|
| **P01 · Người đọc hiểu bài lạ** (Primary) | Nắm nhanh nền tảng của bài trước khi đọc kỹ / trình bày | Điện thoại, thời gian ngắt quãng, 4G chập chờn | Cây chủ đề đọc được ở 360 dp; chủ đề yếu nổi lên đầu; chạy nền + thông báo khi xong | `[Inferred]` vấn đề; `[Assumed]` hành vi |
| **P02 · Người phản biện cần bằng chứng** (Secondary) | Đánh giá nền tảng bài người khác, viết nhận xét theo mảng | Điện thoại/tablet; chữ lớn; ít thời gian | Bằng chứng cho từng reference; ngôn ngữ thận trọng "Likely"; xuất báo cáo PDF | `[Assumed]` |
| **P03 · Người vận hành backend** (Supporting) | Chạy RefChecker + Saffron, giúp người khác kết nối | Laptop làm server; Tailscale; laptop ngủ | Kiểm tra kết nối trước; lỗi chỉ đúng nguyên nhân; kết quả cũ xem được khi server tắt | `[Observed]` sự cố Tailscale ở Lab 2; còn lại `[Assumed]` |

---

## 4. Persona chi tiết (12 trường bắt buộc)

### P01 · Linh: "Người đọc hiểu bài lạ" · **Primary**

| # | Trường | Nội dung | Nguồn |
|---|---|---|---|
| — | Thông tin bắt buộc | **23 tuổi** · **Sinh viên năm 4 CNTT**, đang làm khoá luận, tuần nào cũng phải trình bày một bài báo ở journal club của lab. **Thói quen thiết bị:** điện thoại Android tầm trung 6.5" (khoảng 360–412 dp), dùng hằng ngày; nhận link arXiv qua Zalo/Messenger. **Nhu cầu tiếp cận:** hay dùng một tay, ngoài trời; cần contrast cao và vùng chạm lớn | `[Assumed]` |
| 01 | Identity & Archetype | Linh: người phải hiểu nhanh một bài báo **không phải của mình** | `[Assumed]` |
| 02 | Persona Priority | **Primary**: đại diện cho nhiệm vụ cốt lõi. Luồng Analyze → Progress → Overview → Topic map → Topic detail được thiết kế ưu tiên cho Linh | — |
| 03 | Usage Context | Nhận link bài từ thầy hoặc bạn; mở app trên xe buýt hay giữa hai tiết; một lần phân tích mất vài phút nên khoá màn rồi quay lại; tối mới đọc kỹ trên laptop | `[Assumed]` |
| 04 | Goals | (1) Biết bài dựa trên những mảng kiến thức nào để đọc nền tảng trước. (2) Biết mảng nào có nền tảng đáng ngờ để không trình bày sai. (3) Có sẵn câu hỏi hoặc nhận xét khi trình bày | `[Assumed]` |
| 05 | Job to Be Done | *"Khi nhận một bài báo lạ phải trình bày tuần sau, tôi muốn thấy ngay bài dựa trên những mảng kiến thức nào và mảng nào đáng ngờ, để biết nên đọc gì trước và cẩn thận ở đâu."* | `[Assumed]` |
| 06 | Current Behaviors | Đọc abstract và related work; mở ngẫu nhiên vài reference có tên quen; hỏi ChatGPT "bài này dựa trên kiến thức gì" (không kiểm chứng được); hiếm khi kiểm tra reference có thật không | `[Assumed]` |
| 07 | Pain Points | (1) **40–60 reference, không biết đọc cái nào trước** → đọc lan man, thiếu nền tảng. (2) **Không biết reference có thật không** → có thể trình bày dựa trên nguồn bịa. (3) **Related work viết theo đoạn văn, không thấy cấu trúc** → khó tóm tắt bài đứng trên những mảng nào | `[Assumed]` |
| 08 | Motivations | Hiểu đúng hơn hiểu nhanh; muốn tự kiểm soát (máy gợi ý, mình quyết định); không muốn bị hỏi vặn khi trình bày | `[Assumed]` |
| 09 | Constraints | Màn nhỏ 360–412 dp; mạng chập chờn; đọc tiếng Anh học thuật mức khá; không tự chạy được backend; không trả tiền API | `[Assumed]` |
| 10 | Key Scenarios | **S1 (happy):** *Trigger:* thầy gửi link arXiv tối Chủ nhật, thứ Năm trình bày. *Diễn biến:* share link từ trình duyệt vào app → "Analyze" → khoá màn → nhận thông báo "Analysis done" → Overview: "9 topics · 2 weak" → Explore → chip "Weak" → mở chủ đề yếu → thấy 2 reference "Likely fabricated". *Kết quả:* ghi chú 3 mảng chính và 1 mảng cần cẩn thận. **S2 (lỗi):** Tailscale tắt nên app báo "Can't reach server" kèm gợi ý → bật lại → Retry. Các bài đã phân tích trước vẫn mở được | `[Assumed]` |
| 11 | Success Criteria | Bắt đầu phân tích trong **≤ 3 thao tác**; từ Overview nói được 3 mảng chính + chủ đề yếu nhất trong **≤ 2 phút**; từ chủ đề yếu tới reference có vấn đề **≤ 2 chạm** | Mục tiêu thiết kế, kiểm chứng ở mục 7 |
| 12 | Evidence & Status | **Proto-Persona.** Vấn đề: `[Inferred]` từ *Phantom References*. Bối cảnh, hành vi: `[Assumed]`. Cần kiểm chứng: A1, A2, A3, A4 | — |

### P02 · TS. Hùng: "Người phản biện cần bằng chứng" · **Secondary**

| # | Trường | Nội dung | Nguồn |
|---|---|---|---|
| — | Thông tin bắt buộc | **41 tuổi** · **Giảng viên, hướng dẫn luận văn, reviewer cho hội thảo trong nước**. **Thói quen thiết bị:** điện thoại Android màn lớn và tablet để đọc khi di chuyển; viết nhận xét trên laptop. **Nhu cầu tiếp cận:** lão thị nhẹ, cỡ chữ hệ thống khoảng 115–130% | `[Assumed]` |
| 01 | Identity & Archetype | Hùng: người đánh giá nền tảng bài của **người khác** và cần bằng chứng để kết luận | `[Assumed]` |
| 02 | Persona Priority | **Secondary**: dùng chung luồng chính với P01, nhưng quyết định thiết kế cho Reference detail, dialog Likely fabricated và báo cáo PDF | — |
| 03 | Usage Context | Mỗi đợt review nhận 3–6 bài; xem sơ bộ trên điện thoại lúc chờ họp; viết nhận xét cuối trên laptop | `[Assumed]` |
| 04 | Goals | (1) Thấy mảng nền tảng nào của bài yếu để nhận xét có trọng tâm. (2) Có bằng chứng truy vết được cho từng reference đáng ngờ. (3) Không kết luận oan cho tác giả | `[Assumed]` |
| 05 | Job to Be Done | *"Khi review một bài, tôi muốn thấy mảng nền tảng nào dựa trên reference sai hoặc bịa, kèm bằng chứng, để viết nhận xét cụ thể và công bằng."* | `[Assumed]` |
| 06 | Current Behaviors | Kiểm tra ngẫu nhiên 3–5 reference trông lạ; tra DOI trên trình duyệt; nhận xét chung chung kiểu "cần rà lại tài liệu tham khảo" | `[Assumed]` |
| 07 | Pain Points | (1) **Nhận xét chung chung** vì không biết lỗi tập trung ở mảng nào. (2) **Công cụ báo "không tìm thấy" mà không giải thích** → không dám kết luận. (3) **Chép kết quả sang báo cáo review mất công** | `[Assumed]` |
| 08 | Motivations | Công bằng, chính xác; bằng chứng có link; giữ uy tín người phản biện | `[Assumed]` |
| 09 | Constraints | Không muốn cấu hình phức tạp; chữ phải đọc được khi bật cỡ chữ lớn; ít thời gian cho mỗi bài | `[Assumed]` |
| 10 | Key Scenarios | **S3:** *Trigger:* bài review có related work viết trơn nhưng vài reference lạ. *Diễn biến:* mở bài từ History → Overview → Topics → chủ đề "Weak" → reference Hallucinated → dialog *Likely fabricated* → *Open* → quay lại Overview → "Report" → upload PDF → "Copy link". *Kết quả:* nhận xét nêu rõ mảng yếu kèm link báo cáo | `[Assumed]` |
| 11 | Success Criteria | Tìm được bằng chứng cho 1 reference đáng ngờ trong **≤ 1 phút**; xuất được báo cáo trong **≤ 3 chạm** từ Overview; sau thử nghiệm **không ai hiểu "Likely" thành "chắc chắn bịa"**, và **không ai hiểu "Weak" thành "bài sai"** | Mục tiêu thiết kế |
| 12 | Evidence & Status | **Proto-Persona**, toàn bộ `[Assumed]`. Cần kiểm chứng: A5, A6 | — |

**Khác P01 ở đâu:** Hùng không cần lộ trình đọc. Hùng cần **bằng chứng, cách diễn đạt thận trọng và báo cáo mang đi được**, và layout không được vỡ khi chữ to.

### P03 · Khoa: "Người vận hành backend cho nhóm" · **Supporting**

| # | Trường | Nội dung | Nguồn |
|---|---|---|---|
| — | Thông tin bắt buộc | **22 tuổi** · **Sinh viên năm 4 CNTT**, chạy backend RefChecker + Saffron trên laptop cho nhóm. **Thói quen thiết bị:** laptop Windows làm server; điện thoại Android để thử app. **Nhu cầu tiếp cận:** hay hướng dẫn qua tin nhắn nên cần thông báo lỗi chụp gửi được | `[Assumed]` |
| 01 | Identity & Archetype | Khoa: người giữ cho backend chạy để người khác dùng được app | `[Assumed]` |
| 02 | Persona Priority | **Supporting**: nếu Khoa thất bại thì P01, P02 không phân tích được bài mới. Quyết định thiết kế màn Connect server, thông báo lỗi và việc kết quả cũ vẫn xem được khi server tắt | — |
| 03 | Usage Context | Cài lần đầu ở nhà; hỗ trợ từ xa khi bạn báo "không phân tích được"; laptop có thể ngủ hoặc đổi mạng | `[Assumed]` |
| 04 | Goals | (1) Người khác tự kết nối được. (2) Biết ngay lỗi ở đâu: Tailscale, backend tắt, sai địa chỉ. (3) Không để lộ API key của nhóm | `[Assumed]` |
| 05 | Job to Be Done | *"Khi bạn báo app không phân tích được, tôi muốn app tự nói rõ nguyên nhân, để bạn ấy tự sửa mà không cần gọi tôi."* | `[Assumed]` |
| 06 | Current Behaviors | Gửi địa chỉ Tailscale qua Zalo; hướng dẫn từng người; mở log backend để đoán lỗi | `[Assumed]` |
| 07 | Pain Points | (1) **Lỗi chung chung kiểu "network error"**. (2) **Gõ sai URL** (thiếu `http://`, sai cổng). (3) **VPN xung đột**: Cloudflare WARP chặn Tailscale. (4) **Backend nặng**: Saffron cần khoảng 3GB model, lần chạy đầu lâu | (1)(2) `[Assumed]`; (3) `[Observed]` ở Lab 2 (`HUONG_DAN_TAILSCALE.md`); (4) `[Inferred]` từ README của Saffron |
| 08 | Motivations | Kiểm soát hệ thống; ít bị làm phiền; an toàn cho key | `[Assumed]` |
| 09 | Constraints | Backend chạy trên laptop cá nhân (laptop ngủ là server tắt); Android chỉ chạy 1 VPN cùng lúc | `[Observed]` ở Lab 2 |
| 10 | Key Scenarios | **S4:** *Trigger:* cài app cho bạn mới. *Diễn biến:* đăng nhập Google → Connect server → nhập địa chỉ → *Test connection* → "Can't reach server" + gợi ý "Tailscale on?" → bật Tailscale → Retry → "Connected" → Continue. *Kết quả:* bạn tự dùng được | `[Assumed]` |
| 11 | Success Criteria | Người mới tự kết nối trong **≤ 1 phút** khi có địa chỉ; thông báo lỗi **phân biệt đúng 3 tình huống** (timeout, không tới được server, không phải backend của nhóm); **0** API key nằm trên điện thoại | Mục tiêu thiết kế |
| 12 | Evidence & Status | **Proto-Persona.** Sự cố hạ tầng `[Observed]` từ Lab 2; còn lại `[Assumed]`. Cần kiểm chứng: A7 | — |

---

## 5. Kịch bản cho Primary Persona

**S1** và **S2** của P01, gắn với **Flow A** và **Flow B** trong [user-flow.md](user-flow.md).

---

## 6. Persona → Nhu cầu → Quyết định UI → Cách kiểm chứng

> Cột "Quyết định UI" là **giả thuyết thiết kế**, không phải nhu cầu đã được kiểm chứng.

| Persona | Nhu cầu / vấn đề | Quyết định UI (màn hình) | Cách kiểm chứng |
|---|---|---|---|
| P01 | Biết bài dựa trên mảng nào | Thẻ **Topics** ngay dưới thẻ cảnh báo ở Overview; Topic map dạng cây thu gọn, mỗi node có số reference (Paper overview, Topic map) | Task test: nói ra 3 mảng chính trong ≤ 2 phút |
| P01 | Biết mảng nào đáng ngờ | Nhãn **"Weak"** có icon + chữ; bộ lọc **"Weak"**; dòng định nghĩa ngắn "Weak: ≥ 50% refs have issues" (Topic map) | Hỏi lại: người thử có giải thích đúng "Weak" không |
| P01 | Phân tích lâu, hay rời app | "Run in background" + push "Analysis done" mở thẳng Overview (Analysis in progress, Notifications) | Khoá màn trong lúc phân tích; người thử có quay lại đúng kết quả không |
| P01 | Không bị đánh lừa bởi chủ đề thiếu dữ liệu | Nhóm **"Unclassified"** kèm lý do, không lặng lẽ bỏ reference không đọc được (Topic map) | Hỏi lại: người thử có hiểu vì sao có reference không thuộc chủ đề nào |
| P02 | Cần bằng chứng, sợ kết luận oan | Dialog **"Likely fabricated"** có *Closest match* + "May be wrong — check the source."; bảng Cited / Actual (Reference detail) | Hỏi lại sau task: "Likely" nghĩa là gì |
| P02 | Mang kết quả đi viết nhận xét | **"Report"** → PDF tóm tắt Overview + chủ đề yếu → upload → "Copy link" / "Share" (Export sheet) | Đếm số chạm từ Overview tới link (mục tiêu ≤ 3) |
| P02 | Chữ lớn | Layout một cột, không cố định chiều cao chữ; nội dung ≥ 14 sp; cây chủ đề thụt lề có giới hạn | Test cỡ chữ 130% trên màn 360 dp |
| P03 | Biết nguyên nhân lỗi kết nối | *Test connection* trước khi Continue; 3 thông báo lỗi khác nhau + gợi ý Tailscale (Connect server) | Tạo 3 lỗi có chủ đích; người thử có nói đúng nguyên nhân không |
| P03 | Server tắt không làm hỏng app | Kết quả cũ đọc từ Firestore, xem được khi backend tắt; chỉ việc phân tích bài mới cần server (History, Overview) | Tắt backend rồi mở 1 bài cũ |
| Tất cả | Không phân biệt được màu | Trạng thái và nhãn "Weak" luôn có icon + chữ + màu | Xem màn hình ở chế độ grayscale |

---

## 7. Danh sách giả định và kế hoạch nghiên cứu

| ID | Giả định cần kiểm chứng | Persona | Cách kiểm chứng | Trạng thái |
|---|---|---|---|---|
| A1 | Sinh viên đọc bài lạ có dùng điện thoại để xem tổng quan trước khi đọc kỹ | P01 | Phỏng vấn: "Lần gần nhất bạn phải đọc một bài lạ, bạn bắt đầu thế nào, trên thiết bị gì?" | Chưa |
| A2 | Cây chủ đề giúp người đọc định hướng tốt hơn danh sách reference phẳng | P01 | Task test so sánh: tìm 3 mảng chính bằng cây vs bằng danh sách | Chưa |
| A3 | Ngưỡng "Weak" ≥ 50% reference có vấn đề là hợp lý (có thể chỉnh qua Remote Config) | P01, P02 | Cho người thử xem 3 ngưỡng, hỏi ngưỡng nào khớp trực giác | Chưa |
| A4 | Người dùng chấp nhận tên chủ đề là cụm từ khoá tiếng Anh do máy sinh | P01 | Hỏi lại sau task: tên chủ đề có dễ hiểu không | Chưa |
| A5 | Reviewer muốn nhận xét theo mảng nền tảng, không chỉ liệt kê reference sai | P02 | Phỏng vấn 1–2 giảng viên | Chưa |
| A6 | "Likely" và "Weak" không bị hiểu thành kết luận chắc chắn | P02 | Hỏi lại sau task test | Chưa |
| A7 | Phần lớn lỗi "không phân tích được" là do kết nối, Tailscale hoặc laptop ngủ | P03 | Ghi lại lỗi khi cài app cho 3–5 bạn | Một phần `[Observed]` (Lab 2) |

**Câu hỏi mở**
- Q1: Người dùng TalkBack có dùng được cây chủ đề (mở/đóng node, đọc thanh trạng thái) không?
- Q2: Người đọc tiếng Anh chưa tốt có hiểu tên chủ đề không? (quyết định có tách P04)
- Q3: Một bài có quá nhiều reference "Unclassified" thì cây chủ đề còn đáng tin không?

**Kế hoạch phỏng vấn / quan sát** (guideline gợi ý 6–12 người cho cả lớp)
- **Người tham gia:**
  - 3–4 sinh viên năm cuối hoặc học viên cao học từng trình bày bài ở journal club (P01; kiểm tra luôn A4, Q2).
  - 1–2 giảng viên hoặc reviewer (P02).
  - 1–2 bạn từng chạy server cho nhóm (P03).
- **Câu hỏi:** dùng 6 câu hỏi hành vi của guideline, áp vào nhiệm vụ "đọc hiểu một bài báo lạ":
  1. Lần gần nhất bạn phải đọc một bài báo lạ là khi nào?
  2. Bạn đã làm những bước nào?
  3. Bước nào mất thời gian hoặc dễ sai nhất?
  4. Khi không chắc bài dựa trên kiến thức gì, bạn làm gì?
  5. Bạn dùng công cụ, thiết bị nào? Vì sao?
  6. Dấu hiệu nào cho bạn biết mình đã nắm đủ nền tảng của bài?
- **Quy tắc ghi chép:** mã hoá người tham gia `I01, I02…`, **không** lưu họ tên. Có kết quả thì cập nhật cột "Nguồn" ở mục 4.

---

## 8. Tự chấm theo checklist persona (100 điểm)

| # | Tiêu chí | Tình trạng | Còn thiếu |
|---|---|---|---|
| 1 | Xác định phạm vi, nhiệm vụ cốt lõi, nhóm người dùng | Đã có (mục 1) | — |
| 2 | Có User/Stakeholder Map, xét người dễ bị bỏ sót | Đã có (mục 2) | — |
| 3 | Số persona hợp với phạm vi | Đã có: 3 persona + lý do (mục 3) | — |
| 4 | Persona khác nhau thật về mục tiêu, hành vi, rào cản | Đã có (Coverage Matrix) | — |
| 5 | Đủ 12 trường, ngắn gọn | Đã có (mục 4) | — |
| 6 | Nhu cầu là kết quả mong muốn, không phải tính năng trá hình | Đã có (Goals / JTBD không nêu tính năng) | — |
| 7 | Có bằng chứng hoặc giả định được gắn nhãn rõ | **Mới có nhãn**, phần lớn `[Assumed]` | **Phỏng vấn 6–12 người** |
| 8 | Có Affinity Board hoặc tóm tắt pattern | **Chưa** | Workshop, chụp bảng |
| 9 | Primary có kịch bản và tiêu chí thành công | Đã có (S1, S2, trường 11) | — |
| 10 | Ít nhất 1 quyết định UI gắn persona + cách kiểm chứng | Đã có (mục 6) | — |
