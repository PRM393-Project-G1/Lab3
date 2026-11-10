# Kịch bản thuyết trình Lab 3 – Realtron

Đi kèm bộ slide `Lab03_G1_slides.pdf` (32 slide). Nói hết khoảng 23 phút, chưa tính demo trên máy.

Mỗi slide gồm 3 phần:

- **Ý chính:** câu phải nói. Nếu thiếu thời gian, chỉ nói câu này.
- **Lời nói:** nói tự nhiên, không cần thuộc từng chữ. Chữ trong `[ngoặc vuông]` là hành động: chỉ vào đâu, bấm gì.
- **Nếu thầy hỏi:** câu trả lời ngắn, có chỉ chỗ trong code để mở ra khi cần.

Thầy chấm nặng phần công nghệ và giải thích. Từ slide 6, mỗi công nghệ đi theo ba phần: **What–Why** (là gì, vì sao Realtron cần) → **How** (chạy thế nào) → **Where–When** (nằm ở đâu trong code, chạy lúc nào, bằng chứng). Ba nhãn ở góc trên bên phải slide cho biết đang ở phần nào. Slide What–Why nói ngắn; nếu thiếu thời gian, chỉ nói **Ý chính** của slide đó.

---

## Slide 1 · Realtron (40 giây)

**Ý chính:** Realtron giúp người đọc hiểu nhanh một bài báo qua danh sách tham khảo của nó.

**Lời nói:**

> Em chào thầy. Nhóm em là PRM393-Project-G1, gồm [tên các bạn].
>
> Sản phẩm của nhóm là Realtron, một app Android viết bằng Flutter. Người dùng nhập mã arXiv của một bài báo. Backend của nhóm kiểm tra từng reference trong bài bằng RefChecker, rồi gom các reference thành cây chủ đề bằng Saffron.
>
> Năm nhãn trên slide là năm trạng thái app gán cho mỗi reference: Verified là khớp với nguồn, Warning là lệch nhỏ về metadata, Error là sai thông tin chính, Hallucinated là nhiều khả năng bịa, còn Unverified là chưa kiểm được.
>
> Ở Lab 3, app dùng sáu dịch vụ Firebase, có kiểm thử end-to-end bằng Google ARTEMIS và rà soát mã bằng AI. `[chỉ ảnh điện thoại]` Đây là app thật: màn Paper Overview đang mở sheet xuất báo cáo.

---

## Slide 2 · Đề tài và persona (1 phút)

**Ý chính:** Persona là Linh, người đọc bài lạ trên điện thoại. Thành công khi ít nhất 4/5 người tự làm xong flow trong 2 phút.

**Lời nói:**

> Vấn đề nhóm em giải quyết: khi đọc một bài lạ, người đọc phải lướt 40 đến 60 reference. Họ không biết nên đọc nền tảng nào trước, cũng không biết reference nào có thật. Nghiên cứu Phantom References cho thấy khoảng 1/20 bài được nhận ở NeurIPS và USENIX Security 2025 có ít nhất 2 reference nhiều khả năng bịa.
>
> Persona chính là Linh, sinh viên năm cuối hoặc học viên cao học. Linh đọc trên điện thoại, thời gian ngắt quãng, mạng 4G chập chờn. Vì Linh hay mất mạng nên flow nào trong app cũng có nhánh lỗi riêng.
>
> `[chỉ cột bên phải]` Ba flow giữ nguyên từ Lab 2. Flow A là phân tích một bài. Flow B là tìm chủ đề yếu rồi mở reference có vấn đề trong chủ đề đó. Flow C là xem lại lịch sử và xuất báo cáo PDF.
>
> Tiêu chí thành công cũng lấy từ Lab 2: ít nhất 4 trên 5 người tự làm xong mà không cần trợ giúp, trong 2 phút kể từ khi màn Overview hiện ra.

**Nếu thầy hỏi:**

- *"Chủ đề yếu tính thế nào?"* Một chủ đề là yếu khi tỉ lệ (Hallucinated + Error) trên tổng số reference đạt `weak_topic_threshold` (mặc định 0.5), và chủ đề có ít nhất `weak_topic_min_refs` reference (mặc định 3). Warning không tính, vì chỉ là khác biệt nhỏ. Quy tắc nằm ở `lib/models/weak_topic_rule.dart`; hai ngưỡng đổi được qua Remote Config.
- *"Persona có phỏng vấn người thật không?"* Chưa ạ. Đây là proto-persona nhóm dựng từ nhóm người dùng mục tiêu.

---

## Slide 3 · Figma và app (1 phút)

**Ý chính:** App làm đủ 12 màn của Figma. Chỗ nào lệch đều có lý do, ghi trong `docs/design-traceability.md`.

**Lời nói:**

> `[chỉ bên trái]` Đây là page Final UI trên Figma, gồm 12 màn và các biến thể trạng thái. `[chỉ bên phải]` Đây là app thật: màn đăng nhập ở trạng thái huỷ, màn Analyze, và sheet Export đang báo Uploaded.
>
> App làm đủ 12 màn và 3 flow kèm nhánh lỗi. 22 component trên Figma đều thành widget trong code. Chỗ nào app khác Figma, nhóm em ghi lý do ở mục 4 của design-traceability. Ba chỗ chính nằm trong bảng.
>
> Thứ nhất, Figma thiết kế upload báo cáo lên Cloud Storage. Gói Spark không có bucket, nên app mặc định lưu PDF trên máy, bật cờ `enable_cloud_upload` thì upload lên Cloudinary, như thầy cho phép.
>
> Thứ hai, vì thế trạng thái lỗi đổi tên từ Upload failed thành Export failed, vì lỗi có thể đến từ khâu tạo hoặc lưu PDF chứ không chỉ khâu upload.
>
> Thứ ba, ở màn Reference, Figma chỉ có dialog Likely fabricated tự mở ra. Người dùng đóng dialog xong thì không xem lại được, nên app thêm một banner có nút Details để mở lại.

**Nếu thầy hỏi:**

- *"Figma đã cập nhật theo app chưa?"* Hai thay đổi ở phần Export đã được cập nhật trên Figma. Nút Details ở màn Reference và các câu báo lỗi mới thêm (như Sign-in failed, Couldn't save) thì chưa, nhóm em sẽ bổ sung. Cột "Figma đã cập nhật?" trong design-traceability ghi rõ từng mục.

---

## Slide 4 · Kiến trúc MVVM (1 phút 15 giây)

**Ý chính:** Bốn tầng, phụ thuộc chỉ đi xuống. Chỉ tầng service được chạm tới SDK và mạng.

**Lời nói:**

> Kiến trúc là MVVM với Provider. `[chỉ từ trên xuống]` Phụ thuộc chỉ đi xuống, tầng dưới không biết tầng trên.
>
> View nằm trong `screens` và `widgets`. View chỉ dựng UI từ state và chuyển thao tác của người dùng xuống ViewModel.
>
> ViewModel có 13 lớp, kế thừa ChangeNotifier. ViewModel giữ state, gọi service, ghi Analytics, rồi gọi notifyListeners để View dựng lại.
>
> Tầng service và repository bọc Firebase SDK, HTTP tới backend và Cloudinary sau interface, đồng thời đổi exception của SDK thành lỗi của app.
>
> Dưới cùng là Firebase, backend chạy trên laptop qua Tailscale, và Cloudinary.
>
> `[chỉ cột phải]` Nhóm em giữ kiến trúc bằng bốn quy tắc:
>
> - Widget không gọi SDK.
> - Không có logic trong `build()`.
> - Mỗi màn có một state model. `ViewState` là sealed class với bốn trạng thái Loading, Empty, Failure, Data. Vì là sealed, screen `switch` mà thiếu trạng thái nào thì code không biên dịch được.
> - Service được inject: `lib/app_dependencies.dart` là nơi duy nhất tạo lớp cụ thể, nên khi test, nhóm truyền service giả vào ViewModel.

**Nếu thầy hỏi:**

- *"Giải thích một ViewModel."* Dùng phần [AnalyzeViewModel](#3-giải-thích-một-viewmodel-analyzeviewmodel) ở cuối file.
- *"Vì sao chọn Provider mà không chọn Riverpod?"* Đề cho phép cả hai. Nhóm đã dùng Provider ở Lab 2 nên giữ nguyên.
- *"Có dùng design pattern nào?"* Có Repository (`AnalysisRepository`), Adapter (các lớp `Firebase…Service`, `CloudinaryStorageService`), Dependency Injection với composition root (`app_dependencies.dart`), Observer (ChangeNotifier) và Specification (`WeakTopicRule`). Bảng đầy đủ nằm ở `docs/architecture.md` mục 10.

---

## Slide 5 · Design system trong code (50 giây)

**Ý chính:** Token → theme → 22 widget. Screen không viết mã màu trực tiếp.

**Lời nói:**

> Design system có ba tầng.
>
> Tầng token gồm màu, khoảng cách, bo góc, nằm ở một chỗ duy nhất là `lib/theme/app_tokens.dart`.
>
> Tầng theme, file `app_theme.dart`, dựng ColorScheme, TextTheme (Source Serif 4 cho tiêu đề, Inter cho nội dung) và theme cho button, input, card. Năm màu trạng thái reference không có trong ColorScheme chuẩn, nên nhóm đưa vào ThemeExtension `StatusColors`. Screen gọi `context.status(...)` chứ không viết mã màu.
>
> Tầng cuối là 22 component trên Figma, thành 22 widget trong `lib/widgets`.
>
> Accessibility được kiểm bằng widget test: không tràn ở màn 360 và 412 dp với cỡ chữ 100% và 130%, và vùng chạm tối thiểu 48 dp. Viền ô nhập ban đầu chỉ đạt contrast 1.42:1, nhóm đổi sang màu đạt 4.55:1.
>
> *(Chuyển)* Phần tiếp theo là các công nghệ trong app. Mỗi công nghệ nói theo ba phần: What–Why, How, Where–When; nhãn ở góc trên bên phải slide cho biết đang ở phần nào.

**Nếu thầy hỏi:**

- *"Vì sao phải đổi màu viền?"* WCAG 1.4.11 yêu cầu viền của thành phần giao diện có contrast ít nhất 3:1 so với nền. Màu cũ 1.42:1 không đạt.

---

## Slide 6 · Authentication: What–Why (30 giây)

**Ý chính:** Firebase Auth cấp uid. Router, backend, rules và mọi dịch vụ khác đều dựa trên uid đó.

**Lời nói:**

> What: Authentication là dịch vụ xác thực của Firebase. Google chứng minh người dùng là ai; Firebase cấp cho tài khoản một uid cố định và một ID token dạng JWT, hết hạn sau 1 giờ.
>
> Why: lịch sử phân tích, báo cáo và thông báo là của riêng từng người, nên app phải biết ai đang dùng. Backend chạy trên laptop qua Tailscale, chỉ nhận lệnh từ người đã đăng nhập. Firestore rules cần `request.auth.uid`. Nhóm chọn Google Sign-In vì persona Linh đã có tài khoản Google.
>
> `[chỉ sơ đồ]` Cùng một uid đi qua mọi dịch vụ: `users/{uid}` trên Firestore, `reports/{uid}` trên Cloudinary, `fcmTokens` của FCM, `setUserId` của Analytics, `setUserIdentifier` của Crashlytics, và `verify_id_token` ở backend.

**Nếu thầy hỏi:**

- *"uid khác ID token thế nào?"* uid là định danh cố định của tài khoản. ID token là JWT có chữ ký của Google, chứa uid và hết hạn sau 1 giờ. Server verify chữ ký để biết người gọi đúng là chủ của uid đó.

---

## Slide 7 · Authentication: How (45 giây)

**Ý chính:** Google chỉ chứng minh người dùng là ai. Firebase cấp uid, và mọi thứ phía sau (router, backend, rules) đều dựa trên uid đó.

**Lời nói:**

> Nguyên lý gồm bốn bước.
>
> Một: Google Sign-In chỉ chứng minh người dùng là ai với Google, rồi trả về Google idToken.
>
> Hai: app đổi idToken đó lấy phiên Firebase bằng `signInWithCredential`. Firebase cấp một uid cố định cho tài khoản, và một Firebase ID token dạng JWT, SDK tự làm mới.
>
> Ba: AuthViewModel nghe `authStateChanges`, go_router dựa vào đó để chuyển hướng. Chưa đăng nhập thì mọi route về `/sign-in`; đã đăng nhập thì vào `/analyze`.
>
> Bốn: khi gọi backend, app gửi kèm ID token. Backend không tin uid do app gửi lên, mà verify token bằng Admin SDK để tự lấy uid. Firestore rules cũng so `request.auth.uid` với uid trong đường dẫn.
>
> Về lỗi: `[chỉ ô đỏ]` huỷ ở account picker thì app hiện banner Sign-in cancelled. Mất mạng thì báo offline chứ không crash. Đăng xuất thì app ghi sự kiện logout, xoá FCM token của máy, rồi signOut cả Google lẫn Firebase. `[chỉ ba ảnh]` Ba ảnh là ba trạng thái đó.

**Nếu thầy hỏi:**

- *"Đăng xuất khi mất mạng thì sao?"* `deleteToken()` chỉ chờ tối đa 5 giây. Lỗi thì ghi non-fatal `delete_token`, còn signOut vẫn chạy. (`ProfileViewModel.signOut`)
- *"Hàm nào đổi token?"* `FirebaseAuth.signInWithCredential(GoogleAuthProvider.credential(idToken: …))` trong `lib/firebase/auth_service.dart`.

---

## Slide 8 · Authentication: Where–When (40 giây)

**Ý chính:** Sáu thời điểm trong một phiên dùng app; backend chỉ tin uid lấy từ ID token.

**Lời nói:**

> `[chỉ bảng]` Bảng đi theo một phiên dùng app.
>
> Mở app hoặc đổi màn: `gateRedirect` trong `app_router.dart` chạy mỗi lần điều hướng, với `refreshListenable` là AuthViewModel.
>
> Bấm Continue with Google: `AuthViewModel.signIn()` gọi `signInWithGoogle()`; huỷ thì trả về `SignInResult.cancelled` và màn hình hiện banner.
>
> Vừa có user: `_onUser()` gắn uid cho Analytics và Crashlytics, gọi `ensureUser` để tạo `users/{uid}`, và bật messaging để lưu token FCM.
>
> Mỗi lệnh gửi backend: `api_client.dart` gắn header `Authorization: Bearer <ID token>`; backend gọi `verify_token()` trong `store.py`.
>
> Mỗi lần đọc ghi Firestore: rules `isOwner(uid)`. Đăng xuất: `ProfileViewModel.signOut()`.
>
> `[chỉ chuỗi bên phải]` ID token đi từ `AuthService.idToken()`, qua header, tới `verify_id_token()` ở backend. `[chỉ ảnh Console]` Console của project realtron-874ac có hai tài khoản Google đã đăng nhập.

**Nếu thầy hỏi:**

- *"Chưa đăng nhập mà mở thẳng một route thì sao?"* `gateRedirect` trả về `/sign-in` cho mọi path khi `signedIn` là false; khi trạng thái đăng nhập đổi, router chạy lại redirect.

---

## Slide 9 · Firestore: What–Why và How (1 phút)

**Ý chính:** App chỉ gọi backend để ra lệnh; backend ghi kết quả vào Firestore; app nghe realtime và có cache offline.

**Lời nói:**

> What: Firestore là cơ sở dữ liệu NoSQL của Firebase, document nằm trong collection. App nghe thay đổi theo thời gian thực và có cache trên máy.
>
> Why: backend chạy trên laptop, có lúc tắt. Kết quả nằm ở Firestore nên bài đã phân tích vẫn mở được. Màn Analyzing nghe tiến độ realtime thay vì poll backend. Dữ liệu từng người nằm dưới `users/{uid}`.
>
> How, theo sơ đồ: `[chỉ sơ đồ]` một, app gọi `POST /api/analyses` kèm ID token. Hai, backend dùng Admin SDK ghi `status` và `progress` vào `analyses/{id}`. Ba, `ProgressViewModel` nghe `snapshots()`, nên stepper chạy theo. Bốn, backend ghi `references`, `topics`, rồi `status = done`. Năm, Overview đọc kết quả qua `AnalysisRepository`; lần sau đọc được từ cache.
>
> `[chỉ hai ô]` Mất mạng: SDK trả dữ liệu từ cache, lệnh ghi xếp hàng chờ mạng. Rules: `users/{uid}/**` chỉ chủ sở hữu; `analyses/**` app chỉ đọc.

**Nếu thầy hỏi:**

- *"Firestore có trong 6 dịch vụ đề yêu cầu không?"* Không. Đề yêu cầu Auth, Storage, FCM, Analytics, Crashlytics, Remote Config. Firestore là phần nhóm thêm để tách app khỏi backend.
- *"Lệnh ghi offline thì sao?"* SDK giữ lệnh trong hàng đợi local; Future của lệnh ghi chỉ hoàn tất khi server xác nhận. `await` nó trên đường chuyển màn sẽ làm spinner quay mãi, đó là CR-01.

---

## Slide 10 · Firestore: Where–When (40 giây)

**Ý chính:** App ghi dữ liệu của người dùng; backend ghi kết quả; rules chặn app ghi `analyses`.

**Lời nói:**

> `[chỉ bảng]` `users/{uid}` do app tạo lần đầu đăng nhập (`ensureUser`) và thêm token (`addFcmToken`); backend đọc token để gửi push. `library` do `LibraryRepository` ghi mỗi lần Analyze, đổi tên, xoá; màn History và Recent đọc qua `watchLibrary`.
>
> `reports` do `addReport()` ghi sau khi upload PDF. `notifications` do backend ghi khi job xong; app chỉ đổi trường `read`. `analyses` cùng `references`, `topics` do backend ghi; Analyzing, Overview, Topics, Reference đọc qua `analysis_repository.dart`.
>
> `[chỉ đoạn rules]` `allow write: if false` cho `analyses/**`. Tên collection khai báo một chỗ trong `firestore_schema.dart`.

**Nếu thầy hỏi:**

- *"Backend ghi được analyses khi rules cấm?"* Admin SDK dùng service account nên bỏ qua security rules; rules chỉ áp dụng cho client.

---

## Slide 11 · Storage → Cloudinary: What–Why (30 giây)

**Ý chính:** Báo cáo cần link; Spark không có bucket; interface StorageService làm việc đổi nhà cung cấp chỉ tốn một provider.

**Lời nói:**

> What: dịch vụ lưu file trên cloud và trả về URL. Đề dùng Firebase Cloud Storage; Realtron dùng Cloudinary.
>
> Why: báo cáo PDF cần một link để mở trên laptop hoặc gửi đi. Đề yêu cầu hiện tiến độ và mỗi người chỉ ghi được `reports/{uid}/`. Secret của Cloudinary không được nằm trong APK.
>
> `[chỉ hai thẻ]` Gói Spark không có bucket nên nhóm dùng Cloudinary, như thầy cho phép. `FirebaseStorageService` và `storage.rules` vẫn giữ trong repo. `[chỉ khung code]` ViewModel chỉ biết `StorageService`; `app_dependencies.dart` chỉ đổi một provider.

**Nếu thầy hỏi:**

- *"Sao không để API secret trong app?"* APK giải nén được; ai có secret thì ghi hoặc xoá được mọi asset của tài khoản Cloudinary.

---

## Slide 12 · Storage → Cloudinary: How (45 giây)

**Ý chính:** Signed upload: backend ký cho `reports/{uid}/…` với uid lấy từ token; secret không rời backend.

**Lời nói:**

> Năm bước: ExportViewModel tạo PDF qua ReportService. App gọi `POST /api/uploads/signature` kèm ID token. Backend lấy uid từ token, ký cho `public_id = reports/{uid}/{file}`. App gửi multipart thẳng lên Cloudinary, đếm byte để hiện phần trăm. Nhận `secure_url`, ghi metadata vào `users/{uid}/reports`, hiện Uploaded và Copy link.
>
> `[chỉ khung code]` Chữ ký là SHA-1 của `public_id`, `timestamp` và secret. Cloudinary tính lại: đúng thư mục thì khớp; sửa `public_id` sang uid khác thì chữ ký sai và bị từ chối. Chữ ký kèm timestamp nên chỉ dùng trong khoảng 1 giờ.
>
> Lỗi: backend tắt, thiếu `CLOUDINARY_*` (503) hoặc quá 30 giây thì app báo Export failed và ghi non-fatal `export_report`; PDF vẫn còn trên máy.

**Nếu thầy hỏi:**

- *"Chữ ký dùng lại được không?"* Chỉ trong khoảng 1 giờ và chỉ cho đúng một `public_id`.
- *"Backend thiếu cấu hình thì sao?"* `CloudinarySigner.from_env()` trả None, endpoint trả 503.

---

## Slide 13 · Storage → Cloudinary: Where–When (40 giây)

**Ý chính:** Luồng bắt đầu ở nút Report; cờ `enable_cloud_upload` quyết định có upload hay không.

**Lời nói:**

> `[chỉ bảng]` Bấm Report ở Overview: `ExportViewModel.start()` tạo PDF và lưu trên máy. Dòng 73 kiểm `_remoteConfig.enableCloudUpload`: false thì dừng ở Saved on device, true thì `_upload()`.
>
> Trước upload là chữ ký từ `uploads.py`. Khi upload, `cloudinary_storage_service.dart` dùng `_ProgressRequest` để đếm byte, timeout 30 giây. Xong thì `addReport()`. Lúc khởi động, `app_dependencies.dart` gắn `CloudinaryStorageService`.
>
> `[chỉ ba ảnh]` Bằng chứng: sheet Uploaded, PDF 8.86 KB trên Cloudinary dưới `reports/{uid}/`, và bản ghi trong Firestore.

> **Trước khi demo upload:** bật `enable_cloud_upload = true` trên Remote Config (mặc định `false`), và backend phải có đủ `CLOUDINARY_*` trong `.env`.

---

## Slide 14 · FCM: What–Why (30 giây)

**Ý chính:** Phân tích mất 2–10 phút; push "Analysis done" đưa người dùng về đúng bài. FCM token là địa chỉ của một bản cài app.

**Lời nói:**

> What: FCM là dịch vụ của Google đẩy thông báo từ server xuống từng bản cài app, kể cả khi app chạy nền hoặc đã tắt. `[chỉ ảnh]` Đây là push thật trên máy.
>
> Why: một bài chưa có kết quả mất khoảng 2 đến 10 phút. Người dùng không phải ngồi ở màn Analyzing: rời app, có push, chạm vào là mở đúng Paper Overview.
>
> `[chỉ 3 thẻ]` Ba câu thầy hỏi về token. Token là chuỗi định danh một bản cài app trên một máy, không phải tài khoản. FCM server cấp khi SDK gọi `getToken()`; đổi khi cài lại app hoặc xoá dữ liệu, app nghe `onTokenRefresh`. SDK tự giữ token trên máy; app đẩy lên `users/{uid}.fcmTokens` để server biết gửi tới đâu, và `deleteToken()` khi đăng xuất.

---

## Slide 15 · FCM: How (45 giây)

**Ý chính:** Token lên Firestore bằng `arrayUnion`; backend dùng service account và Admin SDK gửi multicast.

**Lời nói:**

> `[chỉ luồng 5 bước]` App gọi `getToken()`, FCM cấp registration token. App `arrayUnion` vào `users/{uid}.fcmTokens`. Khi job xong, `notify_done()` đọc mảng token. Admin SDK gọi `send_each_for_multicast` với tokens, notification và data. FCM đẩy xuống máy.
>
> `[chỉ ô trái]` Gửi message cần quyền của project, tức service account, nên chỉ server gửi được. Phần notification thì hệ thống tự hiện; phần data mang `analysisId`. Thử nhanh: Console › Messaging › Send test message, dán token.
>
> `[chỉ bảng]` Ba trạng thái: đang mở thì hệ thống không hiện, app nghe `onMessage` và tự hiện snackbar; chạy nền thì chạm vào đi qua `onMessageOpenedApp`; đã tắt thì chạm vào đi qua `getInitialMessage` lúc khởi động. Android 13 trở lên phải `requestPermission()`. Token chết thì backend `ArrayRemove`.

**Nếu thầy hỏi:**

- *"Sao lưu token dạng mảng?"* Một user nhiều máy, mỗi máy một token; `arrayUnion` không tạo bản trùng.
- *"Notification message khác data message chỗ nào?"* Notification do hệ thống hiện khi app chạy nền hoặc đã tắt; data chỉ app đọc, dùng `analysisId` để điều hướng.

---

## Slide 16 · FCM: Where–When trong code (40 giây)

**Ý chính:** Sáu thời điểm: đăng nhập, token đổi, job xong, token chết, chạm push, đăng xuất.

**Lời nói:**

> `[chỉ bảng]` Vừa đăng nhập: `AuthViewModel._onUser()` gọi `messaging.start()`: `requestPermission`, `getToken`, rồi `addFcmToken` với `arrayUnion`. Token đổi: `onTokenRefresh` đẩy token mới.
>
> Job xong: `jobs.py` gọi `store.notify_done()`: ghi `users/{uid}/notifications` rồi `send_each_for_multicast`; token nào FCM báo Unregistered thì `ArrayRemove`.
>
> Chạm push hoặc nút View trên snackbar: `main.dart` `_openPush()` ghi `open_notification` và `go('/analyses/{id}')`. Bấm Sign out: `deleteToken()` với timeout 5 giây.
>

**Nếu thầy hỏi:**

- *"Đăng xuất rồi token trong Firestore có bị xoá không?"* `deleteToken()` vô hiệu token ngay; lần gửi sau FCM báo token không còn và backend `ArrayRemove` khỏi mảng.

---

## Slide 17 · FCM: Where–When, bằng chứng 3 trạng thái (45 giây + demo)

**Ý chính:** Push đến được ở cả ba trạng thái; chạm vào mở đúng bài nhờ `analysisId`.

**Lời nói:**

> Ba trạng thái theo đề. Đang mở: hệ thống không tự hiện, app nghe `onMessage` và hiện snackbar có nút View. Chạy nền và đã tắt: hệ thống tự hiện từ phần notification. Chạm từ nền đi qua `onMessageOpenedApp`; chạm khi đã tắt đi qua `getInitialMessage` lúc khởi động; cả hai đọc `analysisId` để mở đúng Paper Overview.
>
> Danh sách trong app đọc `users/{uid}/notifications`, nên vẫn có khi người dùng từ chối quyền thông báo. Ảnh chụp trên BlueStacks; em xin demo trên điện thoại thật.

**Demo:**

1. Mở Firestore, vào `users/{uid}`, copy token trong `fcmTokens`.
2. Console → Messaging, tạo thông báo. Ở Additional options, thêm custom data `analysisId = 1706.03762`.
3. Send test message, dán token. Gửi ba lần: app đang mở, app chạy nền, app đã tắt (vuốt khỏi đa nhiệm, **không** Force stop).

---

## Slide 18 · Analytics: What–Why (30 giây)

**Ý chính:** Mỗi sự kiện trả lời một câu hỏi sản phẩm, đo được tiêu chí thành công của Lab 2.

**Lời nói:**

> What: Analytics ghi sự kiện, gồm tên và tham số, khi người dùng làm một việc trong app.
>
> Why: Lab 2 đặt tiêu chí ít nhất 4/5 người tự làm xong flow chính trong 2 phút kể từ khi Overview hiện ra. Sự kiện ở từng bước cho biết người dùng thật dừng ở đâu: nhiều `search` mà ít `view_topic` nghĩa là người dùng dừng ở Overview.
>
> `[chỉ bảng]` Chín sự kiện, mỗi sự kiện một câu hỏi. Kế hoạch viết trước khi code, ở `docs/analytics-plan.md`; dùng tên khuyến nghị (`login`, `search`) khi có, còn lại snake_case.

---

## Slide 19 · Analytics: How (40 giây)

**Ý chính:** ViewModel → AnalyticsService → SDK gom lô; debug mode gửi ngay lên DebugView.

**Lời nói:**

> `[chỉ hàng trên]` ViewModel gọi hàm của `AnalyticsService`, ví dụ `logSearch(id, cacheHit)`. Service gọi `logEvent(name, params)`. SDK gom sự kiện theo lô và gửi định kỳ, nên báo cáo Events có thể chậm tới 24 giờ.
>
> `[chỉ ô xanh]` Bật debug mode bằng `adb shell setprop debug.firebase.analytics.app vn.fpt.prm393.realtron` thì sự kiện gửi ngay lên DebugView. Sau đăng nhập app gọi `setUserId(uid)`; không gửi email hay tên.
>
> `[chỉ ô dưới]` Lỗi thật: `notification_open` là tên Firebase giữ cho FCM nên SDK ném "Event name is reserved". Test với service giả không bắt được; Crashlytics bắt được, stack trace chỉ tới `_openPush` trong `main.dart`. Nhóm đổi thành `open_notification` ở commit fee2fe3.

**Nếu thầy hỏi:**

- *"Sao trên trang Events chưa thấy sự kiện?"* Báo cáo chậm tới 24 giờ; DebugView mới là realtime.
- *"Có ghi thông tin cá nhân không?"* Không; `search_term` chỉ là arXiv ID công khai.

---

## Slide 20 · Analytics: Where–When (40 giây)

**Ý chính:** Mỗi sự kiện bắn ở đúng một bước, trong ViewModel của màn đó.

**Lời nói:**

> `[chỉ bảng]` `login` khi đăng nhập thành công, trong AuthViewModel. `search` khi bấm Analyze, kèm `cache_hit`. `view_analysis` khi Overview tải xong, chỉ một lần nhờ cờ `_logged`. `filter_weak_topics` khi bật chip Weak. `view_topic`, `view_reference` khi mở chi tiết. `export_report` khi PDF lưu hoặc upload xong. `open_notification` ở `main.dart` khi chạm push, và ở NotificationsViewModel khi chạm thông báo trong danh sách. `logout` khi Sign out.
>
> `[chỉ hai ảnh]` DebugView của realtron-874ac có các sự kiện này và user_id đã đặt.

**Nếu thầy hỏi:**

- *"Chi tiết ở đâu?"* `docs/analytics-plan.md`; code ở `lib/firebase/analytics_service.dart`.

---

## Slide 21 · Crashlytics: What–Why (30 giây)

**Ý chính:** Lỗi xảy ra trên máy người dùng, nơi nhóm không thấy. Fatal và non-fatal đều về Console kèm ngữ cảnh.

**Lời nói:**

> What: Crashlytics thu báo cáo crash và lỗi từ máy người dùng, kèm stack trace, thiết bị, user ID và custom key.
>
> Why: app chạy trên điện thoại người dùng, 4G chập chờn, backend có thể tắt. Lỗi đã báo cho người dùng vẫn cần đếm. Và Crashlytics bắt được lỗi mà test với service giả bỏ sót, như tên sự kiện bị giữ riêng.
>
> `[chỉ hai ô]` Fatal: app tắt, báo cáo gửi ở lần mở sau; ví dụ Test crash ở Profile. Non-fatal: app vẫn chạy, người dùng thấy thông báo; ví dụ `ftp://abc` ở màn Connect, http client ném Unsupported scheme, màn hình hiện Can't reach server.

**Nếu thầy hỏi:**

- *"Non-fatal để làm gì?"* Người dùng đã được báo, nhưng nhóm vẫn cần biết lỗi xảy ra bao nhiêu lần, với ai, trong hoàn cảnh nào.

---

## Slide 22 · Crashlytics: How (40 giây)

**Ý chính:** `installHandlers()` lúc khởi động bắt fatal; ViewModel gọi `recordNonFatal(reason)`; uid và custom key đi kèm.

**Lời nói:**

> Một: lúc khởi động, `app_dependencies.dart` gọi `installHandlers()`, gắn `FlutterError.onError` và `PlatformDispatcher.onError` vào Crashlytics; lỗi nào lọt ra ngoài, kể cả lỗi async, đều báo fatal.
>
> Hai: ViewModel bắt lỗi, báo cho người dùng trước, rồi gọi `recordNonFatal(error, stack, reason)`, tức `recordError` với `fatal: false`.
>
> Ba: `setUserIdentifier(uid)` khi có user, và `setCustomKey('server_reachable', …)` ở màn Connect.
>
> Bốn: crash lưu trên máy, gửi ở lần mở sau; vài phút sau hiện trên Console. `[chỉ sơ đồ]` Sơ đồ là hai đường của một lỗi. ViewModel gọi interface `CrashlyticsService`, nên test truyền bản giả để kiểm lỗi có được báo.

**Nếu thầy hỏi:**

- *"Sao phải mở lại app mới thấy crash?"* App chết lúc crash nên không gửi được; SDK lưu báo cáo và gửi ở lần khởi động sau.

---

## Slide 23 · Crashlytics: Where–When (40 giây + demo)

**Ý chính:** Một handler lúc khởi động; tám ViewModel báo non-fatal, mỗi chỗ một reason.

**Lời nói:**

> `[chỉ bảng]` Chỗ bắt crash duy nhất là `app_dependencies.dart`. Tám ViewModel báo non-fatal: Analyze (`load_recent`, `analyze_submit`, `touch_library`), Auth (`sync_user`), Connect (`test_server`, kèm key `server_reachable`), Overview, History, Export, Notifications, Profile.
>
> `[chỉ ảnh Issues]` Issues có non-fatal `health` từ đường lỗi thật ftp, hai test crash và lỗi tên sự kiện. `[chỉ hai ảnh nhỏ]` Key `server_reachable = false`, `flutter_error_reason = thrown test_server`, thiết bị và user ID.
>
> `[chỉ ô dưới]` Test crash và Log error nằm riêng ở Profile › Firebase demo, ngoài luồng dùng bình thường, đúng yêu cầu "khu vực trình diễn".

**Demo:**

1. Profile → Firebase demo → **Test crash** → bấm **Crash**. App tắt.
2. Mở lại app, bấm **Log error** để tạo thêm một non-fatal.
3. Vài phút sau, mở Console → Crashlytics.

**Nếu thầy hỏi:**

- *"Admin xem ở đâu?"* Hiện nhóm dev xem trên Firebase Console; trang admin là phần của Final Assignment.

---

## Slide 24 · Remote Config: What–Why (30 giây)

**Ý chính:** Đổi hành vi không cần phát hành bản mới; năm khoá, mặc định giữ ở hai nơi.

**Lời nói:**

> What: bộ tham số khoá–giá trị lưu trên Firebase; app đọc khi chạy, sửa trên Console rồi Publish là app nhận giá trị mới.
>
> Why: ngưỡng chủ đề yếu cần chỉnh theo dữ liệu thật; build và cài lại APK thì quá chậm. Tắt nhanh tính năng lỗi như nút Report. Chỉ bật upload Cloudinary khi backend đã có khoá.
>
> `[chỉ bảng]` Năm khoá: `weak_topic_threshold` 0.5, `weak_topic_min_refs` 3, `max_recent_checks` 10, `enable_report_export` true, `enable_cloud_upload` false. Mặc định nằm trong `remote_config_service.dart` và `firebase/remote-config-defaults.json`; TC-11 kiểm năm giá trị này trên Profile.

---

## Slide 25 · Remote Config: How (40 giây)

**Ý chính:** setDefaults → fetchAndActivate → onConfigUpdated → notifyListeners; offline thì dùng giá trị đã kích hoạt hoặc mặc định.

**Lời nói:**

> `setDefaults` nạp năm giá trị mặc định. Khi mở app, `fetchAndActivate` tải giá trị mới: `minimumFetchInterval` là 1 giờ ở release, 0 ở debug; `fetchTimeout` 10 giây. App nghe `onConfigUpdated`: Console vừa Publish là app nhận, gọi `activate()` rồi `notifyListeners()` để ViewModel và màn hình vẽ lại.
>
> `[chỉ sơ đồ]` Thứ tự ưu tiên: bản đã Publish; nếu chưa tải được thì giá trị đã kích hoạt, lưu trên máy; nếu chưa từng có thì mặc định trong code. Offline thì `fetchAndActivate` lỗi được bỏ qua, app không kẹt.

**Nếu thầy hỏi:**

- *"Sao đổi rồi mà app chưa đổi?"* Realtime listener thường vài giây; mất kết nối realtime thì lấy ở lần mở sau; release còn trong khoảng cache 1 giờ.

---

## Slide 26 · Remote Config: Where–When (40 giây + demo)

**Ý chính:** Mỗi khoá có ViewModel đọc; hai thay đổi nhìn thấy được.

**Lời nói:**

> `[chỉ bảng]` `max_recent_checks`: AnalyzeViewModel cắt danh sách Recent. `enable_report_export`: `OverviewViewModel.canExport` quyết định nút Report. Hai khoá chủ đề yếu: Overview, TopicMap, TopicDetail, Export dùng `weakTopicRule`. `enable_cloud_upload`: ExportViewModel. Profile hiện cả năm khoá qua `RemoteConfigRow`.
>
> `app_dependencies.dart` gọi `init()` lúc khởi động; các ViewModel `addListener` vào RemoteConfigService.
>
> `[chỉ 4 ảnh]` `max_recent_checks` 10 → 1 thì Recent còn 1 thẻ; `enable_report_export` true → false thì mất nút Report. Console version 5 với hai giá trị đã đổi.

**Demo:** làm theo phần [Đổi một giá trị Remote Config trực tiếp](#2-đổi-một-giá-trị-remote-config-trực-tiếp) ở cuối file.

---

## Slide 27 · ARTEMIS: What–Why (30 giây)

**Ý chính:** Agent AI điều khiển máy thật, đi qua cả màn native mà unit/widget test với service giả không chạm tới.

**Lời nói:**

> What: ARTEMIS là agent AI mã nguồn mở của Google; nhận chỉ dẫn bằng ngôn ngữ tự nhiên, điều khiển Android qua ADB.
>
> Why: 141 test Flutter và 72 test backend dùng service giả, không chạm Firebase, backend hay màn ngoài Flutter. Nhiều bước nằm ngoài Flutter: account picker, share từ Chrome, mở push từ khay, mở PDF. Đề yêu cầu ít nhất 10 ca, mỗi ca 3 lần, có nhánh lỗi và tương tác native.
>
> `[chỉ 4 số]` 19 ca: 9 happy path, 5 nhánh lỗi, 5 native.

**Nếu thầy hỏi:**

- *"Tương tác native là gì?"* Màn không do Flutter vẽ: chọn tài khoản Google, share sheet của Chrome, notification shade, app đọc PDF.

---

## Slide 28 · ARTEMIS: How (45 giây)

**Ý chính:** Agent trả JSON giá trị nó thấy; test assert từng giá trị, không tin SUCCESS.

**Lời nói:**

> pytest gửi một chỉ dẫn qua `ArtemisClient`: điểm bắt đầu, các bước, thứ phải thấy ở cuối. Agent đọc cây accessibility trước, chỉ nhìn ảnh khi cần, nên nhóm gắn Semantics label. Agent trả JSON, test assert từng giá trị. Mỗi test ít nhất 3 lần; Flash cho hồi quy, Pro cho phiên khám phá 15–30 phút.
>
> `[chỉ đoạn code]` TC-03 kiểm `screen_title`, `paper_title`, `references_count`, và `logged("search")`: fixture `logged` xoá Logcat rồi tìm sự kiện trong tag FA. Mỗi test tự đóng app trước (`cold_start` gọi `am force-stop`), nên không phụ thuộc thứ tự.

**Nếu thầy hỏi:**

- *"Tại sao phải chạy 3 lần?"* Agent không tất định; pass một lần có thể chỉ là may.
- *"Flash và Pro khác gì?"* Flash rẻ, nhanh cho hồi quy; Pro suy luận tốt hơn cho phiên khám phá không kịch bản.

---

## Slide 29 · ARTEMIS: Where–When (40 giây)

**Ý chính:** Code test nằm trong `e2e_test/`; chạy trước khi nộp; kết quả chưa có.

**Lời nói:**

> `[chỉ bảng]` `conftest.py` có fixture `cold_start`, `analytics_debug_mode`, `airplane_mode`, `send_push`. `realtron.py` có `Agent.check()` và các chỉ dẫn chung `signed_in()`, `open_paper()`. Tám file `test_*.py` chia theo flow. `summarize.py` in bảng pass rate từ `evidence/e2e/results.jsonl`; `exploratory.py` chạy phiên khám phá.
>
> `[chỉ ô trên]` Chạy `uv run pytest --count=3` trước khi nộp, trên điện thoại thật với Firebase và backend thật.
>
> `[chỉ ô vàng]` Trạng thái thật: suite đã viết đủ 19 ca nhưng chưa chạy trên thiết bị, nên chưa có pass rate và chưa có phiên khám phá.

> **Nếu chạy xong trước buổi thuyết trình**, cập nhật slide 29 và thay đoạn cuối bằng: "Kết quả: [X]/19 ca đạt 3/3. Ca [TC-…] chưa đạt vì [nguyên nhân], đã ghi vào `docs/test-plan.md`. Phiên khám phá bằng profile Pro tìm được [số] vấn đề."

---

## Slide 30 · AI code review: What–Why và How (50 giây)

**Ý chính:** AI tìm; nhóm quyết định Accepted, Modified hay Rejected với lý do dựa trên đề hoặc tác động đo được.

**Lời nói:**

> What: dùng AI đọc code và chỉ ra chỗ có thể sai, kèm file:dòng và kịch bản lỗi. Công cụ là Claude Code, lệnh `/code-review` mức high, chạy trên `lib/` ngày 05/11/2026.
>
> Why: lỗi ở đường lỗi như mất mạng, URL lạ dễ lọt qua test happy path; đề yêu cầu ít nhất 5 finding có quyết định và 3 fix có commit.
>
> `[chỉ 5 bước]` How: chạy lệnh; đọc lại code và tái hiện kịch bản, ví dụ CR-01 tắt mạng rồi bấm Analyze thì nút quay mãi; quyết định từng finding; sửa và commit (CR-01 ở 6c95c84, CR-02 đến CR-10 ở be3ab33); ghi vào `docs/code-review.md`. Kết quả: 10 finding, 8 Accepted, 2 Modified, 0 Rejected.

**Nếu thầy hỏi:**

- *"Review trên pull request nào?"* Nhóm review cả `lib/`, không qua pull request.
- *"Finding gồm những loại nào?"* Cả 10 đều là Bug.

---

## Slide 31 · AI code review: Where–When (40 giây)

**Ý chính:** Mỗi finding gắn với file:dòng, quyết định có lý do, và commit.

**Lời nói:**

> `[chỉ bảng]` CR-01 ở `analyze_view_model.dart:135`: `await` một lệnh ghi Firestore khi offline nên nút Analyze quay mãi. Accepted vì bảng điểm trừ lỗi spinner forever; fix là `unawaited`.
>
> CR-05 ở `utils/arxiv_id.dart:2`: ID kiểu cũ có `/` như `hep-th/9901001` làm hỏng đường dẫn Firestore, route và tên file. Modified: AI đề nghị sửa ba nơi, nhóm chặn ngay ở ô nhập vì backend chưa thống nhất cách mã hoá ID.
>
> `[chỉ ô dưới]` Khi nào: 05/11/2026, sau khi xong tính năng, chạy trên cả `lib/`.

**Nếu thầy hỏi (trả lời thật):**

- *"Mỗi fix có commit riêng không?"* CR-01 có commit riêng 6c95c84; CR-02 đến CR-10 chung commit be3ab33. Nhóm nhận đây là thiếu sót.

---

## Slide 32 · Khó khăn, bài học, công cụ AI (1 phút)

**Ý chính:** Mỗi khó khăn đều có cách xử lý cụ thể. AI giúp làm nhanh, nhưng quyết định là của nhóm.

**Lời nói:**

> Nhóm em gặp bốn khó khăn lớn.
>
> Một: gói Spark không có Cloud Storage. Nhóm chuyển sang Cloudinary với chữ ký từ backend, và giữ nguyên interface StorageService.
>
> Hai: tên sự kiện `notification_open` bị Firebase giữ riêng. Crashlytics bắt được lỗi, nhóm đổi tên sự kiện.
>
> Ba: backend chạy trên laptop nên có thể tắt bất cứ lúc nào. App vì thế đọc kết quả từ Firestore, có realtime và cache offline, và chỉ gọi backend để ra lệnh. Backend tắt thì người dùng vẫn xem lại được bài cũ.
>
> Bốn: RefChecker đọc nhầm năm thành tiêu đề với file `.bbl` kiểu ACL. Nhóm viết `bbl_repair.py`. Với bài 1508.04025, trước khi sửa cả 15/15 reference mất tiêu đề; sau khi sửa không còn reference nào mất tiêu đề, và số verified tăng từ 1 lên 9.
>
> Bài học nhóm rút ra: bằng chứng trên Console bắt được lỗi mà test với service giả bỏ sót. Interface cộng DI làm việc đổi nhà cung cấp rất rẻ. Không nên await lệnh ghi Firestore trên đường chuyển màn. Và AI tìm lỗi nhanh, nhưng lý do quyết định phải là của nhóm.
>
> Công cụ AI nhóm đã dùng: Google Stitch để sinh UI ở Lab 2; Claude Code để viết prompt, code, test, tài liệu, chạy code review và soạn bộ slide này. Tài liệu chi tiết nằm trong các file docs ở cột phải, còn link video demo nằm trong README.
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

Theo mục 11 của đề, thầy có thể kiểm từng bạn khoảng 5 phút với bốn việc: chạy một test ARTEMIS, đổi trực tiếp một giá trị Remote Config, giải thích một ViewModel và một quyết định code review. Bạn nào trong nhóm cũng nên tự làm được cả bốn việc.

### 1. Chạy một test ARTEMIS

Cần có sẵn: máy chủ ARTEMIS đang chạy, có API key trong `.env` của ARTEMIS; điện thoại cắm USB, đã bật USB Debugging; backend đang chạy.

```powershell
cd e2e_test
$env:E2E_TEST_ACCOUNT = "<email tài khoản test>"
$env:E2E_SERVER_URL   = "http://<IP Tailscale>:8000"
uv run pytest test_analyze.py::test_tc03_finished_paper_opens_right_away
```

Trong lúc test chạy, nói:

> Test này bảo agent mở app, nhập 1706.03762 rồi bấm Analyze. Agent đọc cây accessibility để tìm ô nhập và nút. Bài này đã có kết quả, nên app phải mở thẳng Paper Overview. Cuối test, agent trả về JSON gồm tên màn, tiêu đề bài, số reference. Test assert từng giá trị, rồi kiểm sự kiện search trong Logcat.

### 2. Đổi một giá trị Remote Config trực tiếp

1. Console → Remote Config → bấm vào `max_recent_checks` → đổi thành `1` → Save.
2. Bấm **Publish changes**.
3. Quay lại app, màn Analyze: mục Recent chỉ còn 1 thẻ. Màn Profile › Firebase demo cũng hiện giá trị mới.
4. Đổi lại thành `10` và Publish.

Trong lúc làm, nói:

> App nghe `onConfigUpdated`, nên Console vừa Publish là app nhận ngay và activate. RemoteConfigService gọi notifyListeners; AnalyzeViewModel nghe service này, nên danh sách Recent được cắt lại ngay mà không cần build lại app.

### 3. Giải thích một ViewModel: AnalyzeViewModel

Mở `lib/viewmodels/analyze_view_model.dart`, nói khoảng 1 phút:

> Đây là ViewModel của màn Analyze. Nó nhận 10 dependency qua constructor, tất cả đều là interface, và được tạo ở `app_dependencies.dart`.
>
> Khi người dùng gõ, `setInput` gọi `parseArxivId`. ID sai thì `showInvalid` bật và nút Analyze bị khoá qua `canSubmit`.
>
> Khi bấm Analyze, `submit()` bật cờ `_submitting` để chặn bấm hai lần. Sau đó nó đọc Firestore qua AnalysisRepository xem bài đã có kết quả chưa. Có rồi thì trả về `ready: true` để mở Overview ngay, không gọi backend. Chưa có, và cũng không đang chạy, thì gọi `POST /api/analyses` qua ApiClient. Lúc này nó ghi sự kiện `search` kèm `cache_hit`.
>
> Bài được ghi vào thư viện của user bằng `unawaited`. Đây chính là fix của CR-01: lệnh ghi Firestore khi offline chỉ xong khi có mạng, nên không được chờ nó.
>
> Về lỗi: `OfflineException` thành trạng thái unreachable; `ApiException` loại rejected thành failed; lỗi khác cũng thành failed và được ghi non-fatal lên Crashlytics. Khối `finally` luôn tắt `_submitting` rồi gọi `notifyListeners`, nên nút không bao giờ quay mãi.
>
> Danh sách Recent nghe Firestore realtime qua LibraryFeed, và chỉ lấy `max_recent_checks` phần tử theo Remote Config.

### 4. Giải thích một quyết định code review

Dùng CR-01 (Accepted) hoặc CR-05 (Modified), như phần lời nói của slide 31. Mở `docs/code-review.md` và commit 6c95c84 để chỉ dòng code trước và sau khi sửa.

---

## Câu hỏi khó: trả lời thật

| Thầy hỏi | Trả lời |
|---|---|
| Ảnh trên slide chụp ở đâu? | Một số ảnh FCM, Remote Config và lỗi kết nối chụp trên emulator BlueStacks. Hôm nay em demo trên điện thoại thật. |
| Sao chưa có pass rate ARTEMIS? | Suite đã viết đủ 19 ca nhưng chưa chạy, vì cần máy thật, backend, tài khoản test và API key cùng lúc. Nhóm sẽ chạy và cập nhật bảng. |
| Fix code review sao gộp một commit? | CR-01 có commit riêng. CR-02 đến CR-10 sửa chung trong be3ab33. Nhóm nhận đây là thiếu sót. |
| Figma có khớp app chưa? | Phần Export đã cập nhật. Nút Details ở màn Reference và các câu báo lỗi mới thì chưa. |
| Push không tới khi app đã tắt? | Máy Xiaomi/Redmi chặn app chạy nền nếu chưa bật Autostart, và Android chặn push cho app bị Force stop. |
