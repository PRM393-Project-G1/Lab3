# Backend (Orchestrator)

Service FastAPI nhận lệnh từ app qua Tailscale, chạy RefChecker và Saffron, rồi ghi tiến độ, kết quả và push qua Firebase. App đọc kết quả từ Firestore, nên xem lại được khi máy này tắt.

```
POST /api/analyses
  → RefChecker: đọc và kiểm tra reference
  → lấy văn bản: toàn văn arXiv → abstract → tiêu đề + câu trích dẫn
  → Saffron: rút chủ đề, dựng cây
  → ghi analyses/{id}, references, topics → notification + FCM
```

Hợp đồng API và tên trường: [`docs/architecture.md`](../docs/architecture.md), mục 7 và 8.

## Cần có

| Thành phần | Dùng để | Ghi chú |
|---|---|---|
| Python 3.12 | Chạy service | |
| Khoá service account | Ghi Firestore, gửi FCM, xác thực token | Bước 8 trong [`firebase/README.md`](../firebase/README.md). **Không commit** |
| Java 8 (JRE) | Chạy Saffron | Mục "Cài Saffron" |
| Docker | Chạy GROBID | Không cần nếu có key LLM |
| Key LLM | Đọc danh sách reference khó và tìm reference bịa | Không có thì bước Fabrication check không chạy |
| Tailscale | Điện thoại gọi được máy này | |

## Cài đặt

Chạy trong `backend/`:

```bash
py -3.12 -m venv .venv
```

```bash
.venv/Scripts/python -m pip install -r requirements.txt
```

```bash
copy .env.example .env
```

Sau đó điền `.env`.

## Chạy

GROBID, nếu không dùng LLM để đọc reference:

```bash
docker run -d --name realtron-grobid -e JAVA_TOOL_OPTIONS=-XX:-UseContainerSupport -p 127.0.0.1:8070:8070 lfoppiano/grobid:0.8.2
```

Service, thay IP bằng kết quả của `tailscale ip -4`:

```bash
.venv/Scripts/uvicorn --factory orchestrator.main:build_app --env-file .env --host 100.114.197.87 --port 8000
```

Trong app, màn Connect nhập `http://100.114.197.87:8000`.

Mỗi job ghi file trung gian và log vào `work/{arxivId}/`. Xem `refchecker.log` và `saffron.log` khi job thất bại. Chạy lại một bài thì kết quả RefChecker đã có được dùng lại, nên không tốn lại lượt gọi API.

**Nếu app báo `Can't reach server`:** bật Tailscale trên điện thoại, kiểm tra service còn chạy, và cho phép Python qua Windows Firewall.

**Tham số `JAVA_TOOL_OPTIONS` của GROBID là bắt buộc trên máy này.** Không có nó, JVM trong container lỗi ngay khi khởi động vì không đọc được cgroup. RefChecker tự bật GROBID được, nhưng không có tham số này, nên hãy bật trước bằng lệnh trên.

## Nạp trước bài demo

Lệnh này chạy đúng các bước của service và ghi kết quả thật lên Firestore, nên app mở được ngay, không cần chờ. Bài đã xong thì bỏ qua; thêm `--force` để chạy lại.

```bash
.venv/Scripts/python -m orchestrator.seed 1706.03762 1409.0473
```

Bài chạy khi chưa có key LLM thì chưa được kiểm tra reference bịa. Sau khi thêm key, chạy lại bằng `--force`.

## Cài Saffron

**Máy chủ tải model của Saffron đã ngừng hoạt động** (`server1.nlp.insight-centre.org/saffron-datasets` trả về 404), nên không chạy được theo hướng dẫn gốc. Bộ cấu hình ở đây thay thế như sau:

| Model gốc | Thay bằng |
|---|---|
| `en-pos-maxent.bin` | Cùng file OpenNLP, tải từ [bản sao của Apache](https://apache.googlesource.com/incubator-nlpcraft/+/409e5f9337f85c4f36fc4c45900482a01ef787f5/external/opennlp/en-pos-maxent.bin) |
| `default.json` (mô hình dựng cây) | Train lại từ `benchmarks/data/texeval/food_en` có sẵn trong repo Saffron |
| `wiki-terms.json.gz` | Bỏ: `saffron-config.json` không dùng đặc trưng `weirdness` |
| `en-lemmatizer.dict.txt` | Bỏ: lemmatizer là tuỳ chọn |
| Model của knowledge graph | Không cần: chạy với `-k TAXO` |

Mô hình `default.json` train trên dữ liệu về ẩm thực, nhưng chỉ học từ các đặc trưng không phụ thuộc lĩnh vực (chuỗi con, độ trùng từ, tần suất), nên vẫn dùng được cho bài báo. Chất lượng cây **chưa được đánh giá bài bản**.

Các bước đã làm, chạy trong thư mục repo Saffron, với `T` là thư mục chứa công cụ. Saffron cần JDK để build (đã thử JDK 25) và Java 8 để chạy.

```bash
mvn -B -q -DskipTests -Dmaven.repo.local=$T/m2 -pl run -am install
```

```bash
mvn -B -q -Dmaven.repo.local=$T/m2 -pl run dependency:copy-dependencies -DoutputDirectory=$T/saffron-home/lib -DincludeScope=runtime
```

```bash
cp run/target/saffron-run-4.0.0.jar $T/saffron-home/lib/
```

Tải `en-pos-maxent.bin` vào `$T/saffron-home/models/`, rồi train:

```bash
java -cp "$T/saffron-home/lib/*" org.insightcentre.nlp.saffron.taxonomy.supervised.Train -c train-config.json -d benchmarks/data/texeval/food_en-doc-topics.json -p benchmarks/data/texeval/food_en-topics.json -t benchmarks/data/texeval/food_en.taxo
```

Trong đó `train-config.json` là:

```json
{"taxonomy": {"negSampling": 5.0, "features": {"gloveFile": null, "hypernyms": null, "featureSelection": null}, "modelFile": "${saffron.home}/models/default.json"}}
```

`SAFFRON_HOME` phải dùng **dấu `/`**: Saffron làm mất dấu `\` trong đường dẫn.

## Test

```bash
.venv/Scripts/python -m pytest
```

Test dùng Firebase giả và các bước giả, không gọi mạng.
