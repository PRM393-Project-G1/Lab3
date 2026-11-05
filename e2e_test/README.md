# Test E2E bằng Google ARTEMIS

ARTEMIS commit: `351ca8422f7b5b54e80a9c1ce03a222e02415b6b` (đã ghim trong `pyproject.toml`). Danh sách test case: [`docs/test-plan.md`](../docs/test-plan.md).

## Cần có

- Điện thoại hoặc emulator đã cài APK, bật USB Debugging và ở trong tailnet.
- Tài khoản Google **dành riêng để test**, đã thêm sẵn vào máy.
- Project Firebase đã cấu hình, backend đang chạy, bài `1706.03762` đã phân tích xong.
- Máy chủ ARTEMIS đang chạy, có API key của model trong `.env` của ARTEMIS.

## Biến môi trường

Không ghi các giá trị này vào repo.

| Biến | Bắt buộc | Ý nghĩa |
|---|---|---|
| `ARTEMIS_BASE_URL` | | Mặc định `http://127.0.0.1:8000` |
| `ARTEMIS_DEVICE_SERIAL` | | Khi nối nhiều máy |
| `E2E_TEST_ACCOUNT` | Có | Email tài khoản test |
| `E2E_SERVER_URL` | Có | URL backend qua Tailscale |
| `E2E_STOPPABLE_ARXIV_ID` | TC-15 | Bài chưa có kết quả |
| `E2E_NEW_ARXIV_IDS` | TC-16 | 3 bài chưa phân tích, cách nhau bằng dấu phẩy |
| `E2E_PUSH_COMMAND` | TC-10 | Lệnh nhờ backend gửi push `Analysis done` của bài `1706.03762` |

Thiếu biến nào thì test dùng biến đó được ghi là `skipped`, không tính là đạt.

## Chạy

```bash
uv sync
```

```bash
uv run pytest --count=3
```

```bash
uv run python summarize.py
```

```bash
uv run python exploratory.py
```

Mỗi lần chạy được ghi vào `evidence/e2e/results.jsonl`, kèm trace ID. `summarize.py` in bảng kết quả từ file đó. `exploratory.py` chạy phiên khám phá bằng profile Pro và ghi `evidence/e2e/exploratory.md`.

`--count=3` lặp từng test 3 lần. Test nào không đạt 3/3 thì phải tìm nguyên nhân và ghi vào `docs/test-plan.md`.
