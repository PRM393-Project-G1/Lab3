# AI design log: Realtron (Lab 3)

> Ghi lại **nguyên văn** mọi prompt đã dùng để sinh UI, phản biện output, các vòng tinh chỉnh và phần nhóm tự sửa.
> Quy trình giống Lab 2 (`../lab2/code/Lab2/ux/ai-design-log.md`).
> Chuỗi UI trong prompt lấy đúng từ [user-flow.md](user-flow.md).

## 0. Công cụ và quy trình

| Bước | Công cụ | Ghi chú |
|---|---|---|
| Sinh UI | **Google Stitch** (stitch.withgoogle.com), chế độ **Mobile · Standard** | Phải dùng Standard thì mới có *Copy to Figma* |
| Viết prompt, phản biện ảnh output | **Claude** (Claude Code) | Prompt do nhóm và AI cùng soạn; mọi kết luận phản biện đều được nhóm kiểm lại trên ảnh và code HTML |
| Chuyển sang Figma | Stitch → Export → **Figma** → Convert → Copy → dán vào Figma | Stitch gửi HTML qua dịch vụ bên thứ ba **code.to.design** (nhóm đã đồng ý). Mỗi lần tối đa **16 màn**, nên phải chia 4 đợt. Khung trình duyệt trong app chặn clipboard (`clipboard-write: denied`), nên bước Copy + dán được làm trong trình duyệt thường (Opera GX). **Đã chuyển ngày 05/11/2026: 39 frame** sang page 03 Final UI, ảnh ở `evidence/design/figma_03_final_ui_sau_khi_dan.jpg`. Thẻ design system của Stitch không sang theo, nên page 04 phải dựng tay trên Figma |
| Hiện thực | Flutter (`app/`) | Lab 3 |

**Trình tự:** Prompt 1 → 2 → 3 (sinh màn hình) → phản biện v1 → Prompt 1b (bù màn thiếu) → R0 → R1 → R2 → R3 (4 vòng, mỗi vòng một mục tiêu) → xuất bản v2.

**Lưu output:** mỗi màn tải `screen.png` + `code.html` vào `stitch/v1/<tên_màn>/` (trước tinh chỉnh) và `stitch/v2/<tên_màn>/` (sau tinh chỉnh). Lưu `DESIGN.md` của Stitch vào `stitch/DESIGN.md`.

---

## 1. Prompt sinh UI (nguyên văn)

Mỗi prompt có đủ 5 thành phần: **persona**, **task**, **nền tảng mobile**, **constraints**, **style**.
Prompt 1 chứa toàn bộ bối cảnh. Prompt 2 và 3 gửi trong **cùng project Stitch** (Stitch giữ ngữ cảnh), nên chỉ mở đầu bằng một câu nhắc lại bối cảnh thay vì dán lại cả khối.

**Lần chạy:** 04/11/2026, project *"RefCheck Academic Citation Verifier"* (`stitch.withgoogle.com/projects/13230219338941343546`), chế độ **App**, model **Balanced** (Gemini 3.8 Flash). Stitch không còn chế độ Standard như Lab 2; menu Export vẫn có mục **Figma**.

### Prompt 1: bối cảnh, design system, màn 0–4

```
Design an Android mobile app called "RefCheck" (Material 3, 360–412 dp wide, portrait only).

PERSONA: Linh, 23, a final-year IT student who must present an unfamiliar research paper at her lab's journal club next week. She reads on her phone between classes, often one-handed. Pain points: the paper cites 40–60 references and she doesn't know which fields of knowledge it builds on or what to read first; she also can't tell whether those references are trustworthy — some may have wrong metadata or be fabricated by AI. Secondary persona: Dr. Hùng, a reviewer who needs evidence, not verdicts, and uses large system text (130%).

APP PURPOSE: The user enters an arXiv ID. The team's backend server (running on a laptop, reached through Tailscale) checks every reference against Semantic Scholar, OpenAlex, CrossRef, DBLP and arXiv, flags likely fabricated references, then groups the references into a topic tree. The app shows which topics the paper builds on, how many references each topic has, how many of them are wrong or fabricated, and which topics are "weak" (at least half of their references have problems). An analysis takes a few minutes and keeps running on the server if the user leaves; results are saved, so past analyses open even when the server is off.

REFERENCE STATUSES (always icon + text label + color, never color alone; precedence top to bottom):
- Hallucinated (likely fabricated) — purple #7E22CE on #FAF5FF, warning-octagon icon
- Error (wrong metadata) — red #B91C1C on #FEF2F2, error icon
- Warning (minor issue) — amber text #92400E, icon #D97706, on #FFFBEB, alert-triangle icon
- Verified — green #15803D on #F0FDF4, check-circle icon
- Unverified (not found) — slate #475569 on #F8FAFC, help-circle icon
A "Weak" topic tag uses the Error colors with an icon and the word "Weak".

DESIGN SYSTEM "Academic Verifier": primary deep navy #1E3A8A, background #F8FAFC, surfaces white, text #0F172A / #475569 / #64748B, outlines #CBD5E1. Headlines in Source Serif 4 (600); body and labels in Inter; arXiv IDs, DOIs, URLs and file names in JetBrains Mono. 8 dp grid, 16 dp page margin, cards 12 dp radius, buttons and inputs 8 dp radius, chips 6 dp, dialogs and sheets 24 dp, subtle elevation. Body text at least 14 sp, tap targets at least 48×48 dp, text contrast at least 4.5:1.

NAVIGATION: bottom navigation bar with 3 tabs — Analyze, History, Profile.

CONTENT RULES: never invent statistics; use exactly the sample values given below. Every screen that loads data needs loading, empty and error states. Use the exact English strings in quotes.

SCREENS (this prompt):
0. Connect server (shown once after first sign-in; reused from Profile with title "Change server"): field "Server URL" with a Paste button and helper "Your team's Tailscale address, e.g. http://100.x.x.x:8000"; button "Test connection" (busy state "Testing…"); success banner "Connected · RefCheck backend" with "Responded in 84 ms."; button "Continue" that is enabled only after a successful test, with the hint "Test the connection to continue." Error banner "Can't reach this server" with three hints: "Is Tailscale turned on on this phone?", "Is the backend running?", "Did you type http:// (not https)?" and a "Retry" button.
1. Sign-in: app logo and "RefCheck"; one line "See which topics a paper builds on — and which of its references you can trust."; button "Continue with Google" with the Google logo. Variants: signing in (button loading), cancelled (banner "Sign-in was cancelled."), offline (banner "You're offline. Connect to sign in.").
2. Analyze (tab): app bar title "Analyze" with a bell icon (notifications) at the right; text field "arXiv ID or paper link" with Paste button and helper "Example: 1706.03762"; chip "Try 1706.03762"; switch "AI-assisted check"; primary button "Analyze"; section "Recent checks" with "View all" and 2 cards (paper title, arXiv ID in mono, "2 h ago", small stacked status bar). Variants: invalid input (error under the field "This doesn't look like an arXiv ID or URL. Example: 1706.03762"); server unreachable (banner "Can't reach the server" — "Check that Tailscale is on and the backend is running." — buttons "Retry" and "Change server").
3. Analysis in progress (no bottom bar): title "Analyzing…", paper title "Attention Is All You Need"; vertical stepper with 5 steps: "Extracting references", "Verifying against databases", "Hallucination check", "Fetching reference text", "Finding topics" (first two done, third active); line "18 of 41 references"; buttons "Run in background" and "Cancel". Variants: complete (title "Analysis complete", button "View overview"); failed (banner "Couldn't analyze this paper" + reason, buttons "Try again" and "Edit input"); offline (banner "You're offline. Progress will update when you reconnect.").
4. Paper overview: app bar with back arrow and action "Report"; paper title (serif) and authors "Vaswani, Shazeer, Parmar, et al. · 2017"; top alert card (purple) "2 references may be fabricated" with button "Review 2"; card with a stacked bar and counts for 41 references: 2 Hallucinated, 3 Error, 4 Warning, 29 Verified, 3 Unverified; card "Topics" with "9 topics · 2 weak", listing the 2 weak topics ("Sequence transduction · 6 refs", "Attention mechanisms · 5 refs") each with a mini stacked bar and a "Weak" tag, and a button "Explore topics".
```

### Prompt 2: màn 5–8

```
Keep the same app context, persona, statuses, "Academic Verifier" design system, 3-tab navigation (Analyze, History, Profile) and content rules as the first prompt. Never invent statistics; every data screen needs loading, empty and error states; use the exact English strings in quotes.

SCREENS (this prompt):
5. Topic map: app bar "Topics" with back arrow, subtitle paper title; filter chips "All topics" / "Weak only"; an expandable tree with indentation guides (max 3 visible levels). Each row: chevron, topic name, "8 refs", a thin stacked status bar, and a "Weak" tag when weak. Sample rows: "Neural networks · 14 refs" (expanded) with children "Attention mechanisms · 5 refs · Weak" and "Recurrent networks · 6 refs"; "Sequence transduction · 6 refs · Weak"; "Machine translation · 9 refs"; last row "Unclassified · 3 refs" with info text "We couldn't read these references, so they have no topic." Footnote: "Weak = at least half of a topic's references have errors or look fabricated." Variants: Weak only with no results (empty state "No weak topics" — "Every topic is mostly backed by verified references." — button "Show all topics"); loading; error ("Couldn't load topics" + "Retry").
6. Topic detail: breadcrumb "Neural networks › Attention mechanisms"; topic name (serif); stacked bar with counts (5 refs: 2 Hallucinated, 1 Error, 2 Verified) and a "Weak" tag; section "Subtopics" with 2 rows; filter chips by status with counts; list of reference cards (status chip, title, first author, year, one-line issue such as "No matching paper found in 5 databases").
7. Reference list: app bar "References" with back arrow; filter chips with counts (All 41, Hallucinated 2, Error 3, Warning 4, Unverified 3, Verified 29); reference cards sorted Hallucinated > Error > Warning > Unverified > Verified; empty state "Nothing here".
8. Reference detail: status banner (Error); table "Cited" vs "Actual" for Title / Authors / Year / Venue with the mismatching cells highlighted (Year: 2016 vs 2017); button "Copy fix" (snackbar "Corrected BibTeX copied"); section "In topics" with 2 topic chips; link "Matched source". Dialog variant for a Hallucinated reference: title "Likely fabricated reference", section "CLOSEST MATCH FOUND" with a title and authors, buttons "Open closest match" and "Search the web", and the line "Automatic detection can be wrong — check the source before concluding."
```

### Prompt 3: màn 9–11 + overlay

```
Keep the same app context, persona, statuses, "Academic Verifier" design system, 3-tab navigation (Analyze, History, Profile) and content rules as the first prompt. Never invent statistics; every data screen needs loading, empty and error states; use the exact English strings in quotes.

SCREENS (this prompt):
9. History (tab): app bar "History"; search field "Search papers or arXiv ID…"; groups "Today", "This week", "Earlier"; history cards (paper title, "arXiv:1706.03762" in mono, time, status chip; one card with chip "In progress"); overflow menu "More actions" with "Rename" and "Delete". Variants: loading; empty ("No checks yet" — "Papers you analyze will be saved here." — button "Analyze your first paper"); error ("Couldn't load history" + "Retry"); no search match ("No checks match "bert".").
10. Notifications: app bar "Notifications" with back arrow; list items (icon, title "Analysis complete", body "Attention Is All You Need — 2 references may be fabricated", "5 min ago", unread dot); empty state "No notifications yet".
11. Profile (tab): avatar, display name, button "Sign out"; section "CHECK DEFAULTS" with switch "AI-assisted check"; section "SERVER" with "Current server" (mono address) and button "Change server"; section "FIREBASE DEMO" with row "Notifications" (badge 3), row "Export & upload report", card "Remote Config" with mono key–value rows "weak_topic_threshold = 0.5" and "max_recent_checks = 10", card "Crashlytics" with buttons "Log handled error" and "Test crash" (destructive style).
Overlays:
- Bottom sheet "Export report" in 4 states: generating ("Generating PDF…"), uploading (progress bar "Uploading… 64%"), uploaded ("Uploaded", file name "refcheck_1706.03762.pdf · 214 KB" in mono, buttons "Copy link" and "Share"), failed ("Upload failed. Check your connection and try again." + "Retry").
- Dialog "Cancel analysis?" — "The analysis will stop and nothing will be saved." — buttons "Keep analyzing" / "Cancel analysis".
- Dialog "Delete this check?" — "It will be removed from your history." — buttons "Cancel" / "Delete".
- Dialog "Rename check" with a text field and "Save".
- Dialog "Trigger a test crash?" — "The app will close. The crash appears in Crashlytics within a few minutes." — buttons "Cancel" / "Crash now".
```

---

## 2. Phản biện bản v1 (≥ 5 phát hiện)

Ảnh v1 (chụp canvas Stitch trước khi tinh chỉnh) nằm ở `stitch/v1/01…07_*.jpg`.

| ID | Màn | Phát hiện | Bằng chứng | Xử lý ở vòng |
|---|---|---|---|---|
| F1 | Sheet Export, 4 dialog (và Profile) | Prompt 3 chỉ hiện History + Notifications trên canvas lúc đó. **Bỏ sót** sheet Export report và các dialog (lỗi "nhiều ý trong một prompt", giống Lab 2). **Đính chính:** sau khi tải lại trang, canvas có thêm một frame Profile mang chữ của Prompt 3 ("Export & upload report", "Log handled error"), nên Profile không thực sự bị thiếu. Vòng 1b vì vậy tạo ra **2 frame Profile**; chỉ giữ bản 1b đã sửa, bỏ bản cũ khi lên Figma | Canvas chỉ có 2 frame ở hàng 3 (`07_notifications_history.jpg`) | 1b |
| F2 | Connect, Sign-in, Topic Map, Topic Detail, Reference List, Analysis | **Nhét công cụ xem trước trạng thái vào UI thật**: "STATE VARIANT INSPECTOR · QA Mode", "Simulate state", "Preview state", "Audit Environment Simulation" | `02_connect_signin.jpg`, `05_topic-map_topic-detail.jpg` | R0 |
| F3 | Overview, Topic Detail, Reference List, Sign-in | **Bịa số liệu và huy hiệu** không có trong prompt: "54.2", "92.7% audited", "Integrity Score 78%", "TLS 1.3 Certified", "RefCheck v2.4.0 (Build 412)", "Graph engine v3.1", "4.2 req/s", "Est. time remaining ~14s" | `03_signin_analyze_overview.jpg`, `04_analysis-in-progress.jpg` | R0 |
| F4 | Mọi màn | **Sai tên app và giọng "audit" kỹ thuật**: app bar ghi "Audit Inspection", nút "ANALYZE CITATION GRAPH", "Review 2 Flagged Citations", "Audit Pipeline", "Live audit stream" | `03_signin_analyze_overview.jpg` | R0 |
| F5 | Sign-in, Connect, Analyze, Overview, Notifications | **Lộ tên backend / công cụ trên UI**: chip "Crossref · arXiv · DBLP", "Semantic Scholar & Crossref Cache", "Validated via CrossRef & arXiv", "Automated Crossref & arXiv sync", "Tailscale mesh node" | `02_connect_signin.jpg`, `07_notifications_history.jpg` | R0 |
| F6 | Mọi màn (trừ phần kết quả) | **Quá nhiều chữ** (góp ý trực tiếp của thầy, 04/11/2026): đoạn giới thiệu, khối "Institutional assurance", mô tả dưới mỗi bước stepper, câu giải thích dài trong banner | Toàn bộ ảnh v1 | R1 |
| F7 | Analyze, Overview | **Thêm khối trang trí không có trong brief**: "Rigorous verification in seconds", "High Density Ingestion", "Recommended" | `03_signin_analyze_overview.jpg` | R0 + R1 |
| F8 | Notifications | **Thêm loại thông báo không có trong flow**: "Backend server connected", "PDF Export ready", "Automated Crossref & arXiv sync" | `07_notifications_history.jpg` | R1 |

**Điểm đạt ở v1** (giữ lại):
- Cây chủ đề có thụt lề, có nhãn "WEAK" kèm icon, có nhóm "Unclassified".
- Trạng thái reference luôn có icon + chữ + màu.
- Bảng Cited / Actual tô đúng ô lệch.
- Design system "Academic Verifier" được dựng thành một trang riêng.

Các lỗi Lab 2 cho thấy Stitch hay mắc, cần soi kỹ:
1. Tự bịa số liệu hoặc phần trăm không có trong prompt.
2. Bỏ sót màn hoặc trạng thái khi một prompt có nhiều yêu cầu.
3. Chỉ dùng màu để phân biệt trạng thái.
4. Chữ nhỏ hơn 14 sp.
5. Thiếu trạng thái lỗi / rỗng.
6. Đổi chữ trên nút khác với prompt.

Riêng sản phẩm này cần soi thêm:
- Cây chủ đề có đọc được ở 360 dp không.
- Nhãn "Weak" có icon + chữ chưa.
- Nhóm "Unclassified" có bị bỏ mất không.

## 3. Vòng bổ sung: Prompt 1b (bù màn thiếu)

**Trước vòng 1b:**
- Nhóm đổi tên app thành **Realtron** và đổi tên project Stitch thành "Realtron".
- Thầy góp ý giao diện quá nhiều chữ, nên quy tắc chữ được chốt ở `user-flow.md` mục 0.

Prompt 1b vì thế áp dụng luôn tên mới và quy tắc chữ ngắn.

```
The app is now called "Realtron". Same persona, statuses, "Academic Verifier" design system and 3-tab navigation (Analyze, History, Profile). The previous prompt missed some screens — create them now as separate screens.

COPY RULES: minimal text. Buttons 1–2 words, titles ≤ 3 words, at most one short helper line (≤ 8 words). No marketing lines, no tool or database names, no version numbers, no technical badges, no "simulate/preview state" controls. Icons + short labels instead of sentences. Use exactly these strings.

11. Profile (tab, Profile selected): avatar, display name, text button "Sign out"; switch row "AI check"; row "Server" with mono address "100.86.14.22:8000" and button "Change"; section "Firebase demo": row "Notifications" (badge 3), row "Export report", card "Remote Config" with mono rows "weak_topic_threshold 0.5" and "max_recent_checks 10", two buttons "Log error" and "Test crash" (destructive).
Bottom sheet "Export report" over the Overview screen, shown as 4 separate frames: "Creating PDF…" (spinner); "Uploading 64%" (progress bar); "Uploaded" with mono file name "realtron_1706.03762.pdf · 214 KB" and buttons "Copy link" and "Share"; "Upload failed" with button "Retry".
Dialogs (each a separate frame over its screen): "Stop analysis?" — "Progress will be lost." — "Keep going" / "Stop"; "Delete check?" — "Removed from your history." — "Cancel" / "Delete"; "Rename" with a text field and "Save"; "Test crash?" — "The app will close." — "Cancel" / "Crash".
```

**Kết quả:** đã bù màn Profile và 3 frame của sheet Export report (Creating PDF, Uploading 64%, Uploaded). **Thiếu** frame "Upload failed" và cả 4 dialog (xem F9); đã bù ở R3a/R3b.

## 4. Bốn vòng tinh chỉnh (mỗi vòng một mục tiêu khác nhau)

R0 và R1 gửi khi đã **chọn toàn bộ màn** trên canvas (Ctrl+A), để Stitch sửa trực tiếp các màn có sẵn thay vì sinh màn mới.

| Vòng | Mục tiêu | Prompt (nguyên văn) | Trước / sau |
|---|---|---|---|
| R0 | Nội dung trung thực, chỉ nói về sản phẩm (xử lý F2, F3, F4, F5, F7) | Xem khối R0 bên dưới | `stitch/v1/` → `[ảnh sau R0]` |
| R1 | Chữ tối giản, dễ quét (xử lý F6, F8; góp ý của thầy) | Xem khối R1 bên dưới | `[ảnh sau R1]` |
| R2 | Accessibility: contrast ≥ 4.5:1, chạm ≥ 48 dp, chữ ≥ 14 sp, icon + chữ cho mọi trạng thái, cỡ chữ 130% | `[CẦN BỔ SUNG]` | `[ảnh]` |
| R3 | Trạng thái lỗi / rỗng / tải của Flow A, B, C | `[CẦN BỔ SUNG]` | `[ảnh]` |

**Prompt R0 (nguyên văn):**

```
R0 — honest, product-only content. Revise ALL selected screens; keep layout, colors and the paper sample data (titles, authors, reference counts).

1. The app name is "Realtron" everywhere (app bar, logo text, sign-in). Remove "RefCheck" and "Audit Inspection".
2. Remove every state-switcher control inside the screens ("Simulate state", "Preview state", "State variant inspector", "QA mode", "Audit environment simulation", "Test dialog"). Each screen shows only its normal state.
3. Remove every number, badge or block that was not in the brief: version and build numbers, "TLS", integrity/audit scores (e.g. "54.2", "92.7% audited", "Integrity score"), engine names, req/s, time estimates, peer identity, "Institutional assurance", "Live audit stream", "High density ingestion".
4. Do not name any backend tool or database (Semantic Scholar, CrossRef, OpenAlex, DBLP, Tailscale node names) and avoid jargon like "audit", "pipeline", "ingestion", "taxonomy". arXiv IDs of papers stay.
```

**Prompt R1 (nguyên văn):**

```
R1 — minimal, scannable copy. Revise ALL selected screens. The lecturer says there is too much text. Rules: buttons 1–2 words; titles ≤ 3 words; at most one helper line (≤ 8 words); remove intro paragraphs, taglines, explanations and decorative sections; prefer icon + short label; more white space. EXCEPTION: analysis results keep their content (reference titles, authors, Cited vs Actual table, issue text, fabrication explanation). Use exactly these strings:

Sign-in: "Realtron", "Know what a paper stands on.", "Continue with Google"; errors "Sign-in cancelled", "You're offline".
Connect server: title "Connect server"; field "Server URL", helper "e.g. http://100.x.x.x:8000"; button "Test" ("Testing…"); success "Connected · 84 ms"; "Continue"; error "Can't reach server" with chips "Tailscale on?" "Backend running?" "Using http://?" and "Retry".
Analyze: field "arXiv ID or link", helper "e.g. 1706.03762", chip "Try 1706.03762", switch "AI check", button "Analyze", section "Recent" + "See all"; error "Not a valid arXiv ID"; banner "Can't reach server" + "Retry" "Change server".
Analyzing: title "Analyzing…"; steps "References", "Verify", "Fabrication check", "Full text", "Topics" (no sub-descriptions); "18/41 refs"; buttons "Run in background", "Stop"; done "Done" + "View results"; failed "Analysis failed" + "Retry" "Edit"; offline "Offline · will resume".
Overview: alert "2 may be fabricated" + "Review"; status bar with 5 counts; card "Topics" "9 topics · 2 weak" + 2 weak rows + "Explore"; app bar action "Report".
Topics: chips "All" / "Weak"; rows "8 refs" + "Weak" tag; "Unclassified · 3" with "No readable text"; footnote "Weak: ≥ 50% refs have issues"; empty "No weak topics" + "Show all". Topic: breadcrumb, counts, "Subtopics". References: "References", chips with counts, empty "Nothing here".
Reference: "Copy fix" (snackbar "Fix copied"), section "Topics", link "Source"; dialog "Likely fabricated", "Closest match", "Open", "Search web", note "May be wrong — check the source."
History: "History", search "Search", groups "Today" "This week" "Earlier", chip "Running", menu "Rename" "Delete"; empty "No checks yet" + "Analyze a paper"; error "Couldn't load" + "Retry". Notifications: item "Analysis done" + "Attention Is All You Need · 2 flagged"; empty "No notifications". Profile: "Sign out", "AI check", "Server" + "Change", "Firebase demo": "Notifications", "Export report", "Remote Config", "Log error", "Test crash". Export sheet: "Creating PDF…", "Uploading 64%", "Uploaded", "Copy link", "Share", "Upload failed" + "Retry".
```

**Kết quả R0 + R1** (ảnh `stitch/r1/`):
- **Đạt:**
  - App bar và Sign-in đã đổi thành "Realtron".
  - Bỏ hết thanh Simulate / Preview state.
  - Connect server, Sign-in, Topic map đã gọn: Topic map chỉ còn "All / Weak", "Unclassified · 3 · No readable text", "Weak: ≥ 50% refs have issues".
  - Stepper bỏ được mô tả con.
- **Còn sót** (AI làm khoảng 2/3 yêu cầu, giống bài học ở Lab 2):
  - Analyze vẫn còn chip "Crossref · arXiv · DBLP", nút viết hoa "ANALYZE" và nhãn "Recommended".
  - Overview vẫn ghi "Review 2 Flagged Citations" (đúng ra là "Review"), thẻ Topics còn câu giải thích dài.
  - Analyzing vẫn còn tiêu đề "Audit Pipeline · Step 3 of 5", các huy hiệu "Parsed / Matched", và "44%".
  - Reference list vẫn còn "41 bibliographic citations audited", "SEVERITY PRECEDENCE SORT", "Status: High Confidence Phantom".
  - Notifications: app bar ghi sai thành "Reference Detail"; vẫn còn các thông báo ngoài flow ("Server connected", "PDF Export ready").

  → xử lý ở vòng **R1b**, hoặc nhóm tự sửa trên Figma.

**Prompt R1b (nguyên văn).** Gửi khi chọn toàn bộ màn, nhưng prompt nêu rõ chỉ sửa 5 màn còn sót. Lý do: shift+click trên canvas Stitch không chọn được nhiều màn cùng lúc.

```
R1b — finish the minimal-copy pass. Change ONLY these 5 screens: Analyze, Paper Overview, Analysis in Progress, Reference List, Notifications. Leave every other screen exactly as it is.

Analyze: remove the source chip next to the field label ("Crossref · arXiv · DBLP") and the "Recommended:" label; the button reads "Analyze" in sentence case (not all caps).
Paper Overview: alert button reads just "Review"; in the Topics card remove the explanation sentence and keep only "9 topics · 2 weak", the 2 weak rows and "Explore".
Analysis in Progress: remove the "Audit Pipeline · Step 3 of 5" header, the status badges ("Parsed", "Matched", "Running", "Upcoming") and the "Analyzing references…" pill; keep the 5 step names with icons, "18/41 refs" with a progress bar, "Run in background" and "Stop".
Reference List: subtitle "41 refs" (remove "bibliographic citations audited"); remove "SEVERITY PRECEDENCE SORT", "Showing 7 of 41", "Status: High Confidence Phantom" and the "Details" buttons (the whole card is tappable). Keep each card's title, authors, year and one-line issue.
Notifications: app bar title "Notifications"; remove the "ACTIVITY LOG" label and the category badges; keep only 2 items: "Analysis done" — "Attention Is All You Need · 2 flagged" — "5 min ago" (unread dot), and "Analysis done" — "Deep Residual Learning · 1 flagged" — "2 h ago" (read). Remove "Server connected", "PDF Export ready" and any sync items.
```

**Kết quả R1b** (ảnh `stitch/r1b/`):
- **Đạt cả 5 màn:**
  - **Analyze:** bỏ chip nguồn và nhãn "Recommended"; nút "Analyze" viết thường; mục "Recent" + "See all".
  - **Overview:** nút "Review"; thẻ Topics bỏ câu giải thích.
  - **Analyzing:** chỉ còn 5 bước + "18/41 refs" + "Run in background" / "Stop".
  - **Reference list:** "41 refs", bỏ nhãn sort và trạng thái kỹ thuật.
  - **Notifications:** tiêu đề đúng, chỉ còn 2 thông báo "Analysis done".
- **Còn sót nhỏ** (nhóm tự sửa trên Figma, hoặc gộp vào R2):
  - Sign-in còn dòng nhỏ "Academic SSO via Google Scholar & ORCID".
  - History: app bar ghi "Realtron · Analyze" trong khi đang ở tab History.
  - Topic detail còn tiêu đề "Audit Distribution".
  - Topic map còn dòng chú thích "Status Distribution".
  - Reference list còn nút "Fix Entry" và dòng "Diff: -1 Year Offset".
  - Overview: thẻ Topics còn dòng "6 references mapped" (chấp nhận được, vì thuộc phần kết quả).

**Prompt R2 (nguyên văn).** Chọn toàn bộ màn; gộp luôn 5 chỗ chữ còn sót sau R1b.

```
R2 — accessibility. Revise ALL selected screens; keep layout, copy and data unless listed below.

1. Text: body and list text at least 14 sp, secondary/meta text at least 12 sp (no 9–11 sp labels); all text contrast at least 4.5:1 on its background (amber warning text uses #92400E, never #D97706 for text).
2. Touch targets: every button, chip, icon button, tree row chevron, list row and overflow menu at least 48×48 dp; at least 8 dp between adjacent targets.
3. Never color alone: every status (Hallucinated, Error, Warning, Verified, Unverified), the "Weak" tag and the stacked status bars keep an icon + text label or a count legend next to them.
4. Large text (130%): single-column layouts, no fixed-height text boxes, long titles wrap to 2 lines instead of being truncated with "…" (topic names like "Attention mechanisms" must be fully readable).
5. Leftover copy fixes: Sign-in remove the line "Academic SSO via Google Scholar & ORCID"; History app bar title is "History" (not "Analyze"); Topic Detail rename "Audit Distribution" to "Status"; Topic Map remove the "Status Distribution" legend line (keep a compact color+icon legend); Reference List remove "Fix Entry" buttons and "Diff: …" lines.
```

**Kết quả R2** (ảnh `stitch/r2/`):
- **Đạt:**
  - Sign-in chỉ còn logo, "Realtron", "Know what a paper stands on." và nút Google.
  - Tiêu đề chủ đề dài không còn bị cắt "…".
  - Topic map đổi dòng "Status Distribution" thành chú thích màu + icon.
  - Reference list bỏ nút "Fix Entry" và dòng "Diff".
- **Cần nhóm tự đo lại trên Figma:** contrast, kích thước vùng chạm 48 dp, cỡ chữ. Stitch chỉ báo "đã sửa", ảnh chụp không đủ để kiểm chứng. Đo bằng plugin contrast ở page 04/05.
- **Phát hiện mới khi kiểm tra hàng màn của 1b:**
  - **F9 — vẫn thiếu frame:** chỉ có 4 frame (Profile, Export: Creating PDF, Uploading 64%, Uploaded). **Không có** frame "Upload failed" và **không có** dialog nào (Stop analysis?, Delete check?, Rename, Test crash?). Prompt 1b đã yêu cầu nhưng Stitch bỏ qua. → R3.
  - **F10 — Profile bịa nội dung:** nhãn "Verified Member" dưới tên và lặp lại trong thẻ Remote Config. → R3.
  - **F11 — nền của sheet Export là bản Overview cũ:** tiêu đề "Paper Verification Audit", "41 Citations Audited", "Network Breakdown"; dòng phụ "Preparing citation audit document." → R3, hoặc trên Figma thay nền bằng frame Overview mới.

**R3 tách thành 2 phần**, vì cần khoảng 20 frame trạng thái. Lab 2 cho thấy một prompt quá nhiều ý sẽ bị bỏ sót (F1, F9). R3a và R3b gửi **không chọn màn nào**, để Stitch tạo frame mới thay vì ghi đè lên màn ở trạng thái bình thường.

**Prompt R3a (nguyên văn):**

```
R3a — error, empty and loading states (part 1: sign-in, connect, Flow A). Create NEW separate frames by duplicating the existing normal screen and changing only what the state needs. Do not modify the existing normal screens. Same Realtron design system and minimal-copy rules (buttons 1–2 words, one short line max). Name each frame "<Screen> — <State>".

1. Sign In — Cancelled: banner "Sign-in cancelled" above the Google button.
2. Connect Server — Failed: error banner "Can't reach server" with 3 small chips "Tailscale on?" "Backend running?" "Using http://?" and button "Retry"; "Continue" disabled.
3. Analyze — Invalid: field shows "hello-world" with red outline and error text "Not a valid arXiv ID"; "Analyze" disabled.
4. Analyze — Server unreachable: banner "Can't reach server" — "Check Tailscale and backend." — buttons "Retry" and "Change server".
5. Analyze — First use: no Recent section; small empty hint "No checks yet" under the Analyze button.
6. Analysis in Progress — Done: all 5 steps checked, title "Done", primary button "View results".
7. Analysis in Progress — Failed: step 3 shows an error icon; banner "Analysis failed" — "Paper not found on arXiv." — buttons "Retry" and "Edit".
8. Analysis in Progress — Offline: grey banner "Offline · will resume" at the top; progress unchanged.
9. Analysis in Progress — Stop dialog: dialog "Stop analysis?" — "Progress will be lost." — buttons "Keep going" and "Stop" (destructive).
10. Paper Overview — Loading: skeleton placeholders for title, alert card, status bar and Topics card. 11. Paper Overview — Error: centered icon, "Couldn't load", button "Retry".
```

**Prompt R3b (nguyên văn):**

```
R3b — error, empty and loading states (part 2: Flow B, Flow C, dialogs). Same rules as R3a: create NEW separate frames by duplicating the normal screen, do not modify existing screens, minimal copy, name each frame "<Screen> — <State>".

1. Topic Map — No weak topics: chip "Weak" selected; empty state icon, "No weak topics", button "Show all".
2. Topic Map — Error: centered icon, "Couldn't load", button "Retry".
3. Reference List — Empty: filter "Unverified" selected; "Nothing here".
4. History — Loading: skeleton cards. 5. History — Empty: icon, "No checks yet", button "Analyze a paper". 6. History — Error: "Couldn't load", button "Retry". 7. History — No results: search "bert", text "No results".
8. History — Delete dialog: "Delete check?" — "Removed from your history." — "Cancel" / "Delete" (destructive). 9. History — Rename dialog: "Rename" with a text field prefilled "Attention Is All You Need" and "Save".
10. Notifications — Empty: icon, "No notifications".
11. Export — Upload failed: bottom sheet "Export report" with error icon, "Upload failed", button "Retry" (background: the current Paper Overview screen).
12. Profile — Test crash dialog: "Test crash?" — "The app will close." — "Cancel" / "Crash" (destructive).
```

**Prompt R3-fix (nguyên văn).** Chọn toàn bộ màn, nhưng prompt chỉ cho sửa Profile và sheet Export. Mục đích: xử lý F10, F11.

```
R3-fix — change ONLY the Profile screens and the Export sheet screens (Creating PDF, Uploading 64%, Uploaded, Upload failed). Leave all other screens exactly as they are.

Profile: remove every "Verified Member" label (under the name and inside the Remote Config card). Remote Config rows show only the mono key and value: "weak_topic_threshold 0.5", "max_recent_checks 10".
Export sheet: the dimmed background must be the current Paper Overview (app bar "Paper Overview", "Attention Is All You Need", alert "2 may be fabricated", Topics card) — remove "Paper Verification Audit", "Citations Audited" and "Network Breakdown". In the sheet remove the helper line "Preparing citation audit document."; keep only "Creating PDF…" / "Uploading 64%" / "Uploaded" / "Upload failed" with their buttons.
```

> Lưu ý: chữ "See all" trong R1 khác với "View all" ở bản trước; `user-flow.md` chưa có chữ này cho Recent. Chốt dùng **"See all"**.

**Kết quả R3a + R3b + R3-fix** (ảnh `stitch/r3/`):
- **Đạt:**
  - Có thêm **23 frame trạng thái**: 11 frame của R3a, 12 frame của R3b, đặt tên dạng "<Màn> — <Trạng thái>".
  - Đủ các nhánh lỗi của Flow A, B, C.
  - Đủ 4 dialog (Stop analysis?, Delete check?, Rename, Test crash?) và frame "Upload failed".
  - **Profile:** bỏ hết nhãn "Verified Member", thẻ Remote Config chỉ còn key và value.
  - Nền của sheet Export đã là màn "Paper Overview".
- **Còn sót** (nhóm tự sửa trên Figma):
  - **F12 — empty/error state lại dài dòng:** Stitch tự thêm câu giải thích dưới tiêu đề, ví dụ "Failed to load paper details and verification data. Check your network connection and try again.", "Analyses you run will appear here for review and reference.", "You're all caught up! …", "There are no unverified references in this manuscript audit.", "Edit the title for this analysis check." → chỉ giữ tiêu đề + nút theo `user-flow.md`.
  - **F13 — tên frame lọt vào app bar:** "Sign In — Cancelled" hiện ngay trên app bar. Banner thì thành "Sign-in cancelled. Please try again." thay vì chuỗi chuẩn "Sign-in cancelled".
  - Sheet "Creating PDF…" vẫn còn dòng "Preparing citation audit document." (R3-fix mới sửa được nền, chưa sửa dòng này).
  - **F14 — frame Profile cũ của Prompt 3:** app bar ghi "REFCHECK · Analyze", và tự bịa thông tin cá nhân: email "linh.hoang@hust.edu.vn", trường "Hanoi University of Science and Technology", nhãn "Student". Bỏ cả frame này khi sắp xếp page 03, chỉ giữ bản Profile đã sửa.

### Sửa tay trên Figma sau khi dán (05/11/2026)

Các lỗi AI chưa xử lý được, nhóm sửa trực tiếp trên page 03:

| Phát hiện | Đã sửa |
|---|---|
| F12 | Xoá 7 câu giải thích dài ở: Paper Overview — Error, Topic Map — Error, History — Error, History — Empty, Notifications — Empty, Reference List — Empty, dialog Rename. Xoá thêm dòng "Network connection timed out" ở Export — Upload failed |
| F13 | Bỏ app bar của Sign In — Cancelled cho khớp màn Sign In; banner còn "Sign-in cancelled" |
| Sheet Creating PDF | Xoá dòng "Preparing citation audit document." |
| F14 | Xoá frame Profile cũ |
| Paper Overview | "2 references may be fabricated" → "2 may be fabricated"; "References verification (41)" → "References (41)" |
| Thiếu dialog | Tạo frame "Reference — Likely fabricated dialog" (Stitch chỉ có trong code, không có frame riêng). Đổi nút "Search web" sang màu primary và bỏ icon thùng rác |

Page 03 có 39 frame, chia 5 Section: Entry (4), Flow A (12), Flow B (8), Flow C (11), Other (4).

**Còn lại:** dialog Rename và Delete nằm trên frame cao hơn lớp nền mờ, nên phần cuối frame không được làm mờ. Chỉ ảnh hưởng hình tĩnh trên Figma.

### Script dựng phần còn lại của Figma (05/11/2026, đã chạy)

Làm tay bằng chuột quá chậm và dễ sai, nên phần còn lại nằm trong một script: `design/figma-setup/realtron-figma-setup.js`. Script dựng page 01, 02, 04, 05, gắn màu và chữ của page 03 + 06 vào token, sửa các lỗi prototype đã phát hiện (`See all` nối nhầm màn, `History — Loading` sai trigger, thời gian chờ của `Export: Creating PDF`) và đặt 4 điểm bắt đầu.

Kết quả đọc lại từ file Figma sau khi chạy: 40 Variables, 10 Text styles, 2 Effect styles; page 01 có sitemap và 3 flow; page 02 có 12 màn; page 05 có 22 component; 895/895 chữ trên page 03 dùng Text style; 2471/2491 lớp tô dùng Variable (phần còn lại gồm nền section, gradient và vector); 13 Bottom nav là instance; page 06 có 4 điểm bắt đầu, không tương tác nào trỏ tới khung không tồn tại.

Lần chạy này làm lộ một lỗi của chính script: khung `Export: Saved` mới thêm không có đường ra, và khi `Creating PDF` chuyển sang `Saved` thì không còn tới được nhánh C-E1. Đã sửa bằng `design/figma-setup/realtron-figma-fix-export.js`: 40 khung đều có đường đi tiếp, chỉ `Export: Uploading 64%` và `Export: Uploaded` không tới được, vì chúng chỉ dùng khi bật `enable_cloud_upload`. **Chưa thử bằng Present.**

Những bản sao khác trên page 03 không được đổi thành instance; chỉ Bottom nav được thay.

## 5. Tổng kết vòng lặp

| Vòng | Mục tiêu | Phát hiện xử lý | AI làm được | Nhóm tự sửa ở bản cuối (Figma) |
|---|---|---|---|---|
| 1b | Bù màn thiếu | F1 | Một phần: có Profile + 3 frame Export, thiếu dialog và "Upload failed" (F9) | — (đã bù ở R3) |
| R0 | Trung thực, chỉ nói về sản phẩm | F2, F3, F4, F5, F7 | Phần lớn: bỏ thanh Simulate, số bịa, tên app sai | Vài chip nguồn còn sót (đã xử lý ở R1b) |
| R1 | Chữ tối giản (góp ý của thầy) | F6, F8 | Khoảng 2/3 | 5 màn còn sót → R1b |
| R1b | Dọn chữ còn sót ở 5 màn | F6 (phần còn lại), F8 | Đạt cả 5 màn | — |
| R2 | Accessibility + dọn chữ nhỏ | — | Bỏ chữ thừa, không cắt tiêu đề | **Đo lại** contrast, vùng chạm 48 dp, cỡ chữ bằng plugin trên Figma |
| R3a/R3b | Trạng thái lỗi / rỗng / tải + dialog | F9 | Đủ 23 frame | F12 (rút gọn câu giải thích), F13 (sửa app bar) |
| R3-fix | Sửa Profile, nền sheet Export | F10, F11 | Profile đạt; nền sheet đạt | Dòng phụ "Preparing citation audit document." |

**Bài học** (lặp lại Lab 2, và có thêm điểm mới):
1. AI tự thêm chữ giải thích và số liệu, kể cả khi đã có quy tắc "tối giản". Sau mỗi vòng phải soát lại chữ trên từng frame.
2. Prompt nhiều ý thì bị bỏ sót (F1, F9). Tách nhỏ (R3a/R3b) hiệu quả hơn.
3. Muốn sửa màn có sẵn thì phải **chọn màn** trước khi gửi prompt. Muốn tạo frame trạng thái mới thì **không chọn gì**, nếu không Stitch sẽ ghi đè lên màn ở trạng thái bình thường.
4. Ảnh chụp không đủ để kiểm chứng accessibility. Phải đo bằng công cụ trên Figma.

## 6. Phần còn phải bổ sung

- `[CẦN BỔ SUNG]` Ảnh chụp bước *Copy to Figma* và page 03 Final UI sau khi sửa tay.
- `[CẦN BỔ SUNG]` Link Figma (quyền xem công khai).
