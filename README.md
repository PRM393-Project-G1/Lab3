# Realtron

Hiểu nhanh một bài báo qua danh sách tham khảo của nó: bài dựa trên những mảng kiến thức nào, mỗi mảng có bao nhiêu reference, bao nhiêu trong số đó sai hoặc bịa, và mảng nào "yếu".

PRM393 Lab 3. App Android (Flutter + Firebase). Backend do nhóm chạy trên laptop, truy cập qua Tailscale, dùng hai dự án mã nguồn mở [RefChecker](https://github.com/markrussinovich/refchecker) và [Saffron](https://github.com/insight-centre/saffron).

**Muốn chạy thử:** xem [HUONG_DAN_CHAY.md](HUONG_DAN_CHAY.md).

## Tài liệu

| Nội dung | File |
|---|---|
| Figma (6 page) | [Realtron](https://www.figma.com/design/gPn3Z9LnTN8Js3QxbrH5Gu/Realtron) |
| Persona | [design/persona.md](design/persona.md) |
| User flow, chuỗi chữ trên UI | [design/user-flow.md](design/user-flow.md) |
| Design system | [design/DESIGN.md](design/DESIGN.md) |
| Quyết định thiết kế | [design/design-decisions.md](design/design-decisions.md) |
| Nhật ký AI (Stitch) | [design/ai-design-log.md](design/ai-design-log.md) |
| Bàn giao Flutter | [handoff/flutter-handoff.md](handoff/flutter-handoff.md) |
| Truy vết thiết kế | [docs/design-traceability.md](docs/design-traceability.md) |
| Kiến trúc | [docs/architecture.md](docs/architecture.md) |
| Sự kiện Analytics | [docs/analytics-plan.md](docs/analytics-plan.md) |
| Test plan, test E2E | [docs/test-plan.md](docs/test-plan.md), [e2e_test/](e2e_test/README.md) |
| Cấu hình Firebase | [firebase/README.md](firebase/README.md) |
| Backend (Orchestrator) | [backend/README.md](backend/README.md) |

## Phiên bản

| Công cụ | Phiên bản |
|---|---|
| Flutter | 3.47.4 (stable) |
| Dart | 3.13.3 |
| Google ARTEMIS | commit `351ca8422f7b5b54e80a9c1ce03a222e02415b6b` |

Phiên bản package được ghim trong `pubspec.yaml` và `pubspec.lock`.

## Chạy

```bash
flutter pub get
```

```bash
flutter test
```

```bash
flutter run
```

## AI đã dùng

| Công cụ | Mục đích |
|---|---|
| Google Stitch | Sinh UI |
| Claude (Claude Code) | Viết prompt, phản biện output của Stitch, viết tài liệu, viết code |

## Video demo

`[CẦN BỔ SUNG]`
