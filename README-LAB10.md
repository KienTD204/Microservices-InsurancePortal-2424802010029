# Bài thực hành 10 - Review lại kiến trúc của hệ thống

**Trương Đắc Kiên - 2424802010029 - D24CNTT05**

- Nhánh `student/lab10`, kế thừa Bài 9 (`student/lab9`). Bài này không thay đổi mã nguồn của hệ thống.
- Đề bài: [submission/lab10/provided](submission/lab10/provided).

## File nộp (mỗi Task một PDF riêng)

| Task | File nộp | Nội dung |
| --- | --- | --- |
| Task 1 - Kiến trúc tổng quát | [BTH10-Task1-Kien-truc-tong-quat-2424802010029.pdf](submission/lab10/BTH10-Task1-Kien-truc-tong-quat-2424802010029.pdf) (5 trang) | Một sơ đồ 5 tầng có đủ tên 12 thành phần (2 giao diện, Gateway, 9 service) và mọi công nghệ hỗ trợ: Docker/Docker Compose, web server (Kestrel, Nginx, Tomcat nhúng), Ocelot, Eureka, RabbitMQ, PostgreSQL, Elasticsearch, SignalR, JWT...; kèm bảng thành phần, bảng công nghệ và nhận xét review. |
| Task 2 - Bốn khung nhìn | [BTH10-Task2-Kien-truc-4-khung-nhin-2424802010029.pdf](submission/lab10/BTH10-Task2-Kien-truc-4-khung-nhin-2424802010029.pdf) (16 trang) | 10 sơ đồ UML: Logic (sơ đồ gói + 3 sơ đồ lớp), Tiến trình (2 sơ đồ tuần tự + sơ đồ hoạt động), Cài đặt (sơ đồ thành phần + sơ đồ gói), Triển khai (sơ đồ triển khai); mỗi sơ đồ có phần giải thích. |

## Đối chiếu yêu cầu

| Yêu cầu trong đề | Vị trí đáp ứng |
| --- | --- |
| Có tất cả tên của mỗi service | Task 1, Hình 1 và bảng 4.1 |
| Có tất cả công nghệ hỗ trợ (Docker, web server, thành phần đã nhúng/cài đặt) | Task 1, Hình 1 (tầng hạ tầng, nền tảng triển khai, nền tảng phát triển) và bảng 4.2 |
| Khung nhìn Logic | Task 2, mục 2 (Hình 1-4) |
| Khung nhìn Tiến trình | Task 2, mục 3 (Hình 5-7) |
| Khung nhìn Cài đặt | Task 2, mục 4 (Hình 8-9) |
| Khung nhìn Triển khai | Task 2, mục 5 (Hình 10) |
| Dùng UML làm quy ước | Tất cả sơ đồ Task 2 là sơ đồ UML 2 (gói, lớp, tuần tự, hoạt động, thành phần, triển khai), vẽ bằng PlantUML |

## Nguồn gốc nội dung

Sơ đồ được khái quát từ hệ thống thật chứ không thiết kế giả định: tên lớp và thuộc tính lấy từ thư mục `Domain` của từng service; quan hệ giữa các project lấy từ `ProjectReference` trong `*.csproj`; tuyến Gateway lấy từ `AgentPortalApiGateway/ocelot.json`; sự kiện và hàng đợi lấy từ `Startup.cs`/`RabbitInstaller.cs`; container, cổng và phụ thuộc khởi động lấy từ `scripts/lab9.docker.yml` (bản triển khai đã chạy và kiểm chứng ở Bài 9).

## Dựng lại tài liệu

Mã nguồn sơ đồ nằm ở [submission/lab10/diagrams](submission/lab10/diagrams) (`*.puml` cho UML, `gen_overview.py` cho sơ đồ tổng quát), ảnh đã dựng ở `diagrams/out` (SVG và PNG). Nội dung hai tài liệu là `task1.html`, `task2.html` với `report.css`.

```bash
bash submission/lab10/build.sh
```

Script cần Python 3, Docker (dùng JRE trong image `lab-eureka-server` để chạy PlantUML, tệp `plantuml.jar` lấy từ extension PlantUML của VS Code) và Chrome hoặc Edge để in HTML ra PDF.
