# Bài thực hành 7 - Lưu trữ và truy cập dữ liệu cùng Marten

**Trương Đắc Kiên - 2424802010029 - D24CNTT05**

- Kho bài làm: https://github.com/KienTD204/Microservices-InsurancePortal-2424802010029/tree/student/lab7
- Nhánh `student/lab7`, kế thừa đầy đủ Bài 6 tại commit `3bbedb0`.
- Solution `DotNetMicroservicesPoc.sln`, .NET 8; SDK 8.0.425 theo `global.json`.
- Đề PDF và sáu RAR gốc: [submission/lab7/provided](submission/lab7/provided).
- Tệp `.txt` để nộp: [2424802010029_TruongDacKien_BTH7_GitHub.txt](submission/lab7/2424802010029_TruongDacKien_BTH7_GitHub.txt).

## Đối chiếu từng task

| Yêu cầu trong đề | Phần hoàn thành |
| --- | --- |
| Task #1 - Thêm Marten bằng NuGet | `PaymentService/PaymentService.csproj` tham chiếu **Marten 7.19.1**, đúng phiên bản trong RAR. `Startup.ConfigureServices` đăng ký `AddMarten`, kết nối PostgreSQL và kho dữ liệu có phạm vi theo request. |
| Task #2 - Bổ sung ba project PaymentService | Đủ `PaymentService`, `PaymentService.Api`, `PaymentService.Test` trong solution. Có domain tài khoản/bút toán, Marten repository/session, serializer hỗ trợ protected setter và tham chiếu vòng, API số dư, consumer `PolicyCreated`/`PolicyTerminated`, seed và Hangfire nhập sao kê như mã mẫu. |
| Task #3 - Bổ sung ba project ProductService | Đủ `ProductService`, `ProductService.Api`, `ProductService.Test` trong solution. Có danh mục, cover/question/choice, DTO và converter đa hình, CQRS command/query, EF repository, seed bốn sản phẩm và API. |
| Giữ đúng tên và các tham chiếu | Giữ nguyên sáu tên project của thầy; Payment tham chiếu `PaymentService.Api` và `PolicyService.Api`; Product tham chiếu `ProductService.Api`; hai project test tham chiếu đúng service. |
| Project phải build được | Build **toàn bộ solution** trên Windows và Linux, đều **0 lỗi**. Log, TRX và bằng chứng chạy thật ở [evidence](submission/lab7/evidence). |
| Nộp link GitHub dạng `.txt` | Có tệp link trỏ trực tiếp tới nhánh Bài 7, kèm thông tin sinh viên. |

Phần phụ lục của đề là kiến trúc tham khảo từ Bài 3. ProductService giữ Entity Framework và chế độ InMemory của mẫu; Marten được dùng cho aggregate `PolicyAccount` của PaymentService, không thay EF bằng Marten trái với sáu RAR.

## Đối chiếu với sáu RAR

Các tệp đã có ở Bài 6 được giữ và đối chiếu lại với chính sáu RAR Bài 7. Chạy trên Windows:

```powershell
./scripts/audit-lab7-sources.ps1
```

Kết quả: **107/107 tệp có mặt**, **104 tệp giữ nguyên**, **3 tệp điều chỉnh**, **0 tệp thiếu**. Đối chiếu chuẩn hóa CRLF/LF; archive gốc được giữ nguyên từng byte và có SHA256 trong [teacher-source-audit.json](submission/lab7/evidence/teacher-source-audit.json).

| Tệp điều chỉnh so với mẫu | Lý do |
| --- | --- |
| `PaymentService/Messaging/RabbitMq/RabbitEventListener.cs` | Kế thừa bản sửa từ bài trước: `await` xử lý notification trước khi hủy DI scope, tránh đóng phiên Marten khi handler còn đang ghi dữ liệu. |
| `PaymentService/Startup.cs` | Đợi `UseInitializer()` hoàn tất trước khi mở HTTP và đăng ký consumer; tránh request/sự kiện đến khi schema và dữ liệu demo chưa khởi tạo xong. |
| `PaymentService.Test/PaymentService.Test.csproj` | Thêm `Testcontainers.PostgreSql` 3.9.0, cùng phiên bản hạ tầng kiểm thử của solution, để xác minh Marten trên PostgreSQL 16 riêng. |

Các file `PaymentService.Test/Persistence/*`, Dockerfile và script Bài 7 là phần kiểm chứng bổ sung. Giữ nguyên các assertion và sáu test domain Payment, mười bốn test Product của mẫu. Giữ LICENSE và nguồn upstream trong README gốc.

## Build và chạy kiểm thử

Build trực tiếp trên Windows với .NET SDK 8.0.425:

```powershell
dotnet build DotNetMicroservicesPoc.sln -c Release --nologo
```

Để chạy cùng môi trường Linux/PostgreSQL đã kiểm chứng, cần PowerShell 7 và Docker Desktop với Linux engine. Tại root repository, chạy lần lượt và chỉ chuyển bước khi lệnh trước thành công:

```powershell
git switch student/lab7
docker compose -p insurance-lab7 -f scripts/lab7.docker.yml build verify
docker compose -p insurance-lab7 -f scripts/lab7.docker.yml run --rm verify
```

Verifier build toàn bộ solution và chạy 7 suite. Testcontainers dùng PostgreSQL 16 và Elasticsearch 8.9.2 tạm, cổng ngẫu nhiên; container kiểm thử tự dọn sau khi chạy. Docker socket được gắn vào verifier để Testcontainers tạo môi trường thử. Các TRX và log build Linux được xuất ra `submission/lab7/evidence`.

| Suite | Số test đạt |
| --- | ---: |
| AuthService.Test | 8 |
| ProductService.Test | 14 |
| PricingService.Test | 10 |
| PolicyService.Test | 8 |
| PaymentService.Test | 11 |
| DashboardService.Test | 8 |
| PricingService.IntegrationTest | 2 |
| **Tổng** | **61/61** |

Năm test Marten bổ sung kiểm tra: khôi phục owner/protected setter và đúng loại bút toán/tham chiếu sau khi mở DocumentStore mới; số hợp đồng duy nhất và rollback toàn bộ batch lỗi; insert/update chỉ được lưu khi commit; handler tạo/hủy hợp đồng xử lý lặp mà không nhân đôi tài khoản/hoàn tiền; seed demo không bị nhân đôi.

## Chạy hai service và kiểm tra dữ liệu thật

```powershell
docker compose -p insurance-lab7 -f scripts/lab7.docker.yml up -d --wait --wait-timeout 180 postgres rabbit payment product
./scripts/verify-lab7-runtime.ps1
docker compose -p insurance-lab7 -f scripts/lab7.docker.yml ps
```

| Thành phần Bài 7 | Địa chỉ |
| --- | --- |
| Product Swagger | http://localhost:15030/swagger |
| Product API | http://localhost:15030/api/Products |
| Payment Swagger | http://localhost:15070/swagger |
| Tài khoản demo | http://localhost:15070/api/Payment/accounts/POLICY_1 |
| RabbitMQ Management | http://localhost:15673 (`guest` / `guest`) |

Môi trường này dùng network/volume riêng và các cổng 15030/15070/15673. PostgreSQL chỉ mở trong network Docker; dữ liệu ở volume `insurance-lab7_lab7_pgdata`. Thông tin đăng nhập trong compose là dữ liệu demo cho bài thực hành.

Kết quả ngày **01/11/2026: 9/9 kiểm tra chạy thật đạt**. Script kiểm tra danh mục bốn sản phẩm, cover/question của TRI, ba tài khoản demo, cột JSONB PostgreSQL, sự kiện RabbitMQ tạo/hủy tài khoản và dữ liệu sau khi restart PaymentService. Mỗi lần chạy tạo một hợp đồng thử có tiền tố `LAB7-`, để kiểm chứng không phụ thuộc dữ liệu cũ. Kết quả chi tiết ở [runtime-verification.json](submission/lab7/evidence/runtime-verification.json).

Dừng môi trường Bài 7 và giữ dữ liệu:

```powershell
docker compose -p insurance-lab7 -f scripts/lab7.docker.yml down
```

## Minh chứng và giới hạn

- `solution-build-windows.txt`: build Windows cuối, 0 lỗi; số cảnh báo tùy build đầy đủ hay incremental.
- `solution-build-linux.txt`: build Linux đầy đủ, 0 lỗi và 54 cảnh báo từ source/thư viện nền.
- `tests-linux/*.trx` và `tests-linux.txt`: 61 test đạt, 0 thất bại, 0 bỏ qua.
- `teacher-source-audit.json`: đối chiếu từng tệp và SHA256 của sáu RAR.
- `runtime-verification.json`: kiểm tra HTTP, JSONB, RabbitMQ và dữ liệu sau khi restart.
- `verification-summary.json`: tổng hợp kết quả máy đọc được.

NuGet vẫn báo các cảnh báo của dependency cũ trong mẫu, gồm Marten/Steeltoe/NHibernate. Không tắt audit, không che cảnh báo và không nâng hàng loạt phiên bản ngoài yêu cầu Bài 7. Mã và tài khoản demo phục vụ bài thực hành; build 0 lỗi không đồng nghĩa 0 cảnh báo. Các project scaffold ngoài phạm vi Bài 7 được mô tả trong tài liệu những bài trước.

Workflow GitHub Actions `Lab build and tests` chạy lại build và cùng 7 suite khi push, gồm các test PostgreSQL mới trong `PaymentService.Test`. Xem trạng thái của đúng commit ở tab Actions.
