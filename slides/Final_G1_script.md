# Kịch bản thuyết trình Final Assignment – Realtron

Đi kèm bộ slide `Final_G1_slides.pdf`: 23 slide chính và 3 slide phụ lục. Nói khoảng 18–19 phút, trong đó demo chiếm khoảng 1/3.

Bộ slide đi theo khung *Software Project Presentation Guideline* của thầy, chia bốn phần:

| Phần | Slide | Trả lời câu hỏi | Thời lượng |
|---|---|---|---|
| P1 · Problem | 1–6 | Tại sao làm? Làm gì? | ≈ 3 phút 30 |
| P2 · Design | 7–15 | Xây thế nào? (toàn hệ thống) | ≈ 6 phút |
| P3 · Demo | 16–19 | Từng workflow chạy ra sao? | ≈ 6 phút 30 |
| P4 · Proof | 20–23 | Chứng minh được gì? | ≈ 2 phút 30 |

Mỗi slide có 3 phần:

- **Câu chốt:** câu quan trọng nhất. Nếu quên hết, chỉ cần nói câu này.
- **Nói:** câu ngắn, nói tự nhiên, không cần thuộc từng chữ. Chữ trong `[ngoặc vuông]` là hành động: chỉ vào đâu, bấm gì.
- **Thầy hỏi:** câu trả lời ngắn cho câu thầy hay hỏi ở slide đó.

Mẹo để nói trơn tru:

- **Tiêu đề mỗi slide là câu kết luận.** Mở đầu slide bằng chính câu tiêu đề, rồi mới giải thích.
- **Phần Design nói về toàn hệ thống**, không đi sâu từng workflow. Chi tiết từng workflow để dành cho phần Demo.
- **Demo theo câu chuyện**, không theo menu: kết quả của WF-01 là đầu vào của WF-02 và WF-03, cùng một bài báo.
- Mã `BR-xx` là business rule, định nghĩa ở slide 8. Nhắc mã khi đi qua điểm rẽ nhánh, để thầy thấy rule nối từ thiết kế tới demo và test.
- Cuối mỗi slide có một câu chuyển. Nói câu đó rồi mới bấm sang slide sau.
- Thiếu thời gian: slide 12 (Sequence) chỉ nói câu chốt; slide 13 và 14 gộp thành một phút.

---

# P1 · PROBLEM

## Slide 1 · Overview (30 giây)

**Câu chốt:** Realtron giúp người đọc hiểu nhanh một bài báo qua danh sách tham khảo: bài dựa trên mảng nào, mảng nào đáng ngờ.

**Nói:**

> Em chào thầy. Nhóm em là PRM393-Project-G1, gồm [tên các bạn].
>
> Sản phẩm của nhóm là Realtron, một app Android. Người dùng là sinh viên, học viên cao học và người phản biện phải đọc bài báo của người khác.
>
> `[chỉ ba ô]` Giá trị của app: nhìn vào là thấy bài dựa trên những mảng kiến thức nào, và reference nào đáng ngờ. Nền tảng là app Android, Firebase, và backend phân tích do nhóm tự chạy.
>
> `[chỉ ảnh điện thoại]` Đây là app đang chạy thật, ở màn Paper Overview của bài Attention Is All You Need.
>
> *(Chuyển)* Em xin bắt đầu từ bối cảnh: hiện nay người đọc làm việc này thế nào.

---

## Slide 2 · Context (30 giây)

**Câu chốt:** Hiện nay người đọc bài báo lạ phải tự lần từng reference bằng tay.

**Nói:**

> Bối cảnh là môi trường học thuật: journal club, làm khoá luận, phản biện bài cho hội thảo. Người liên quan là người đọc và người phản biện.
>
> Công cụ hiện tại là trình đọc PDF, Google Scholar, tra DOI trên trình duyệt. Có bạn hỏi ChatGPT "bài này dựa trên gì", nhưng câu trả lời không kiểm chứng được.
>
> `[chỉ 4 bước]` Quy trình hiện tại có bốn bước: nhận link bài, đọc abstract và related work, mở vài reference có tên quen, rồi tra tay những reference trông lạ.
>
> `[chỉ 40–60]` Một bài có 40 đến 60 reference, nên phần lớn không bao giờ được kiểm tra.
>
> *(Chuyển)* Cách làm này gây ra ba điểm nghẽn.

---

## Slide 3 · Problem (40 giây)

**Câu chốt:** Ba điểm nghẽn dẫn tới đọc lan man và tin nhầm nguồn bịa.

**Nói:**

> `[đọc bảng theo hàng]` Một: người đọc không thấy bài dựa trên mảng kiến thức nào, vì related work viết thành đoạn văn. Hậu quả là đọc lan man, thiếu nền tảng khi trình bày.
>
> Hai: không biết reference nào có thật, vì tra tay từng cái quá lâu nên bỏ qua. Hậu quả là trình bày hoặc nhận xét dựa trên nguồn bịa.
>
> Ba: người phản biện nhận xét chung chung, vì không biết lỗi tập trung ở mảng nào.
>
> `[chỉ ô minh chứng]` Vấn đề này có thật. Nghiên cứu Phantom References cho thấy khoảng 1 trên 20 bài được nhận ở NeurIPS và USENIX Security 2025 có ít nhất 2 reference nhiều khả năng là bịa. Tức là bài đã qua peer review vẫn có thể dựa trên nguồn không có thật.
>
> *(Chuyển)* Với mỗi điểm nghẽn, nhóm có một workflow trả lời trực tiếp.

**Thầy hỏi:**

- *Nhóm có khảo sát người dùng không?* Chưa. Persona là proto-persona; con số về vấn đề lấy từ nghiên cứu Phantom References. Thử nghiệm với người dùng nằm ở slide 22.

---

## Slide 4 · Proposed Solution (40 giây)

**Câu chốt:** Mỗi pain point có một workflow trả lời trực tiếp.

**Nói:**

> Giải pháp tổng thể: người dùng nhập arXiv ID. Backend kiểm tra từng reference và dựng cây chủ đề. App chỉ ra chủ đề yếu và cho xuất báo cáo.
>
> `[đọc bảng theo hàng]` Pain point 1 được trả lời bằng cây chủ đề: kỳ vọng nói ra được 3 mảng chính trong 2 phút. Đó là WF-02.
>
> Pain point 2 được trả lời bằng việc kiểm tra từng reference, gán 5 trạng thái, có bằng chứng. Đó là WF-01.
>
> Pain point 3 được trả lời bằng chủ đề yếu cộng báo cáo PDF có link. Đó là WF-03.
>
> `[chỉ hai ô dưới]` Phạm vi MVP là ba workflow này. Ngoài phạm vi: tóm tắt nội dung bài, quản lý thư viện kiểu Zotero, upload PDF bài báo, và iOS. Lý do: chúng không trả lời câu hỏi "bài dựa trên gì".
>
> `[chỉ dải xanh]` Mục tiêu đo được: ít nhất 4 trên 5 người tự làm xong trong 2 phút kể từ khi Overview hiện ra.
>
> *(Chuyển)* Những ai dùng hệ thống này?

---

## Slide 5 · Main Actors (30 giây)

**Câu chốt:** Ba nhóm người dùng và bốn hệ thống bên ngoài.

**Nói:**

> Ba actor là người, tương ứng ba persona.
>
> - Người đọc, Linh: phân tích bài, xem chủ đề yếu, xuất báo cáo.
> - Người phản biện, TS. Hùng: dùng cùng chức năng, nhưng trọng tâm là bằng chứng của từng reference và báo cáo PDF.
> - Người vận hành, Khoa: chạy backend trên laptop, giữ các khoá bí mật.
>
> Bốn hệ thống ngoài: Firebase để xác thực, gửi push, đo lường và cấu hình; arXiv và cơ sở dữ liệu học thuật là nguồn đối chiếu; LLM API là tuỳ chọn; Cloudinary lưu file PDF.
>
> `[chỉ dòng dưới]` Quyền hạn thật do Firestore rules quyết định: mỗi người chỉ đọc, ghi dữ liệu của mình; kết quả phân tích chỉ backend được ghi.
>
> *(Chuyển)* Các actor này làm việc qua ba workflow lõi.

---

## Slide 6 · Main Features (45 giây)

**Câu chốt:** Tính năng gom thành ba workflow lõi, cũng là ba workflow sẽ demo.

**Nói:**

> `[đi qua từng cột]` WF-01, phân tích tham khảo của một bài báo. Trigger: người đọc nhận một bài lạ cần trình bày. Kết quả: Analysis chuyển sang DONE, có push "Analysis done".
>
> WF-02, xác định chủ đề yếu. Trigger: cần biết mảng nào của bài đáng ngờ. Kết quả: thấy chủ đề yếu và reference có vấn đề, kèm bằng chứng.
>
> WF-03, xuất báo cáo kiểm tra tham khảo. Trigger: người phản biện cần gửi nhận xét. Kết quả: file PDF và link chia sẻ.
>
> `[chỉ dòng dưới]` Đăng nhập, kết nối server, thông báo và Profile không phải workflow. Chúng là điều kiện đầu hoặc chức năng hỗ trợ, vì không tự tạo ra kết quả nghiệp vụ.
>
> *(Chuyển)* Sang phần Design. Em trình bày toàn hệ thống trước, chi tiết từng workflow để phần demo.

**Thầy hỏi:**

- *Sao đăng nhập không phải workflow?* Đăng nhập không có kết quả nghiệp vụ và không đổi trạng thái của đối tượng nghiệp vụ nào. Nó là điều kiện đầu của WF-01.
- *WF-02 chỉ là xem, có phải workflow không?* Có. Nó có trigger, có kết quả cho người dùng (chủ đề yếu kèm bằng chứng), có quyết định theo rule BR-04, có nhánh ngoại lệ, và nói được bằng ngôn ngữ nghiệp vụ.

---

# P2 · DESIGN

## Slide 7 · Business Flow (1 phút)

**Câu chốt:** Một sơ đồ cho cả hệ thống: từ arXiv ID tới báo cáo, qua bốn lane người dùng, app, backend, dịch vụ ngoài.

**Nói:**

> Đây là sơ đồ activity có swimlane cho toàn hệ thống. Bốn lane: người dùng, app, backend và dịch vụ ngoài.
>
> `[chỉ theo mũi tên, từ trái sang]` WF-01: người dùng gửi arXiv ID. App kiểm tra bài đã có kết quả chưa, đây là BR-02. Có rồi thì mở Overview ngay. Chưa có thì backend kiểm tra reference và dựng cây chủ đề. Xong thì FCM đẩy push, app mở Overview.
>
> `[chỉ chữ đỏ]` Hai nhánh ngoại lệ: ID sai thì báo lỗi theo BR-01; phân tích lỗi thì Analysis sang FAILED.
>
> WF-02: app đánh dấu chủ đề yếu theo BR-04, người dùng xem chủ đề yếu và bằng chứng.
>
> WF-03: app tạo PDF. Nếu cờ upload bật, theo BR-06, thì backend ký cho đúng thư mục của người dùng, Cloudinary lưu file, và người dùng nhận link. Cờ tắt thì PDF chỉ lưu trên máy.
>
> *(Chuyển)* Đối tượng đi qua cả luồng này là Analysis. Slide sau là vòng đời của nó.

---

## Slide 8 · State Machine (40 giây)

**Câu chốt:** Analysis có 5 trạng thái, và chỉ backend được đổi trạng thái.

**Nói:**

> `[đi theo số trên mũi tên]` Một: người dùng submit. Guard là ID hợp lệ, BR-01, và bài chưa có kết quả, BR-02. Backend tạo job ở QUEUED.
>
> Hai: job bắt đầu, chuyển PROCESSING và ghi tiến độ. Ba: xong thì sang DONE và gửi push.
>
> Bốn: trong lúc chạy, chỉ người khởi tạo mới bấm Stop được, đó là BR-03. Năm: một bước lỗi, hoặc backend khởi động lại giữa chừng, thì sang FAILED. Sáu: từ FAILED hoặc CANCELLED, bấm Analyze lại sẽ tạo job mới.
>
> `[chỉ ô đỏ]` Ba chuyển bị cấm: bài DONE không chạy lại; app không tự ghi trạng thái vì Firestore rules chặn; người khác bấm Stop thì backend trả 403.
>
> `[chỉ cột phải]` Đây là sáu business rule dùng trong toàn bộ thiết kế, demo và test.
>
> *(Chuyển)* Hệ thống chứa đối tượng này được tổ chức như sau.

**Thầy hỏi:**

- *Backend khởi động lại thì sao?* Lúc khởi động, backend chuyển mọi job đang QUEUED hoặc PROCESSING sang FAILED, nếu không app sẽ chờ mãi một job không còn tồn tại (`fail_interrupted` trong `store.py`).

---

## Slide 9 · System Architecture (50 giây)

**Câu chốt:** Kết quả nằm trên Firestore; app chỉ gọi backend để ra lệnh.

**Nói:**

> Đây là sơ đồ C4 mức 1, System Context. Hộp xanh là hệ thống nhóm xây: app Android và backend Orchestrator, cùng dữ liệu kết quả trên Cloud Firestore.
>
> Bên trái là người dùng và người vận hành. Bên trên là Firebase. Bên dưới là Cloudinary. Bên phải là ba hệ thống backend gọi khi phân tích: arXiv, cơ sở dữ liệu học thuật, và LLM API tuỳ chọn.
>
> `[chỉ dải Triển khai]` App cài bằng APK. Backend FastAPI chạy trên laptop, điện thoại gọi qua Tailscale. Firebase dùng gói Spark.
>
> `[chỉ dải Quyết định]` Quyết định kiến trúc chính: backend ghi kết quả lên Firestore, app chỉ gọi backend để ra lệnh. Nhờ vậy màn tiến độ chạy realtime, có cache offline, và bài cũ vẫn xem được khi laptop tắt. Đánh đổi là backend phải ghi qua Admin SDK.
>
> *(Chuyển)* Các khối này dùng những công nghệ nào?

---

## Slide 10 · Technology Stack (40 giây)

**Câu chốt:** Mỗi công nghệ gắn với một vai trò cụ thể.

**Nói:**

> `[đi nhanh theo bảng]` Mobile: Flutter, Provider cho MVVM, go_router cho điều hướng và deep link từ push. Backend: FastAPI. Phân tích: RefChecker kiểm tra reference, Saffron dựng cây chủ đề. Cloud: Firebase Auth, Firestore, Cloud Messaging; giám sát bằng Analytics, Crashlytics, Remote Config. Kiểm thử: flutter_test, pytest và Google ARTEMIS.
>
> `[chỉ hai ô dưới]` Hai lựa chọn quan trọng. Một: dùng Firestore thay vì REST để trả kết quả, như vừa nói ở slide trước. Hai: dùng Cloudinary thay Cloud Storage, vì gói Spark không có bucket. Upload được ký ở backend nên khoá bí mật không nằm trong APK.
>
> *(Chuyển)* Phía người dùng nhìn thấy gì?

---

## Slide 11 · UI/UX Design (40 giây)

**Câu chốt:** Giao diện đi từ mockup AI, qua bốn vòng chỉnh, tới Figma cuối và app thật.

**Nói:**

> `[chỉ hàng trên, trái sang phải]` Mockup ban đầu sinh bằng Google Stitch. Nhóm chỉnh bốn vòng, mỗi vòng một mục tiêu: trung thực, chữ tối giản, accessibility, đủ trạng thái lỗi. Bản cuối dựng lại trên Figma.
>
> `[chỉ ô Sau góp ý]` Một phản hồi đã đổi thiết kế: thầy góp ý giao diện quá nhiều chữ. Nhóm rút nút còn 1–2 từ, tiêu đề tối đa 3 từ, bỏ đoạn giới thiệu.
>
> `[chỉ hàng dưới]` Đây là app thật dựng theo Figma: 12 màn, 3 tab Analyze, History, Profile. Màn nào có tải dữ liệu đều có đủ bốn trạng thái: rỗng, đang tải, lỗi, thành công.
>
> *(Chuyển)* Bên trong app, một lần bấm Analyze đi qua những thành phần nào?

---

## Slide 12 · Sequence Diagram (35 giây)

**Câu chốt:** Bấm Analyze thì app đọc Firestore trước, chỉ gọi backend khi bài chưa có kết quả.

**Nói:**

> `[đọc theo số]` Người đọc bấm Analyze. Màn hình gọi `submit()` của AnalyzeViewModel. ViewModel hỏi AnalysisRepository xem bài đã có trên Firestore chưa. Đây là chỗ áp BR-02.
>
> `[chỉ khung alt]` Nếu chưa có: ViewModel gọi ApiClient, ApiClient gửi POST /api/analyses kèm Firebase ID token. Backend ghi trạng thái và kết quả lên Firestore. App nghe `watchAnalysis()` nên tiến độ hiện realtime.
>
> `[chỉ dải dưới]` Hai nhánh khác: bài đã DONE thì mở Overview ngay; mất mạng thì báo "Can't reach server" và ghi lỗi lên Crashlytics.
>
> *(Chuyển)* Các lớp trong sơ đồ này được thiết kế thế nào?

---

## Slide 13 · Class Design (30 giây)

**Câu chốt:** Business rule nằm trong domain; ViewModel chỉ phụ thuộc interface.

**Nói:**

> Hàng trên là ViewModel, mỗi màn một cái. ViewModel chỉ biết interface AnalysisRepository và ApiClient, được inject qua Provider. Bản cài đặt thật là FirestoreAnalysisRepository và HttpApiClient. Nhờ vậy test truyền được service giả.
>
> `[chỉ hộp màu nâu]` Quy tắc chủ đề yếu, BR-04, nằm trong WeakTopicRule, ở tầng domain, không nằm trong UI. TopicTree gọi rule này, nên Overview, Topics, Topic và báo cáo PDF luôn ra cùng một kết quả.
>
> *(Chuyển)* Dữ liệu của các lớp này nằm ở đâu?

---

## Slide 14 · Database Design (45 giây)

**Câu chốt:** Kết quả phân tích dùng chung cho mọi người; dữ liệu cá nhân tách theo uid.

**Nói:**

> `[chỉ sơ đồ trái]` Mô hình khái niệm: một User có nhiều mục thư viện, báo cáo và thông báo, mỗi mục trỏ tới một Analysis. Một Analysis có nhiều Reference và nhiều Topic. Topic và Reference quan hệ nhiều-nhiều.
>
> `[chỉ bảng phải]` Trên Firestore: dữ liệu cá nhân nằm dưới `users/{uid}`. Kết quả phân tích nằm ở `analyses` và dùng chung, vì một bài chỉ cần phân tích một lần.
>
> `[chỉ ô ràng buộc]` Ràng buộc nằm ở Firestore rules: mỗi người chỉ đọc, ghi nhánh của mình; trường role không tự đổi được; thông báo thì app chỉ được đổi trường `read`; còn `analyses` thì write luôn là false, chỉ backend ghi qua Admin SDK.
>
> *(Chuyển)* Slide cuối phần Design kiểm tra các bản thiết kế này có khớp nhau không.

---

## Slide 15 · Traceability (30 giây)

**Câu chốt:** Mỗi workflow nối được tới màn hình, class, dữ liệu, rule và test.

**Nói:**

> `[đọc hàng WF-01 từ trái sang phải]` Ví dụ WF-01: đi qua màn Analyze, Analyzing, Overview; class AnalyzeViewModel với ApiClient và AnalysisRepository; dữ liệu `analyses` và `library`; rule BR-01 đến BR-03; kiểm bằng tám ca E2E và unit test của ViewModel.
>
> WF-02 và WF-03 cũng nối được như vậy. Không có màn, class hay bảng nào chỉ để cho đẹp.
>
> `[chỉ dải dưới]` Chuỗi truy vết đi từ Problem tới Achievement.
>
> *(Chuyển)* Sang phần Demo. Ba workflow sẽ nối thành một câu chuyện.

---

# P3 · DEMO

## Slide 16 · Demo Plan (30 giây)

**Câu chốt:** Ba workflow nối nhau trên cùng một bài báo.

**Nói:**

> Em sẽ demo trên cùng một bài: 1706.03762, Attention Is All You Need.
>
> `[chỉ ba cột]` WF-01: người đọc phân tích bài, kết quả là Analysis DONE và có push. WF-02: từ chính kết quả đó, đi tới chủ đề yếu và mở một reference có vấn đề. WF-03: người phản biện xuất báo cáo PDF của bài này và lấy link.
>
> Kết quả của workflow trước là đầu vào của workflow sau.
>
> *(Chuyển)* Bắt đầu với WF-01. `[cầm điện thoại, bật chiếu màn hình]`

---

## Slide 17 · Demo WF-01 · Phân tích tham khảo của một bài báo (≈ 2 phút)

**Câu chốt:** Nhập một arXiv ID, Analysis đi từ QUEUED tới DONE, và có push khi xong.

**Nói và làm:**

> Scenario: em là Linh, vừa nhận một bài lạ phải trình bày tuần sau. Điều kiện đầu: đã đăng nhập Google và đã kết nối server.
>
> `[nhập abc123]` Thử nhánh ngoại lệ trước: ID sai thì app báo "Not a valid arXiv ID" và nút Analyze tắt. Đây là BR-01.
>
> `[xoá, nhập 1706.03762, bấm Analyze]` ID đúng. App hỏi Firestore trước, theo BR-02. Bài này đã có kết quả nên mở Overview ngay, không chạy lại.
>
> `[nếu có bài mới để chạy: nhập ID, bấm Analyze, chỉ stepper]` Với bài chưa có kết quả, màn Analyzing hiện stepper năm bước, chạy theo dữ liệu backend ghi lên Firestore. Analysis đi từ QUEUED sang PROCESSING. Người dùng có thể rời app.
>
> `[mở khay thông báo, chạm push "Analysis done"]` Khi xong, backend gửi push. Chạm vào là mở đúng Paper Overview.
>
> `[chỉ ô Evidence]` Minh chứng: `analyses/1706.03762` ở DONE với 40 reference, push trên khay hệ thống. Các ca test tương ứng là TC-03, 04, 08, 10, 15, 16.
>
> *(Chuyển)* Overview đã có. Giờ tìm xem mảng nào của bài đáng ngờ.

---

## Slide 18 · Demo WF-02 · Xác định chủ đề yếu của bài báo (≈ 2 phút)

**Câu chốt:** Chủ đề là Weak khi Hallucinated cộng Error chiếm từ 50% và có ít nhất 3 reference.

**Nói và làm:**

> Scenario: Linh cần biết mảng nào của bài đáng ngờ. Điều kiện đầu: Analysis ở DONE.
>
> `[ở Overview, bấm Explore]` Đây là cây chủ đề, dựng từ văn bản của các reference.
>
> `[bật chip Weak]` App lọc theo BR-04. `[chỉ ô ví dụ]` Ví dụ chủ đề có 5 reference, 2 Hallucinated và 1 Error, tức 3 trên 5, bằng 60%, vượt ngưỡng 50%, nên là Weak. Warning không tính.
>
> `[mở một chủ đề]` Trong chủ đề có phân bố trạng thái, chủ đề con và các reference.
>
> `[mở một reference Error hoặc Hallucinated]` Bảng Cited và Actual tô đúng ô bị lệch. Nếu là Hallucinated thì có dialog "Likely fabricated" kèm bài gần nhất tìm được.
>
> Nhánh ngoại lệ: không có chủ đề yếu thì app hiện "No weak topics"; lỗi tải thì "Couldn't load" kèm Retry.
>
> `[nếu đã chuẩn bị: mở Remote Config trên Console, hạ weak_topic_threshold, Publish]` Ngưỡng 50% nằm trên Remote Config. Đổi trên Console thì app nhận ngay, không cần build lại.
>
> Minh chứng: các sự kiện `filter_weak_topics`, `view_topic`, `view_reference` trên DebugView, và ca test TC-06, 07, 18.
>
> *(Chuyển)* Người phản biện muốn mang kết quả này đi để viết nhận xét.

---

## Slide 19 · Demo WF-03 · Xuất báo cáo kiểm tra tham khảo (≈ 2 phút)

**Câu chốt:** Một lần bấm Report cho ra PDF trên máy; bật upload thì có thêm link chia sẻ.

**Nói và làm:**

> Scenario: em là TS. Hùng, cần gửi nhận xét kèm bằng chứng. Điều kiện đầu: Analysis ở DONE.
>
> `[mở tab History, chọn bài]` Bài cũ mở được cả khi backend tắt, vì kết quả đọc từ Firestore.
>
> `[bấm Report]` App tạo PDF từ đúng kết quả đang xem và lưu trên máy: Creating rồi Saved.
>
> `[nếu enable_cloud_upload đang bật]` Cờ upload bật, theo BR-06, nên app xin backend chữ ký cho đúng thư mục `reports/{uid}`, rồi upload lên Cloudinary: Uploading rồi Uploaded. `[bấm Copy link, mở link]` Đây là file PDF mở từ link.
>
> Nhánh ngoại lệ: backend tắt thì app báo "Export failed", ghi lỗi lên Crashlytics, nhưng PDF vẫn còn trên máy. Nếu ai sửa đường dẫn sang uid khác, chữ ký không khớp và Cloudinary từ chối.
>
> Minh chứng: file `realtron_1706.03762.pdf` 8.86 KB trên Cloudinary và bản ghi `users/{uid}/reports`. Ca test TC-09, 17, 19.
>
> *(Chuyển)* Sang phần cuối: nhóm chứng minh hệ thống chạy đúng bằng cách nào.

---

# P4 · PROOF

## Slide 20 · Testing & Verification (50 giây)

**Câu chốt:** Hệ thống được kiểm ở bốn mức: unit, backend, E2E và bằng chứng trên Console.

**Nói:**

> `[chỉ ba con số]` 83 trên 83 ca test backend pass. 141 test Flutter cho ViewModel, model và design system. 19 ca E2E bằng Google ARTEMIS.
>
> `[đi qua bảng]` Unit và widget test của Flutter dùng service giả: [đọc kết quả flutter test]. Test backend bằng pytest phủ API, job, chữ ký upload và việc sửa file `.bbl`: 83 trên 83 pass. E2E bằng ARTEMIS chạy trên điện thoại thật với Firebase và backend thật, mỗi ca ba lần: [đọc pass rate]. Mỗi dịch vụ Firebase có ảnh Console làm bằng chứng. AI code review có 10 finding, 8 chấp nhận, 2 sửa theo cách khác, đều có commit.
>
> `[chỉ dải dưới]` Mỗi business rule có test riêng: BR-01 là TC-04, BR-02 là TC-03, BR-04 là TC-06 và test TopicTree, BR-06 là test chữ ký upload ở backend.
>
> *(Chuyển)* Đối chiếu lại với mục tiêu ở đầu bài.

---

## Slide 21 · Achievements (40 giây)

**Câu chốt:** Ba mục tiêu có minh chứng; mục tiêu đo bằng người dùng thì chưa đo.

**Nói:**

> `[đọc theo hàng]` Mục tiêu biết reference nào đáng ngờ: với bài 1706.03762, 40 reference được phân loại thành 24 Verified, 10 Warning, 2 Error, 4 Unverified.
>
> Mục tiêu biết bài dựa trên mảng nào: bài này có 40 chủ đề, sự kiện xem chủ đề có trên DebugView.
>
> Mục tiêu nhận xét có bằng chứng: file PDF 8.86 KB trên Cloudinary, có bản ghi trên Firestore.
>
> `[chỉ ô Chưa đạt]` Em xin nói thẳng: mục tiêu 4 trên 5 người tự làm xong trong 2 phút chưa được đo, vì nhóm chưa thử nghiệm với người dùng thật.
>
> *(Chuyển)* Đó là một trong bốn giới hạn hiện tại.

---

## Slide 22 · Limitations & Next Steps (25 giây)

**Câu chốt:** Mỗi giới hạn có tác động rõ và một bước tiếp theo cụ thể.

**Nói:**

> Hai giới hạn ưu tiên cao. Một: backend chạy trên laptop, mỗi lần một job; laptop tắt thì không phân tích được bài mới. Bước tiếp theo là đưa backend lên máy chủ luôn bật. Hai: chưa thử nghiệm với người dùng thật; bước tiếp theo là task test với 5 người và đo thời gian.
>
> Trung bình: chất lượng cây chủ đề chưa được đánh giá, tên chủ đề là cụm từ tiếng Anh. Nhóm sẽ đánh giá trên bộ bài mẫu và dùng Gemini sinh tên dễ hiểu.
>
> Thấp: gói Spark không có Cloud Storage, nên upload đi qua Cloudinary.
>
> *(Chuyển)* Em xin kết lại bằng ba thông điệp.

---

## Slide 23 · Conclusion (30 giây)

**Câu chốt:** Vấn đề được giải, sản phẩm chạy thật, kết quả có kiểm chứng.

**Nói:**

> Một: từ 40 đến 60 reference rời rạc, người đọc có cây chủ đề, chủ đề yếu và bằng chứng cho từng reference.
>
> Hai: ba workflow vừa demo chạy trên app thật, với Firebase và backend thật.
>
> Ba: 83 trên 83 test backend pass, ảnh Console cho từng dịch vụ Firebase, 10 finding review đã xử lý.
>
> `[chỉ dòng link]` Link repo, Figma và video demo ở đây.
>
> Em xin cảm ơn thầy và các bạn. Nhóm em sẵn sàng nhận câu hỏi. `[để nguyên slide này trong lúc hỏi đáp]`

---

# PHỤ LỤC (không chiếu, mở khi được hỏi)

| Slide | Mở khi thầy hỏi | Ai trả lời |
|---|---|---|
| A1 · Persona | "Người dùng chính là ai, họ cần gì?" | [tên] |
| A2 · Đặc tả workflow | "Workflow này có những thành phần nào, precondition, postcondition là gì?" | [tên] |
| A3 · Application design | "App chia tầng thế nào, sao test được bằng service giả?" | [tên] |

---

## Chuẩn bị trước buổi

**Điền vào slide trước khi nộp:**

- [ ] Slide 1: họ tên, MSSV từng bạn và tên giảng viên hướng dẫn.
- [ ] Slide 20: kết quả `flutter test` (chạy trên máy có Flutter SDK) và pass rate ARTEMIS sau khi chạy 3 lần mỗi ca. Nếu chưa chạy được, sửa ô đó thành trạng thái thật thay vì để trống.
- [ ] Slide 23: link video demo.

**Thiết bị và dữ liệu:**

- [ ] Điện thoại thật cài APK mới nhất, đăng nhập tài khoản Google demo. Máy Xiaomi/Redmi: bật Autostart cho Realtron, không Force stop.
- [ ] Laptop chạy backend, Tailscale bật trên cả hai máy, màn Connect kết nối được.
- [ ] Bài `1706.03762` đã phân tích xong (nạp sẵn: `.venv/Scripts/python -m orchestrator.seed 1706.03762` trong `backend/`).
- [ ] **WF-02 cần một chủ đề yếu để demo.** Ảnh chụp hiện tại của bài 1706.03762 là "40 topics · 0 weak" ở ngưỡng 0.5. Trước buổi, chọn một trong hai cách và thử trước:
  - phân tích sẵn một bài có chủ đề yếu, rồi demo WF-02 trên bài đó; hoặc
  - hạ `weak_topic_threshold` trên Remote Config (ví dụ 0.3) và kiểm tra bài 1706.03762 có hiện chủ đề yếu không. Nhớ trả lại 0.5 sau buổi.
- [ ] Một bài chưa phân tích, nếu muốn demo stepper Analyzing chạy thật (mất khoảng 2–10 phút, nên bấm từ đầu buổi).
- [ ] Gửi lại push thật của một bài đã xong: `.venv/Scripts/python -m orchestrator.push 1706.03762` trong `backend/`.
- [ ] Remote Config: đặt `enable_cloud_upload = true` nếu demo upload; ghi lại giá trị gốc để trả lại sau buổi.
- [ ] Debug Analytics: `adb shell setprop debug.firebase.analytics.app vn.fpt.prm393.realtron`, rồi mở lại app.
- [ ] Mở sẵn tab Console: Firestore `analyses/1706.03762`, Analytics › DebugView, Remote Config, Crashlytics; tab Media Library của Cloudinary.
- [ ] Phân công: một bạn thao tác điện thoại, một bạn thuyết minh. Có video demo dự phòng nếu mạng hoặc thiết bị lỗi.

---

## Câu hỏi khó: trả lời thật

| Thầy hỏi | Trả lời |
|---|---|
| Đề Assignment yêu cầu web admin, tính năng Gemini, cross-role flow và test Security Rules. Đâu? | [Trả lời theo tình trạng thật lúc trình bày.] Bộ slide này trình bày phần app Android và backend đã hoàn thành. Nếu các phần đó chưa xong, nói rõ phần nào chưa có và kế hoạch, không trình bày như đã làm. |
| Sao chưa có pass rate ARTEMIS? | [Nếu chưa chạy:] Suite đã viết đủ 19 ca nhưng chưa chạy, vì cần máy thật, backend, tài khoản test và API key cùng lúc. |
| Persona lấy từ đâu? | Proto-persona: viết từ vấn đề có nguồn (Phantom References) và giả định của nhóm. Nhóm chưa phỏng vấn người dùng thật; đây là giới hạn ở slide 22. |
| BR-xx có trong tài liệu không? | Các rule có thật trong code và rules (`main.py`, `weak_topic_rule.dart`, `firestore.rules`, `uploads.py`); mã BR-01 đến BR-06 là cách nhóm đánh số để trình bày và truy vết. |
| Sao không vẽ C4 mức 2? | Thầy yêu cầu vẽ mức 1 (System Context). Cấu trúc bên trong app nằm ở slide Class Design và phụ lục A3. |
| Sao không dùng Cloud Storage như đề? | Gói Spark không có bucket. Nhóm dùng Cloudinary, upload ký ở backend. Code `FirebaseStorageService` vẫn giữ, đổi lại chỉ cần sửa một chỗ inject. |
| Một số ảnh chụp ở đâu? | Một số ảnh FCM, Remote Config chụp trên emulator BlueStacks; hôm nay demo trên điện thoại thật. |
| Test Flutter có chạy không? | [Đọc kết quả `flutter test` đã điền ở slide 20.] |
