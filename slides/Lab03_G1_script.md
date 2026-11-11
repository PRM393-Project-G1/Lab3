# Kịch bản thuyết trình Lab 3 – Realtron

Đi kèm bộ slide `Lab03_G1_slides.pdf` (33 slide). Nói khoảng 24 phút, chưa tính demo.

Từ slide 6, mỗi công nghệ đi theo ba phần: **What–Why** (là gì, vì sao Realtron cần) → **How** (chạy thế nào) → **Where–When** (nằm ở đâu trong code, chạy lúc nào, bằng chứng). Ba nhãn ở góc trên bên phải slide cho biết đang ở phần nào.

Mỗi slide có 3 phần:

- **Câu chốt:** câu quan trọng nhất. Nếu quên hết, chỉ cần nói câu này.
- **Nói:** câu ngắn, nói tự nhiên, không cần thuộc từng chữ. Chữ trong `[ngoặc vuông]` là hành động: chỉ vào đâu, bấm gì.
- **Thầy hỏi:** câu trả lời ngắn. Tên file trong ngoặc là chỗ mở code nếu thầy muốn xem.

Mẹo để nói trơn tru:

- Mỗi công nghệ nói theo đúng 3 phần: **là gì, vì sao cần → chạy thế nào → nằm ở đâu, chạy lúc nào**. Slide What–Why nói ngắn, dành thời gian cho How và Where–When.
- Nếu thầy giới hạn thời gian, ở slide What–Why chỉ nói **Câu chốt**.
- Gặp tên hàm khó đọc thì chỉ tay vào slide, không cần đọc to.
- Cuối mỗi slide có một câu chuyển. Nói câu đó rồi mới bấm sang slide sau.

---

## Slide 1 · Realtron (40 giây)

**Câu chốt:** Realtron giúp người đọc hiểu nhanh một bài báo thông qua danh sách tài liệu tham khảo của nó.

**Nói:**

> Em chào thầy. Nhóm em là PRM393-Project-G1, gồm [tên các bạn].
>
> Sản phẩm của nhóm là Realtron, một app Android viết bằng Flutter.
>
> Cách dùng rất đơn giản. Người dùng nhập mã arXiv của một bài báo. Backend dùng RefChecker để kiểm tra từng tài liệu tham khảo, tức là reference, trong bài. Sau đó dùng Saffron để gom các reference thành cây chủ đề.
>
> `[chỉ 5 nhãn]` Mỗi reference được gắn một trong năm nhãn:
>
> - Verified: khớp với nguồn.
> - Warning: lệch nhỏ.
> - Error: sai thông tin chính.
> - Hallucinated: nhiều khả năng là bịa.
> - Unverified: chưa kiểm được.
>
> Ở Lab 3, app dùng sáu dịch vụ Firebase, kiểm thử bằng Google ARTEMIS và rà soát mã bằng AI. `[chỉ ảnh điện thoại]` Đây là app thật, đang ở màn Paper Overview.
>
> *(Chuyển)* Trước hết, em xin nói app này giải quyết vấn đề gì.

---

## Slide 2 · Đề tài và persona (1 phút)

**Câu chốt:** Người dùng chính là Linh, đọc bài trên điện thoại. Mục tiêu: ít nhất 4/5 người tự làm xong trong 2 phút.

**Nói:**

> Vấn đề là thế này. Khi đọc một bài báo lạ, người đọc phải lướt qua 40 đến 60 reference. Họ không biết nên đọc cái nào trước. Họ cũng không biết cái nào là có thật.
>
> Đây là vấn đề có thật. Nghiên cứu Phantom References cho thấy: khoảng 1 trên 20 bài được nhận ở NeurIPS và USENIX Security 2025 có ít nhất 2 reference nhiều khả năng là bịa.
>
> Người dùng chính của nhóm là Linh, sinh viên năm cuối hoặc học cao học. Linh đọc trên điện thoại, hay bị ngắt quãng, mạng 4G chập chờn. Vì vậy flow nào trong app cũng có xử lý riêng khi lỗi.
>
> `[chỉ cột bên phải]` App có ba flow, giữ nguyên từ Lab 2:
>
> - Flow A: phân tích một bài.
> - Flow B: tìm chủ đề yếu, rồi mở reference có vấn đề trong chủ đề đó.
> - Flow C: xem lại lịch sử và xuất báo cáo PDF.
>
> Thế nào là thành công? Ít nhất 4 trên 5 người tự làm xong, không cần ai giúp, trong 2 phút tính từ lúc màn Overview hiện ra.
>
> *(Chuyển)* Tiếp theo là thiết kế Figma so với app thật.

**Thầy hỏi:**

- *"Chủ đề yếu tính thế nào?"* Chủ đề yếu là chủ đề có ít nhất 3 reference, và ít nhất một nửa trong số đó là Hallucinated hoặc Error. Warning không tính vì chỉ lệch nhỏ. Hai con số 3 và một nửa đổi được trên Remote Config. (`lib/models/weak_topic_rule.dart`)
- *"Persona có phỏng vấn người thật không?"* Chưa ạ. Đây là persona giả định, nhóm dựng từ nhóm người dùng mục tiêu.

---

## Slide 3 · Figma và app (1 phút)

**Câu chốt:** App làm đủ 12 màn của Figma. Chỗ nào khác Figma đều có lý do và được ghi lại.

**Nói:**

> `[chỉ bên trái]` Đây là thiết kế trên Figma, gồm 12 màn và các trạng thái. `[chỉ bên phải]` Còn đây là app thật: màn đăng nhập khi người dùng huỷ, màn Analyze, và màn Export đang báo Uploaded.
>
> App làm đủ 12 màn và 3 flow, kể cả các nhánh lỗi. 22 component trên Figma đều có widget tương ứng trong code.
>
> `[chỉ bảng]` Có ba chỗ app khác Figma:
>
> - Một: Figma thiết kế upload lên Cloud Storage. Nhưng gói Spark miễn phí không có Storage. Nên app lưu PDF trên máy, còn khi bật cờ `enable_cloud_upload` thì upload lên Cloudinary, như thầy đã cho phép.
> - Hai: vì vậy lỗi "Upload failed" đổi tên thành "Export failed". Lý do là lỗi có thể xảy ra lúc tạo hoặc lưu PDF, không chỉ lúc upload.
> - Ba: ở màn Reference, Figma chỉ có một hộp thoại cảnh báo tự bật lên. Đóng rồi thì không xem lại được. Nên app thêm một banner có nút Details để mở lại.
>
> Lý do của từng thay đổi được ghi trong file design-traceability.
>
> *(Chuyển)* Bây giờ em nói về kiến trúc code.

**Thầy hỏi:**

- *"Figma đã cập nhật theo app chưa?"* Hai thay đổi ở phần Export đã cập nhật trên Figma. Nút Details và các câu báo lỗi mới, như Sign-in failed hay Couldn't save, thì chưa, nhóm sẽ bổ sung. (`docs/design-traceability.md`, cột "Figma đã cập nhật?")

---

## Slide 4 · Kiến trúc MVVM (1 phút 15 giây)

**Câu chốt:** Code chia 4 tầng, tầng trên gọi tầng dưới, không có chiều ngược lại. Chỉ tầng service được đụng tới Firebase và mạng.

**Nói:**

> Nhóm em dùng kiến trúc MVVM với Provider. `[chỉ từ trên xuống]` Có bốn tầng. Tầng trên gọi tầng dưới, còn tầng dưới không biết tầng trên.
>
> - View là các màn hình và widget. View chỉ vẽ giao diện, rồi chuyển thao tác của người dùng xuống ViewModel.
> - ViewModel có 13 lớp. ViewModel giữ trạng thái, gọi service, ghi Analytics, rồi báo cho View vẽ lại.
> - Service bọc Firebase, backend và Cloudinary lại. Lỗi của thư viện được đổi thành lỗi của app.
> - Dưới cùng là Firebase, backend chạy trên laptop qua Tailscale, và Cloudinary.
>
> `[chỉ cột phải]` Nhóm giữ kiến trúc này bằng bốn quy tắc:
>
> - Widget không gọi Firebase trực tiếp.
> - Không viết logic trong hàm `build()`.
> - Mỗi màn có bốn trạng thái: đang tải, rỗng, lỗi, và có dữ liệu. Nhóm dùng sealed class, nên màn nào quên xử lý một trạng thái thì code không biên dịch được.
> - Service được tạo ở đúng một chỗ là `app_dependencies.dart`, rồi truyền vào ViewModel. Nhờ vậy khi test, nhóm thay bằng service giả rất dễ.
>
> *(Chuyển)* Tiếp theo là design system.

**Thầy hỏi:**

- *"Giải thích một ViewModel."* Dùng phần [AnalyzeViewModel](#3-giải-thích-một-viewmodel-analyzeviewmodel) ở cuối file.
- *"Sao chọn Provider mà không chọn Riverpod?"* Đề cho phép cả hai. Nhóm đã dùng Provider ở Lab 2 nên giữ nguyên.
- *"Có dùng design pattern nào?"* Có năm pattern: Repository, Adapter (các lớp service bọc Firebase và Cloudinary), Dependency Injection (`app_dependencies.dart`), Observer (ChangeNotifier) và Specification (quy tắc chủ đề yếu). Bảng đầy đủ ở `docs/architecture.md` mục 10.

---

## Slide 5 · Design system trong code (50 giây)

**Câu chốt:** Màu và kích thước khai báo ở một chỗ. Màn hình chỉ dùng lại, không tự viết mã màu.

**Nói:**

> Design system có ba tầng.
>
> - Tầng token: màu, khoảng cách, bo góc. Tất cả nằm trong một file duy nhất là `app_tokens.dart`.
> - Tầng theme: font chữ, màu chủ đạo, kiểu của nút, ô nhập và thẻ. Tiêu đề dùng font Source Serif 4, nội dung dùng Inter. Năm màu trạng thái của reference được thêm vào theme, nên màn hình chỉ gọi tên trạng thái chứ không viết mã màu.
> - Tầng component: 22 component trên Figma thành 22 widget trong code.
>
> Về accessibility, nhóm có widget test kiểm tra hai điều. Một là chữ không bị tràn trên màn 360 và 412 dp, kể cả khi phóng chữ lên 130%. Hai là vùng bấm đủ lớn, tối thiểu 48 dp.
>
> Nhóm cũng sửa một lỗi tương phản: viền ô nhập lúc đầu chỉ đạt 1.42:1, quá mờ. Nhóm đổi sang màu đạt 4.55:1.
>
> *(Chuyển)* Phần tiếp theo là trọng tâm: các công nghệ trong app. Mỗi công nghệ em nói theo ba phần: là gì và vì sao cần, chạy thế nào, nằm ở đâu và chạy lúc nào. `[chỉ góc trên bên phải slide sau]` Nhãn ở góc trên cho biết slide đang ở phần nào. Bắt đầu với đăng nhập.

**Thầy hỏi:**

- *"Sao phải đổi màu viền?"* Chuẩn WCAG 1.4.11 yêu cầu viền ô nhập có độ tương phản ít nhất 3:1 so với nền. Màu cũ chỉ 1.42:1 nên không đạt.

---

## Slide 6 · Authentication: What–Why (30 giây)

**Câu chốt:** Firebase cấp cho mỗi tài khoản một uid. Mọi dịch vụ khác đều dựa vào uid đó.

**Nói:**

> Authentication là dịch vụ đăng nhập của Firebase. Google xác nhận người dùng là ai. Firebase cấp cho tài khoản một uid cố định, và một ID token có hạn 1 giờ.
>
> Vì sao Realtron cần? Lịch sử, báo cáo và thông báo là của riêng từng người, nên app phải biết ai đang dùng. Backend chạy trên laptop, chỉ được nhận lệnh từ người đã đăng nhập. Nhóm chọn Google Sign-In vì Linh đã có sẵn tài khoản Google, không phải nhớ thêm mật khẩu.
>
> `[chỉ sơ đồ]` Cùng một uid đi qua mọi dịch vụ: thư mục trên Firestore và Cloudinary, token FCM, user ID trên Analytics và Crashlytics, và backend.
>
> *(Chuyển)* Đăng nhập chạy thế nào?

**Thầy hỏi:**

- *"uid khác ID token thế nào?"* uid là mã cố định của tài khoản, không đổi. ID token giống một tấm vé: bên trong có uid, có chữ ký của Google, và hết hạn sau 1 giờ. Server kiểm tra vé để biết người gọi đúng là chủ của uid đó.

---

## Slide 7 · Authentication: How (45 giây)

**Câu chốt:** Google xác nhận danh tính, Firebase cấp uid. Router và backend đều dựa vào uid đó.

**Nói:**

> Có bốn bước:
>
> 1. Người dùng đăng nhập bằng Google. Google xác nhận danh tính và trả về một token của Google.
> 2. App đổi token đó lấy phiên đăng nhập Firebase. Firebase cấp uid và một ID token, tự làm mới.
> 3. App theo dõi trạng thái đăng nhập. Chưa đăng nhập thì mọi màn đều chuyển về màn Sign-in. Đăng nhập rồi thì vào màn Analyze.
> 4. Khi gọi backend, app gửi kèm ID token. Backend tự kiểm tra token để lấy uid. Firestore cũng có rule: mỗi người chỉ truy cập được dữ liệu của chính mình.
>
> `[chỉ ô đỏ]` Khi lỗi: người dùng bấm huỷ thì app báo "Sign-in cancelled". Mất mạng thì app báo offline, không bị crash. Khi đăng xuất, app xoá FCM token của máy, rồi đăng xuất cả Google lẫn Firebase.
>
> `[chỉ ba ảnh]` Ba ảnh là ba trạng thái: chưa đăng nhập, huỷ đăng nhập, và đã đăng nhập.
>
> *(Chuyển)* Trong code, uid được dùng ở những chỗ nào?

**Thầy hỏi:**

- *"Đăng xuất khi mất mạng thì sao?"* Bước xoá token chỉ chờ tối đa 5 giây. Nếu lỗi thì ghi lên Crashlytics, còn việc đăng xuất vẫn tiếp tục. (`ProfileViewModel.signOut`)
- *"Tên hàm là gì?"* `signInWithCredential` để đổi token; `authStateChanges` để theo dõi đăng nhập; router là go_router.

---

## Slide 8 · Authentication: Where–When (40 giây)

**Câu chốt:** Bảng đi theo một phiên dùng app: mở app, đăng nhập, dùng, đăng xuất.

**Nói:**

> `[chỉ bảng]` Bảng này đi theo một phiên dùng app:
>
> - Mở app hoặc đổi màn: hàm `gateRedirect` trong `app_router.dart` quyết định có cho vào màn đó hay không.
> - Bấm Continue with Google: AuthViewModel gọi AuthService để đăng nhập.
> - Vừa có user: app gắn uid cho Analytics và Crashlytics, tạo hồ sơ trên Firestore, và lưu token FCM.
> - Mỗi lệnh gửi backend: app gắn ID token vào header. Backend tự kiểm token.
> - Mỗi lần đọc, ghi Firestore: rules so uid.
> - Bấm Sign out: ProfileViewModel xoá token rồi đăng xuất.
>
> `[chỉ ô dưới]` Backend không tin uid do app gửi lên, vì ai cũng sửa được. ID token có chữ ký của Google, nên backend kiểm được.
>
> `[chỉ ảnh Console]` Bằng chứng: Firebase Console có hai tài khoản Google đã đăng nhập.
>
> *(Chuyển)* Có uid rồi, dữ liệu của từng người nằm ở Firestore.

**Thầy hỏi:**

- *"Chưa đăng nhập mà mở thẳng một màn thì sao?"* Router chạy `gateRedirect` mỗi lần đổi màn, và chạy lại khi trạng thái đăng nhập đổi. Chưa đăng nhập thì luôn bị đưa về `/sign-in`.

---

## Slide 9 · Firestore: What–Why và How (1 phút)

**Câu chốt:** App chỉ gọi backend để ra lệnh. Kết quả nằm ở Firestore, nên backend tắt vẫn xem được bài cũ.

**Nói:**

> Firestore là cơ sở dữ liệu NoSQL của Firebase. App nghe thay đổi theo thời gian thực, và có cache trên máy.
>
> Vì sao cần? Backend chạy trên laptop, có lúc tắt. Kết quả nằm ở Firestore, nên bài đã phân tích vẫn mở được. Màn Analyzing cũng không phải hỏi backend liên tục.
>
> `[chỉ sơ đồ]` Cách chạy có năm bước:
>
> 1. App gửi lệnh phân tích tới backend, kèm ID token.
> 2. Backend ghi trạng thái và tiến độ vào Firestore.
> 3. App nghe thay đổi đó, nên thanh tiến độ chạy theo.
> 4. Backend ghi danh sách reference, chủ đề, rồi báo xong.
> 5. Màn Overview đọc kết quả. Lần sau mở lại thì đọc được từ cache.
>
> `[chỉ hai ô dưới]` Mất mạng thì app đọc từ cache, còn lệnh ghi xếp hàng chờ có mạng. Rules: mỗi người chỉ đọc dữ liệu của mình; kết quả phân tích thì app chỉ được đọc.
>
> *(Chuyển)* Trong code, ai ghi và ai đọc từng phần dữ liệu?

**Thầy hỏi:**

- *"Firestore có trong 6 dịch vụ đề yêu cầu không?"* Không. Đề yêu cầu Auth, Storage, FCM, Analytics, Crashlytics và Remote Config. Nhóm dùng thêm Firestore để app vẫn có dữ liệu khi backend tắt.
- *"Lệnh ghi khi mất mạng thì sao?"* SDK giữ lệnh trên máy và gửi khi có mạng. Nếu code chờ lệnh đó xong thì màn hình sẽ đứng, đó là lỗi CR-01 mà nhóm đã sửa.

---

## Slide 10 · Firestore: Where–When (40 giây)

**Câu chốt:** App ghi dữ liệu của người dùng. Backend ghi kết quả phân tích. Rules chặn app ghi vào kết quả.

**Nói:**

> `[chỉ bảng]` Có năm phần dữ liệu:
>
> - `users/{uid}`: app tạo lần đầu đăng nhập, rồi thêm token FCM. Backend đọc token này để gửi push.
> - `library`: app ghi mỗi lần Analyze, đổi tên hay xoá. Màn History và Recent đọc phần này.
> - `reports`: app ghi sau khi upload PDF.
> - `notifications`: backend ghi khi phân tích xong. App chỉ được đổi trạng thái đã đọc.
> - `analyses`: backend ghi trong lúc phân tích. Các màn Analyzing, Overview, Topics, Reference đọc phần này.
>
> `[chỉ đoạn rules]` Rules: người dùng chỉ đọc được dữ liệu của mình. Với `analyses`, app chỉ được đọc, không được ghi.
>
> `[chỉ hai ảnh]` Hai ảnh Console là token FCM và bản ghi báo cáo trong Firestore. Tên các collection khai báo một chỗ duy nhất, trong `firestore_schema.dart`.
>
> *(Chuyển)* Tiếp theo là lưu file báo cáo.

**Thầy hỏi:**

- *"Sao app không được ghi vào analyses?"* Kết quả phân tích dùng chung cho mọi người. Nếu app ghi được thì ai cũng sửa được kết quả. Chỉ backend ghi, bằng Admin SDK.

---

## Slide 11 · Storage → Cloudinary: What–Why (30 giây)

**Câu chốt:** Báo cáo PDF cần một link. Gói Spark không có Storage, nên nhóm dùng Cloudinary mà không phải sửa màn nào.

**Nói:**

> Dịch vụ này lưu file trên cloud và trả về một đường link.
>
> Vì sao cần? Báo cáo PDF cần một link để mở trên laptop hoặc gửi cho người khác. Đề còn yêu cầu hiện tiến độ upload, và mỗi người chỉ ghi được vào thư mục của mình.
>
> `[chỉ hai thẻ]` Thiết kế dùng Firebase Cloud Storage. Nhưng gói Spark không có Storage, nên nhóm dùng Cloudinary, như thầy đã cho phép.
>
> `[chỉ khung code]` Đổi được dễ dàng vì ViewModel chỉ biết interface StorageService. Chỉ sửa một dòng trong `app_dependencies.dart`, không sửa màn nào.
>
> *(Chuyển)* Upload chạy thế nào?

**Thầy hỏi:**

- *"Sao không để khoá bí mật trong app cho gọn?"* File APK giải nén được. Ai lấy được khoá thì upload hoặc xoá được mọi file trong tài khoản Cloudinary.

---

## Slide 12 · Storage → Cloudinary: How (45 giây)

**Câu chốt:** Khoá bí mật chỉ nằm ở backend. Backend ký cho đúng thư mục của từng người, nên ai cũng chỉ ghi được vào thư mục của mình.

**Nói:**

> Ý chính là upload có chữ ký. Có năm bước:
>
> 1. App tạo file PDF từ đúng kết quả người dùng đang xem.
> 2. App xin backend một chữ ký, gửi kèm ID token.
> 3. Backend lấy uid từ token, rồi ký cho đường dẫn `reports/{uid}/tên-file`.
> 4. App gửi file thẳng lên Cloudinary, không đi qua backend, và hiện phần trăm tiến độ.
> 5. App nhận link file, lưu thông tin vào Firestore, rồi hiện "Uploaded" cùng nút Copy link.
>
> `[chỉ khung code]` Chữ ký là mã băm SHA-1 của đường dẫn, thời gian và khoá bí mật. `[chỉ hai ô]` Đúng thư mục thì Cloudinary nhận. Nếu ai sửa đường dẫn sang thư mục người khác, chữ ký sẽ sai và Cloudinary từ chối.
>
> `[chỉ ô đỏ]` Khi lỗi: backend tắt, backend thiếu cấu hình Cloudinary, hoặc upload quá 30 giây, thì app báo "Export failed" và ghi lỗi lên Crashlytics. File PDF vẫn còn trên máy.
>
> *(Chuyển)* Upload chạy ở đâu và lúc nào?

**Thầy hỏi:**

- *"Chữ ký dùng lại được không?"* Không lâu được. Chữ ký có kèm thời gian, Cloudinary chỉ nhận trong khoảng 1 giờ. Và chữ ký chỉ đúng cho một đường dẫn file.
- *"Ký thế nào?"* App gọi `POST /api/uploads/signature`. Backend băm SHA-1 trên `public_id`, timestamp và khoá bí mật. Thiếu biến `CLOUDINARY_*` thì backend trả 503.

---

## Slide 13 · Storage → Cloudinary: Where–When (40 giây)

**Câu chốt:** Upload chỉ chạy khi người dùng bấm Report và cờ `enable_cloud_upload` đang bật.

**Nói:**

> `[chỉ bảng]` Luồng bắt đầu khi người dùng bấm Report ở màn Overview. ExportViewModel tạo PDF và lưu trên máy.
>
> Dòng 73 kiểm cờ Remote Config `enable_cloud_upload`. Tắt thì dừng ở "Saved on device". Bật thì app xin chữ ký, upload, rồi ghi link vào Firestore.
>
> Lúc khởi động, `app_dependencies.dart` chọn CloudinaryStorageService cho interface StorageService.
>
> `[chỉ ba ảnh]` Bằng chứng: màn Export báo Uploaded, file PDF 8.86 KB trên Cloudinary nằm trong `reports/{uid}`, và bản ghi trong Firestore.
>
> *(Chuyển)* Tiếp theo là thông báo đẩy, tức là FCM.

> **Trước khi demo upload:** bật `enable_cloud_upload = true` trên Remote Config (mặc định là `false`), và backend phải có đủ `CLOUDINARY_*` trong `.env`.

---

## Slide 14 · FCM: What–Why (30 giây)

**Câu chốt:** Phân tích một bài mất 2–10 phút. Push báo cho người dùng khi xong, nên họ không phải ngồi chờ.

**Nói:**

> FCM là dịch vụ của Google đẩy thông báo từ server xuống từng máy, kể cả khi app chạy nền hoặc đã tắt. `[chỉ ảnh]` Đây là push thật trên máy.
>
> Vì sao cần? Một bài chưa có kết quả mất khoảng 2 đến 10 phút. Người dùng không phải ngồi chờ: cứ rời app, khi có push thì chạm vào là mở đúng bài.
>
> `[chỉ 3 thẻ]` Ba câu thầy đã hỏi về token:
>
> - **Token là gì?** Là địa chỉ nhận thông báo của một bản cài app trên một máy. Nó không phải tài khoản. Một người đăng nhập trên 2 máy thì có 2 token.
> - **Ai cấp, khi nào đổi?** Server FCM của Google cấp. Token đổi khi cài lại app hoặc xoá dữ liệu app. Khi đổi, app được báo và tự đẩy token mới lên.
> - **Máy có lưu token không?** Thư viện FCM tự lưu trên máy. App đẩy token lên Firestore để server biết gửi tới đâu. Khi đăng xuất, app xoá token để người dùng sau không nhận nhầm thông báo.
>
> *(Chuyển)* Push đi từ server xuống máy thế nào?

---

## Slide 15 · FCM: How (45 giây)

**Câu chốt:** Token là địa chỉ của máy. Server cần địa chỉ này, cộng với quyền của project, để gửi push.

**Nói:**

> `[chỉ luồng 5 bước]` Luồng chạy:
>
> 1. App xin FCM một token.
> 2. App lưu token vào Firestore, trong hồ sơ của user. Một user có thể có nhiều token, mỗi máy một cái.
> 3. Khi phân tích xong một bài, backend đọc danh sách token của user.
> 4. Backend dùng Firebase Admin SDK gửi push tới các token đó, kèm mã của bài báo.
> 5. FCM đẩy push xuống máy.
>
> `[chỉ ô trái]` Gửi message phải có quyền của project, nên chỉ server gửi được. Phần notification thì điện thoại tự hiện. Phần data mang mã bài để app mở đúng bài. Muốn thử nhanh thì vào Console, mục Messaging, gửi test message bằng cách dán token.
>
> `[chỉ bảng]` App xử lý ba trạng thái: đang mở thì app tự hiện thanh thông báo nhỏ; chạy nền hoặc đã tắt thì điện thoại hiện thông báo, chạm vào là mở app.
>
> *(Chuyển)* Trong code, các bước này nằm ở đâu?

**Thầy hỏi:**

- *"Sao lưu token dạng mảng?"* Vì một người có thể dùng nhiều máy, mỗi máy một token. App thêm bằng `arrayUnion` nên không bị trùng.
- *"Notification message khác data message chỗ nào?"* Phần notification thì hệ thống tự hiện khi app chạy nền hoặc đã tắt. Phần data thì chỉ app đọc. App dùng `analysisId` trong data để mở đúng bài.

---

## Slide 16 · FCM: Where–When trong code (40 giây)

**Câu chốt:** Token lên Firestore khi đăng nhập, push đi khi job xong, token bị xoá khi đăng xuất.

**Nói:**

> `[chỉ bảng]` Sáu thời điểm:
>
> - Vừa đăng nhập: AuthViewModel bật messaging. App xin quyền, lấy token, thêm vào Firestore.
> - Token đổi: app đẩy token mới lên.
> - Job phân tích xong: backend gọi `notify_done()` trong `store.py`. Hàm này lưu một thông báo vào Firestore rồi gửi push.
> - Token không còn dùng được: backend xoá nó khỏi danh sách.
> - Người dùng chạm push: `main.dart` ghi sự kiện rồi mở màn Overview của bài.
> - Đăng xuất: app xoá token, chờ tối đa 5 giây.
>
> *(Chuyển)* Slide sau là bằng chứng push chạy được.

**Thầy hỏi:**

- *"Đăng xuất rồi thì token trong Firestore có bị xoá không?"* App gọi `deleteToken()` nên token hết hiệu lực ngay. Lần sau backend gửi tới token đó, FCM báo không còn, và backend tự xoá nó khỏi mảng.
- *"Tên hàm là gì?"* App: `getToken()`, `onTokenRefresh`, `onMessage` (app đang mở), `onMessageOpenedApp` (app chạy nền), `getInitialMessage` (app đã tắt). Backend: `send_each_for_multicast`, `ArrayRemove`.

---

## Slide 17 · FCM: Where–When, bằng chứng 3 trạng thái (45 giây + demo)

**Câu chốt:** Push đến được ở cả ba trạng thái của app, và bấm vào thì mở đúng bài.

**Nói:**

> Đề yêu cầu nhận push ở ba trạng thái của app. Sáu ảnh trên slide đủ cả ba:
>
> - App đang mở: hệ thống không tự hiện thông báo, nên app tự hiện một thanh thông báo nhỏ có nút View.
> - App chạy nền: thông báo hiện trên khay. Bấm vào thì mở màn Overview của bài.
> - App đã tắt: máy vẫn nhận thông báo "Analysis done". Bấm vào thì app mở lên đúng bài đó.
>
> Ảnh cuối là danh sách thông báo trong app, lấy từ Firestore. Nên kể cả khi người dùng tắt quyền thông báo trên Android 13 trở lên, danh sách này vẫn còn.
>
> Ảnh trên slide chụp trên emulator. Em xin demo lại trên điện thoại thật.

**Demo:**

1. Mở Firestore, vào `users/{uid}`, copy token trong `fcmTokens`.
2. Vào Console → Messaging, tạo một thông báo. Ở Additional options, thêm custom data `analysisId = 1706.03762` để bấm vào thì mở đúng bài.
3. Bấm Send test message, dán token. Gửi ba lần: khi app đang mở, khi app chạy nền, và khi app đã tắt (vuốt app khỏi danh sách đa nhiệm, **không** dùng Force stop).

---

## Slide 18 · Analytics: What–Why (30 giây)

**Câu chốt:** Mỗi sự kiện trả lời một câu hỏi về sản phẩm, gắn với tiêu chí thành công của Lab 2.

**Nói:**

> Analytics ghi lại sự kiện mỗi khi người dùng làm một việc trong app, để nhóm đếm và phân tích trên Console.
>
> Vì sao cần? Lab 2 đặt tiêu chí: ít nhất 4 trên 5 người tự làm xong trong 2 phút. Sự kiện ở từng bước cho biết người dùng thật dừng ở đâu. Ví dụ: có nhiều lượt search nhưng ít view_topic, tức là người dùng dừng ở Overview, chưa vào chủ đề.
>
> `[chỉ bảng]` Nhóm lập kế hoạch 9 sự kiện trước khi code. Mỗi sự kiện trả lời một câu hỏi. Ví dụ, `search` cho biết bao nhiêu lần người dùng dùng lại kết quả có sẵn.
>
> *(Chuyển)* Sự kiện đi từ app lên Console thế nào?

---

## Slide 19 · Analytics: How (40 giây)

**Câu chốt:** ViewModel ghi sự kiện qua một service. Bật debug mode thì thấy ngay trên DebugView.

**Nói:**

> `[chỉ hàng trên]` ViewModel gọi AnalyticsService, service gọi thư viện Firebase. Thư viện gom sự kiện lại rồi mới gửi, nên báo cáo trên Console có thể chậm tới 24 giờ.
>
> `[chỉ ô xanh]` Khi bật debug mode bằng lệnh adb, sự kiện được gửi ngay và hiện trên DebugView trong vài giây.
>
> Sau khi đăng nhập, app gắn uid cho Analytics. Nhóm không ghi email hay tên.
>
> `[chỉ ô dưới]` Có một lỗi thật nhóm tìm ra nhờ Console. Lúc đầu nhóm đặt tên sự kiện là `notification_open`. Nhưng Firebase đã giữ tên này cho riêng mình, nên app báo lỗi. Test với service giả không bắt được lỗi này, nhưng Crashlytics thì bắt được. Nhóm đã đổi tên thành `open_notification`.
>
> *(Chuyển)* Từng sự kiện được ghi ở đâu, lúc nào?

**Thầy hỏi:**

- *"Sao trên trang Events chưa thấy sự kiện?"* Báo cáo Analytics có thể chậm tới 24 giờ. DebugView mới là thời gian thực.
- *"Có ghi thông tin cá nhân không?"* Không. Từ khoá tìm kiếm chỉ là mã arXiv, vốn công khai.

---

## Slide 20 · Analytics: Where–When (40 giây)

**Câu chốt:** Mỗi sự kiện được ghi ở đúng một bước, trong ViewModel của màn đó.

**Nói:**

> `[chỉ bảng]` Bảng này ghi mỗi sự kiện bắn lúc nào và ở đâu. Ví dụ:
>
> - `login` khi đăng nhập Google thành công, trong AuthViewModel.
> - `search` khi bấm Analyze.
> - `filter_weak_topics` khi bật chip Weak ở màn Topics.
> - `open_notification` khi chạm push, hoặc chạm một thông báo trong danh sách.
>
> Mọi lời gọi đều đi qua AnalyticsService; widget không gọi thẳng Firebase.
>
> `[chỉ hai ảnh]` Bằng chứng: DebugView có các sự kiện view_analysis, view_reference, filter_weak_topics, login, logout, search, và user_id đã được gắn.
>
> *(Chuyển)* Nhắc tới Crashlytics, đó cũng là dịch vụ tiếp theo.

**Thầy hỏi:**

- *"Chi tiết ở đâu?"* Kế hoạch sự kiện ở `docs/analytics-plan.md`. `search` có tham số `cache_hit`, `view_topic` có `is_weak`. Lỗi tên sự kiện được sửa ở commit fee2fe3.

---

## Slide 21 · Crashlytics: What–Why (30 giây)

**Câu chốt:** Lỗi xảy ra trên máy người dùng, nơi nhóm không nhìn thấy. Crashlytics gửi lỗi đó về cho nhóm.

**Nói:**

> Crashlytics thu báo cáo crash và lỗi từ máy người dùng, kèm thiết bị, user ID và thông tin app gắn thêm.
>
> Vì sao cần? App chạy trên điện thoại người dùng, mạng 4G chập chờn, backend có thể tắt. Lỗi xảy ra ở chỗ nhóm không nhìn thấy. Lỗi đã báo cho người dùng vẫn cần đếm. Và Crashlytics bắt được lỗi mà test với service giả bỏ sót.
>
> `[chỉ hai ô phải]` Có hai loại:
>
> - Fatal là crash: app tắt, báo cáo gửi ở lần mở app sau.
> - Non-fatal là lỗi đã xử lý: app vẫn chạy, người dùng thấy thông báo. `[chỉ ảnh]` Ví dụ: nhập `ftp://abc` ở màn Connect, app báo "Can't reach server".
>
> *(Chuyển)* Lỗi đi tới Console thế nào?

**Thầy hỏi:**

- *"Non-fatal để làm gì?"* Lỗi đó người dùng đã được báo, nhưng nhóm vẫn cần biết nó xảy ra bao nhiêu lần, trong hoàn cảnh nào.

---

## Slide 22 · Crashlytics: How (40 giây)

**Câu chốt:** Lỗi làm app chết thì báo là fatal. Lỗi app đã xử lý thì báo là non-fatal, kèm thông tin để biết lỗi xảy ra trong hoàn cảnh nào.

**Nói:**

> Crashlytics trong app có bốn phần:
>
> 1. Bắt mọi lỗi chưa xử lý. Lúc app khởi động, nhóm nối bộ bắt lỗi của Flutter vào Crashlytics. Lỗi nào lọt ra ngoài, kể cả lỗi bất đồng bộ, đều được báo là fatal.
> 2. Báo cả lỗi đã xử lý. ViewModel bắt lỗi, báo cho người dùng trước, rồi gửi lên Crashlytics dạng non-fatal.
> 3. Thêm ngữ cảnh. App gắn uid và một khoá tên `server_reachable`.
> 4. Khi app crash, báo cáo được lưu trên máy và gửi ở lần mở app sau. Nên phải mở lại app rồi đợi vài phút.
>
> `[chỉ sơ đồ]` Sơ đồ là hai đường đi của một lỗi: không ai bắt thì thành fatal, ViewModel bắt thì thành non-fatal. Cả hai đều lên Console kèm uid.
>
> *(Chuyển)* Trong code, lỗi được báo ở những chỗ nào?

**Thầy hỏi:**

- *"Sao phải mở lại app mới thấy crash?"* Lúc crash, app đã chết nên không gửi được. Thư viện lưu báo cáo trên máy và gửi ở lần mở sau.
- *"Tên hàm là gì?"* `FlutterError.onError` và `PlatformDispatcher.onError`, gắn trong `installHandlers()` lúc khởi động; `recordError` với `fatal: false`; `setUserIdentifier(uid)`.

---

## Slide 23 · Crashlytics: Where–When (40 giây + demo)

**Câu chốt:** Một chỗ bắt crash lúc khởi động, tám ViewModel báo lỗi đã xử lý, mỗi chỗ có tên riêng.

**Nói:**

> `[chỉ bảng]` Chỗ bắt crash duy nhất là `app_dependencies.dart`, lúc app khởi động. Tám ViewModel báo lỗi non-fatal, mỗi chỗ có một cái tên riêng gọi là reason. Ví dụ ConnectViewModel báo `test_server` khi thử kết nối server thất bại.
>
> `[chỉ ảnh Issues]` Trang Issues có lỗi non-fatal từ đường lỗi thật `ftp`, hai lần test crash, và lỗi tên sự kiện. `[chỉ hai ảnh nhỏ]` Ảnh dưới cho thấy khoá `server_reachable` bằng false, cùng thiết bị và user ID.
>
> `[chỉ ô dưới]` Nút Test crash nằm riêng ở mục Firebase demo trong Profile, không nằm trong luồng dùng bình thường.
>
> Em xin demo.

**Demo:**

1. Profile → Firebase demo → **Test crash** → hộp thoại Test crash? → bấm **Crash**. App tắt.
2. Mở lại app. Trong lúc chờ, bấm **Log error** (hiện thông báo Error logged) để tạo thêm một lỗi non-fatal.
3. Vài phút sau, mở Console → Crashlytics để thấy lỗi mới.

**Thầy hỏi:**

- *"Admin xem kết quả ở đâu?"* Hiện nhóm xem trên Firebase Console. Trang web cho admin là phần của Final Assignment.

---

## Slide 24 · Remote Config: What–Why (30 giây)

**Câu chốt:** Đổi hành vi của app từ Console, không cần phát hành bản mới.

**Nói:**

> Remote Config là bộ tham số lưu trên Firebase. App đọc khi chạy. Sửa trên Console rồi bấm Publish là app nhận giá trị mới.
>
> Vì sao cần? Ngưỡng chủ đề yếu cần chỉnh theo dữ liệu thật. Build lại và cài lại APK cho mọi người thì quá chậm. Remote Config còn giúp tắt nhanh một tính năng khi nó lỗi, ví dụ nút Report.
>
> `[chỉ bảng]` App có năm khoá, mỗi khoá có giá trị mặc định. `[chỉ ô dưới]` Giá trị mặc định nằm ở hai nơi và phải khớp nhau: trong code, và trong file JSON dùng để tạo tham số trên Console.
>
> *(Chuyển)* Giá trị từ Console tới app thế nào?

---

## Slide 25 · Remote Config: How (40 giây)

**Câu chốt:** Đổi giá trị trên Console là app đổi theo ngay, không cần build lại. Mất mạng thì app vẫn có giá trị mặc định.

**Nói:**

> Remote Config chạy theo bốn bước:
>
> 1. App luôn có sẵn 5 giá trị mặc định. Nên lần đầu mở app, hoặc lúc mất mạng, app vẫn chạy bình thường.
> 2. Khi mở app, app tải giá trị mới về. Bản release tải nhiều nhất 1 lần mỗi giờ để không bị giới hạn. Bản debug thì không giới hạn.
> 3. App lắng nghe thay đổi. Console vừa bấm Publish là app nhận ngay.
> 4. Có giá trị mới thì màn hình tự vẽ lại, không cần build lại app.
>
> `[chỉ sơ đồ phải]` App lấy giá trị theo thứ tự: bản mới nhất trên Console; nếu chưa tải được thì giá trị đã kích hoạt lần trước, lưu trên máy; nếu chưa từng có thì giá trị mặc định trong code.
>
> *(Chuyển)* Khoá nào tác động tới màn nào?

**Thầy hỏi:**

- *"Mất mạng thì sao?"* App dùng giá trị tải được lần trước, hoặc giá trị mặc định nếu chưa tải lần nào.
- *"Sao đổi rồi mà app chưa đổi?"* Thường mất vài giây. Nếu máy mất kết nối realtime, app sẽ lấy giá trị mới ở lần mở sau. Bản release có thể phải chờ tới 1 giờ.

---

## Slide 26 · Remote Config: Where–When (40 giây + demo)

**Câu chốt:** Năm khoá, mỗi khoá có ViewModel đọc. Hai thay đổi nhìn thấy được trên màn hình.

**Nói:**

> `[chỉ bảng]` `max_recent_checks` do AnalyzeViewModel đọc, quyết định số thẻ ở mục Recent. `enable_report_export` do OverviewViewModel đọc, quyết định có nút Report hay không. Hai khoá về chủ đề yếu do các màn Overview, Topics và Export đọc.
>
> `[chỉ ô dưới]` Lúc khởi động, app tải giá trị. Các ViewModel lắng nghe service này, nên có giá trị mới là màn đang mở vẽ lại ngay.
>
> `[chỉ 4 ảnh]` Có hai bằng chứng. Đổi `max_recent_checks` từ 10 xuống 1, thì mục Recent chỉ còn 1 thẻ. Đổi `enable_report_export` từ true sang false, thì nút Report biến mất.
>
> Em xin demo trực tiếp.

**Demo:** làm theo phần [Đổi một giá trị Remote Config trực tiếp](#2-đổi-một-giá-trị-remote-config-trực-tiếp) ở cuối file.

**Thầy hỏi:**

- *"Tên hàm là gì?"* `setDefaults`, `fetchAndActivate`, `onConfigUpdated`, `activate`. Giá trị mặc định khớp với file `firebase/remote-config-defaults.json`.

---

## Slide 27 · ARTEMIS: What–Why (30 giây)

**Câu chốt:** ARTEMIS là agent AI dùng app trên máy Android như người test, đi qua được cả các màn ngoài Flutter.

**Nói:**

> ARTEMIS là agent AI mã nguồn mở của Google. Nó nhận chỉ dẫn bằng ngôn ngữ tự nhiên, rồi điều khiển máy Android qua ADB, điện thoại thật hay emulator đều được: chạm, gõ, vuốt, đọc màn hình.
>
> Vì sao cần? Nhóm đã có 141 test Flutter và 72 test backend, nhưng chúng dùng service giả. Chúng không chạm tới Firebase, backend, hay các màn ngoài Flutter như chọn tài khoản Google, chia sẻ link từ Chrome, mở push từ khay. Đề cũng yêu cầu ít nhất 10 ca, mỗi ca chạy 3 lần.
>
> `[chỉ 4 số]` Nhóm viết 19 ca: 9 ca chạy bình thường, 5 ca lỗi, và 5 ca tương tác ngoài Flutter.
>
> *(Chuyển)* Một test chạy thế nào?

**Thầy hỏi:**

- *"Tương tác ngoài Flutter là gì?"* Là những thứ không do Flutter vẽ: màn chọn tài khoản Google, chia sẻ link từ Chrome, mở push từ khay, mở PDF bằng app khác.

---

## Slide 28 · ARTEMIS: How (45 giây)

**Câu chốt:** Nhóm không tin khi agent nói "thành công", mà kiểm từng giá trị agent nhìn thấy.

**Nói:**

> Có bốn bước:
>
> 1. Mỗi test gửi cho agent một chỉ dẫn: bắt đầu ở đâu, làm những bước nào, cuối cùng phải thấy gì.
> 2. Agent đọc cây accessibility trước, khi cần mới nhìn ảnh màn hình. Nên nhóm gắn nhãn Semantics cho các nút và thẻ quan trọng.
> 3. Agent trả về các giá trị nó thấy, test kiểm từng giá trị.
> 4. Mỗi test chạy 3 lần.
>
> `[chỉ đoạn code]` Ví dụ TC-03 kiểm: tên màn là Paper Overview, tiêu đề bài đúng, có ít nhất một reference, và có sự kiện search trong log.
>
> `[chỉ ô phải]` Vì người test cũng là AI, nó có thể báo xong dù dừng sai màn. Nên nhóm không tin trạng thái SUCCESS. Riêng sự kiện Analytics thì test tự đọc Logcat, không hỏi agent.
>
> *(Chuyển)* Code test nằm ở đâu, và kết quả ra sao?

**Thầy hỏi:**

- *"Tại sao phải chạy 3 lần?"* Agent AI không phải lúc nào cũng làm giống nhau. Pass một lần có thể chỉ là may. Đạt 3/3 mới coi là ổn định.
- *"Flash và Pro khác gì?"* Flash rẻ và nhanh, dùng cho các lần chạy lại thường xuyên. Pro suy luận tốt hơn, dùng cho phiên khám phá không có kịch bản.

---

## Slide 29 · ARTEMIS: Where–When (40 giây)

**Câu chốt:** Suite có 19 ca trong `e2e_test/`. Mỗi lần chạy để lại một dòng kết quả và một trace của ARTEMIS.

**Nói:**

> `[chỉ bảng]` Code test nằm trong thư mục `e2e_test`. `conftest.py` chuẩn bị máy trước mỗi test, ví dụ đóng app để test nào cũng bắt đầu từ đầu. `realtron.py` chứa các chỉ dẫn dùng chung. Tám file test chia theo flow. `summarize.py` in bảng tỉ lệ pass.
>
> `[chỉ ô trên]` Khi nào chạy: trước khi nộp, mỗi ca 3 lần. Lần chạy đầu là tối 10/11: TC-03 trên emulator Android, với Firebase thật và backend chạy trên máy host.
>
> `[chỉ ô dưới]` Mỗi lần chạy ghi một dòng vào `results.jsonl`: ca nào, đạt hay không, bao nhiêu giây, trace ID. Trace của ARTEMIS lưu từng bước và ảnh màn hình trước, sau mỗi bước.
>
> *(Chuyển)* Slide sau là kết quả của lần chạy đó, với chính các ảnh ARTEMIS chụp.

**Thầy hỏi:**

- *"Sao chạy trên emulator?"* Suite chạy được trên cả điện thoại thật và emulator, chỉ cần ADB thấy máy. Lần này backend chạy trên chính laptop đó, nên app trong emulator gọi backend qua `10.0.2.2`, địa chỉ emulator dùng để trỏ về máy host.

---

## Slide 30 · ARTEMIS: kết quả TC-03 (45 giây)

**Câu chốt:** Agent đúng cả hai lần. Test đạt ở lần 2; lần 1 fail vì bộ test, không vì app.

**Nói:**

> `[chỉ hai ảnh]` Đây là ảnh ARTEMIS tự chụp ở lần 2. Agent chạm "Try 1706.03762", bấm Analyze, đợi màn Paper Overview hiện ra.
>
> `[chỉ ô code]` Rồi nó báo lại bốn giá trị: tên màn Paper Overview, tên bài Attention Is All You Need, 40 reference, và dòng "40 topics · 0 weak". Cả hai lần agent đều báo đúng như vậy.
>
> `[chỉ bảng]` Lần 1 test vẫn fail. `[chỉ ô cam]` Lỗi nằm ở bộ test: profile Flash kết thúc với trạng thái completed nhưng để trống output, nên test không có JSON để kiểm. Agent thật ra đã ghi JSON vào bước báo cáo cuối. Nhóm thêm hàm `final_report()` để đọc JSON từ bước đó.
>
> Lần 2 chạy với bản sửa: 6 bước, 112 giây, cả 5 assert đều đạt, kể cả sự kiện `search` trong Logcat. Theo `summarize.py`, TC-03 đạt 1 trên 2 lần. 18 ca còn lại chưa chạy.
>
> *(Chuyển)* Tiếp theo là phần rà soát mã bằng AI.

**Thầy hỏi:**

- *"Mới một ca, chưa đủ 3 lần?"* Đúng. Đề yêu cầu ít nhất 10 ca, mỗi ca 3 lần; nhóm mới chạy TC-03 hai lần. Các ca còn lại chạy bằng cùng lệnh `uv run pytest --count=3`, kết quả sẽ vào cùng file.
- *"Sao biết agent không bịa giá trị?"* Ảnh trong trace là ảnh chụp màn hình thật ở từng bước, khớp với JSON agent báo. Sự kiện `search` thì test tự đọc Logcat, không hỏi agent.

> **Nếu chạy thêm ca trước buổi thuyết trình**, cập nhật slide 30 theo bảng của `summarize.py`, rồi thay đoạn cuối bằng: "Kết quả: [X]/19 ca đạt 3/3. Ca [TC-…] chưa đạt vì [nguyên nhân], nhóm đã ghi vào `docs/test-plan.md`."

---

## Slide 31 · AI code review: What–Why và How (50 giây)

**Câu chốt:** AI tìm ra 10 vấn đề. Nhóm tự quyết định từng vấn đề và ghi lý do.

**Nói:**

> AI code review là dùng AI đọc code để chỉ ra chỗ có thể sai, kèm file, dòng và kịch bản gây lỗi. Nhóm dùng Claude Code, lệnh `/code-review` ở mức high, rà soát thư mục `lib/` ngày 05/11/2026.
>
> Vì sao cần? Lỗi ở đường lỗi, như mất mạng hay URL lạ, rất dễ lọt qua các test chạy bình thường. Đề cũng yêu cầu ít nhất 5 finding có quyết định và 3 fix có commit.
>
> `[chỉ 5 bước]` Quy trình có năm bước: chạy lệnh; đọc lại code và tái hiện lỗi; quyết định từng finding; sửa và commit; ghi lại vào `docs/code-review.md`.
>
> `[chỉ 4 số]` Kết quả: 10 finding, 8 Accepted, 2 Modified, 0 Rejected. AI chỉ tìm lỗi. Quyết định và lý do là của nhóm.
>
> *(Chuyển)* Các finding nằm ở đâu trong code?

**Thầy hỏi:**

- *"Review trên pull request nào?"* Nhóm chạy review trên cả thư mục `lib/`, không qua pull request.
- *"Finding gồm những loại nào?"* Cả 10 finding đều là lỗi (Bug).

---

## Slide 32 · AI code review: Where–When (40 giây)

**Câu chốt:** Mỗi finding gắn với một dòng code, một quyết định có lý do, và một commit.

**Nói:**

> `[chỉ bảng]` Em xin kể hai ví dụ.
>
> CR-01, Accepted. Khi mất mạng, lệnh ghi Firestore không báo lỗi mà chờ tới khi có mạng. Màn Analyze lại chờ lệnh này, nên nút Analyze quay mãi. Đề trừ điểm lỗi "spinner quay mãi", nên nhóm sửa: cho lệnh ghi chạy nền, không chờ nó nữa.
>
> CR-05, Modified. Mã arXiv kiểu cũ như `hep-th/9901001` có dấu gạch chéo, làm hỏng đường dẫn trong Firestore. AI đề nghị mã hoá mã này ở ba chỗ. Nhóm chọn cách khác: chặn ngay ở ô nhập, vì backend chưa thống nhất cách mã hoá.
>
> `[chỉ ô dưới]` Review chạy ngày 05/11/2026, sau khi xong tính năng, trên cả thư mục `lib/`.
>
> *(Chuyển)* Cuối cùng là khó khăn và bài học.

**Thầy hỏi (trả lời thật):**

- *"Mỗi fix có commit riêng không?"* CR-01 có commit riêng là 6c95c84. Từ CR-02 đến CR-10 được sửa chung trong commit be3ab33. Nhóm nhận đây là thiếu sót so với yêu cầu mỗi fix một commit.

---

## Slide 33 · Khó khăn, bài học, công cụ AI (1 phút)

**Câu chốt:** Khó khăn nào cũng có cách xử lý cụ thể. AI giúp làm nhanh, nhưng quyết định là của nhóm.

**Nói:**

> Nhóm em gặp bốn khó khăn lớn:
>
> 1. Gói Spark không có Cloud Storage. Nhóm chuyển sang Cloudinary, có chữ ký từ backend, và không phải sửa phần còn lại của app.
> 2. Tên sự kiện `notification_open` bị Firebase giữ riêng. Crashlytics bắt được lỗi, nhóm đổi tên.
> 3. Backend chạy trên laptop, có thể tắt bất cứ lúc nào. Nên app đọc kết quả từ Firestore, có cache offline, và chỉ gọi backend khi cần ra lệnh. Backend tắt thì người dùng vẫn xem lại được bài cũ.
> 4. RefChecker đọc nhầm năm thành tiêu đề với một loại file `.bbl`. Nhóm viết thêm `bbl_repair.py` để sửa. Với bài 1508.04025, trước khi sửa cả 15 reference đều mất tiêu đề. Sau khi sửa thì không còn cái nào, và số reference Verified tăng từ 1 lên 9.
>
> Bốn bài học nhóm rút ra:
>
> - Bằng chứng trên Console bắt được lỗi mà test với service giả bỏ sót.
> - Dùng interface và truyền service từ một chỗ thì đổi nhà cung cấp rất dễ.
> - Không nên chờ lệnh ghi Firestore khi chuyển màn.
> - AI tìm lỗi nhanh, nhưng lý do quyết định phải là của nhóm.
>
> Công cụ AI nhóm đã dùng: Google Stitch để sinh giao diện ở Lab 2, và Claude Code để viết code, test, tài liệu, chạy code review và soạn bộ slide này. Tài liệu chi tiết nằm trong các file docs ở cột phải, link video demo nằm trong README.
>
> Em xin cảm ơn thầy. Nhóm em sẵn sàng nhận câu hỏi.

---

## Chuẩn bị trước buổi

- [ ] Điền họ tên và MSSV ở slide 1.
- [ ] Điện thoại thật đã cài APK mới nhất và đăng nhập Google. Với máy Xiaomi/Redmi: bật Autostart cho Realtron, không dùng Force stop.
- [ ] Laptop chạy backend (thấy dòng `Uvicorn running on http://<IP Tailscale>:8000`). Tailscale bật trên cả hai máy. Màn Connect trong app kết nối được.
- [ ] Bài `1706.03762` đã phân tích xong, để mở Overview ngay khi demo.
- [ ] Debug Analytics: chạy `adb shell setprop debug.firebase.analytics.app vn.fpt.prm393.realtron` rồi mở lại app.
- [ ] Remote Config: nếu demo upload thì đặt `enable_cloud_upload = true`. Ghi lại giá trị gốc (`max_recent_checks = 10`, `enable_report_export = true`) để trả lại sau demo.
- [ ] Copy sẵn FCM token của máy, lấy từ Firestore `users/{uid}.fcmTokens`.
- [ ] Lệnh gửi lại push thật của một bài đã xong (chạy trong `backend/`): `.venv/Scripts/python -m orchestrator.push 1706.03762`.
- [ ] Mở sẵn các tab Console của project realtron-874ac: Authentication › Users, Firestore › `users`, Messaging, Analytics › DebugView, Crashlytics, Remote Config. Mở thêm tab Media Library của Cloudinary.

---

## Phần kiểm tra 5 phút

Thầy có thể kiểm từng bạn khoảng 5 phút với bốn việc: chạy một test ARTEMIS, đổi một giá trị Remote Config, giải thích một ViewModel, và giải thích một quyết định code review. Bạn nào cũng nên tự làm được cả bốn.

### 1. Chạy một test ARTEMIS

Cần có sẵn: máy chủ ARTEMIS đang chạy, có API key trong `.env` của ARTEMIS; điện thoại cắm USB đã bật USB Debugging, hoặc emulator đang mở; backend đang chạy.

```powershell
cd e2e_test
$env:E2E_TEST_ACCOUNT = "<email tài khoản test>"
$env:E2E_SERVER_URL   = "http://<IP Tailscale>:8000"   # emulator + backend cùng laptop: http://10.0.2.2:<cổng backend>
uv run pytest test_analyze.py::test_tc03_finished_paper_opens_right_away
```

Lần chạy ngày 10/11 mất khoảng 2 phút cho ca này.

Trong lúc test chạy, nói:

> Test này bảo agent mở app, nhập 1706.03762 rồi bấm Analyze. Agent đọc cây accessibility để tìm ô nhập và nút bấm. Bài này đã có kết quả, nên app phải mở thẳng màn Paper Overview. Cuối cùng, agent trả về tên màn, tiêu đề bài và số reference. Test kiểm từng giá trị, rồi kiểm sự kiện search trong log.

### 2. Đổi một giá trị Remote Config trực tiếp

1. Console → Remote Config → bấm vào `max_recent_checks` → đổi thành `1` → Save.
2. Bấm **Publish changes**.
3. Quay lại app, màn Analyze: mục Recent chỉ còn 1 thẻ. Màn Profile › Firebase demo cũng hiện giá trị mới.
4. Đổi lại thành `10` rồi Publish.

Trong lúc làm, nói:

> App lắng nghe thay đổi của Remote Config, nên Console vừa Publish là app nhận ngay. Service báo cho AnalyzeViewModel, và ViewModel cắt danh sách Recent theo giá trị mới. Không cần build lại app.

### 3. Giải thích một ViewModel: AnalyzeViewModel

Mở `lib/viewmodels/analyze_view_model.dart`, nói khoảng 1 phút:

> Đây là ViewModel của màn Analyze. Nó nhận 10 service qua constructor, tất cả đều là interface, và được tạo ở `app_dependencies.dart`.
>
> Khi người dùng gõ, hàm `setInput` kiểm tra mã arXiv. Mã sai thì hiện lỗi và khoá nút Analyze.
>
> Khi bấm Analyze, hàm `submit()` làm theo thứ tự:
>
> 1. Bật cờ `_submitting` để chặn bấm hai lần.
> 2. Hỏi Firestore xem bài đã có kết quả chưa.
> 3. Ghi sự kiện `search`, kèm `cache_hit` cho biết có dùng lại kết quả cũ hay không.
> 4. Nếu chưa có kết quả và cũng chưa đang chạy, thì gọi backend để bắt đầu phân tích.
> 5. Lưu bài vào thư viện của user, nhưng không chờ lệnh này xong. Đây chính là fix của CR-01.
> 6. Trả về mã bài. Nếu đã có kết quả thì mở màn Overview ngay.
>
> Khi lỗi: mất mạng thì báo không kết nối được. Lỗi lạ thì báo thất bại và ghi lên Crashlytics. Khối `finally` luôn tắt cờ `_submitting`, nên nút không bao giờ quay mãi.
>
> Danh sách Recent lấy từ Firestore theo thời gian thực, và chỉ hiện số bài bằng `max_recent_checks` trên Remote Config.

### 4. Giải thích một quyết định code review

Dùng CR-01 (Accepted) hoặc CR-05 (Modified), nói như ở slide 32. Mở `docs/code-review.md` và commit 6c95c84 để chỉ dòng code trước và sau khi sửa.

---

## Câu hỏi khó: trả lời thật

| Thầy hỏi | Trả lời |
|---|---|
| Ảnh trên slide chụp ở đâu? | Một số ảnh FCM, Remote Config và lỗi kết nối chụp trên emulator BlueStacks. Hôm nay em demo trên điện thoại thật. |
| ARTEMIS mới chạy một ca? | Đúng. Nhóm đã chạy TC-03 hai lần trên emulator: agent đúng cả hai lần, test đạt ở lần 2 sau khi sửa bộ test đọc output. 18 ca còn lại chưa chạy, và TC-03 chưa đủ 3 lần. Nhóm sẽ chạy tiếp và cập nhật bảng. |
| Fix code review sao gộp một commit? | CR-01 có commit riêng. CR-02 đến CR-10 sửa chung trong be3ab33. Nhóm nhận đây là thiếu sót. |
| Figma đã khớp app chưa? | Phần Export đã cập nhật. Nút Details ở màn Reference và các câu báo lỗi mới thì chưa. |
| Push không tới khi app đã tắt? | Máy Xiaomi/Redmi chặn app chạy nền nếu chưa bật Autostart. Android cũng chặn push cho app bị Force stop. |
