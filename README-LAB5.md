# Bài thực hành 5 - PricingService và Eureka

Sinh viên: **Trương Đắc Kiên** - MSSV **2424802010029** - Lớp **D24CNTT05**.

Repository nộp bài: [Microservices-InsurancePortal-2424802010029, nhánh student/lab5](https://github.com/KienTD204/Microservices-InsurancePortal-2424802010029/tree/student/lab5).

## Task 1 - Tích hợp source thầy cung cấp

Ba gói RAR gốc được giữ ở `submission/lab5/provided/`. API và unit test đã có trong source bài 4 và được đối chiếu lại với từng file trong ba gói thầy gửi. Nội dung `PricingService.Api`, `PricingService.Test` và các assertion trong `PricingControllerTest` được giữ nguyên. Chỉ fixture integration được cấu hình PostgreSQL 16, giải phóng tài nguyên an toàn và tắt discovery khi test để không đăng ký nhầm instance kiểm thử.

Project chạy chính `PricingService` lấy từ source bài 4 trong cùng repository, gồm controller, MediatR handler, domain tính phí, Marten/PostgreSQL và dữ liệu mẫu. Không thay thế PostgreSQL bằng dữ liệu giả trong bộ kiểm thử tích hợp.

Chạy đối chiếu ba gói gốc:

```powershell
./scripts/audit-lab5-sources.ps1
```

## Task 2 - Eureka Server và Eureka Client

- Server thật: Spring Cloud Netflix Eureka trong `eureka-server`, cấu hình `application.yml`, cổng **8761**; `registerWithEureka: false`, `fetchRegistry: false`, `waitTimeInMsWhenSyncEmpty: 0`.
- Client: `Steeltoe.Discovery.ClientCore` và `Steeltoe.Discovery.Eureka` **3.2.7**; `AddDiscoveryClient(Configuration)` và `UseDiscoveryClient()` trong `Startup.cs`.
- `PricingService/appsettings.json`: tên `PricingService`, server `http://localhost:8761/eureka/`, đăng ký và truy vấn registry được bật, hostname `localhost`, cổng **5041**.
- `GET /health` trả `UP`; `GET /info` cung cấp thông tin cho liên kết status của Eureka.

**Khác biệt cổng so với PDF:** cổng 5040 không mở được trên laptop Windows này (`SocketException: access permissions`), nên dùng 5041. Cấu hình lắng nghe, launch profile, đăng ký Eureka và script kiểm tra đều dùng cùng 5041. Trên máy khác có thể đổi đồng bộ `Urls`, `Eureka:Instance:Port` và `Properties/launchSettings.json` về 5040 nếu cổng đó dùng được.

## Chạy bài thực hành

Yêu cầu .NET SDK **8.0.425**, Docker Desktop Linux engine, Git. Mở Docker Desktop trước, rồi chạy tại thư mục gốc repository:

```powershell
./scripts/start-lab5.ps1
```

Script build và khởi động hai container Eureka/PostgreSQL của bài 4, chờ Eureka trả HTTP 200, rồi chạy đúng lệnh `dotnet run --project ./PricingService`. Giữ terminal này mở trong khi kiểm tra. Script không xóa volume hay dữ liệu của bài trước.

- Eureka: <http://localhost:8761>
- Swagger: <http://localhost:5041/swagger>
- Kiểm tra dịch vụ: <http://localhost:5041/health>
- Registry: <http://localhost:8761/eureka/apps/PRICINGSERVICE>

Khi khởi động lần đầu, chờ một thời gian ngắn rồi tải lại Eureka. Trong `Instances currently registered with Eureka`, `PRICINGSERVICE` phải có trạng thái **UP** và địa chỉ instance dùng cổng 5041.

Ở terminal PowerShell thứ hai:

```powershell
./scripts/verify-lab5.ps1
```

Script chạy hai bộ test thầy cung cấp, kiểm tra instance Eureka, gọi API tính phí và kiểm tra yêu cầu sai trả HTTP 400. Kết quả TRX/JSON được lưu ở `submission/lab5/evidence/`.

Kết quả chạy ngày 18/10/2026: **10 unit test + 2 integration test đạt, 0 lỗi, 0 bỏ qua**. Build toàn bộ solution thành công, **0 lỗi**. `runtime-verification.json` ghi `PASS`; `heartbeat.txt` ghi nhận các lần gia hạn được Eureka chấp nhận.

Để chỉ chạy test tự động, không cần khởi động Eureka hay PricingService, nhưng Docker phải chạy:

```powershell
dotnet test PricingService.Test/PricingService.Test.csproj -c Release
dotnet test PricingService.IntegrationTest/PricingService.IntegrationTest.csproj -c Release
```

Integration test tạo PostgreSQL riêng bằng Testcontainers, tự seed dữ liệu và tự dọn container. Không cần sửa connection string của máy.

## Ví dụ tính phí

Trong Swagger, mở `POST /api/Pricing`, chọn **Try it out**, dán `submission/lab5/request-travel.json` rồi **Execute**. Với một người lớn, một trẻ em và điểm đến EUR, kết quả phải là:

```json
{
  "totalPrice": 98.0,
  "coverPrices": { "C1": 26.0, "C2": 52.0, "C3": 20.0 }
}
```

Gửi `{}` phải nhận HTTP **400**. Các bài unit test còn kiểm tra phí nhà **172.50** và phí xe **100**.

## Nội dung nộp eLearning

1. Task 1: link repository và **nhánh student/lab5** ở đầu tài liệu này.
2. Task 2: `submission/lab5/Bai-thuc-hanh-5_Minh-chung-Eureka.pdf`, chứa ảnh chụp runtime thật và kết quả kiểm thử.

Hạn trong đề: **18:00 ngày 18/10/2026**. Việc tải lên eLearning thực hiện qua tài khoản sinh viên.

## Giải thích Service Discovery

Eureka Server là **Service Registry**: giữ danh sách các instance đang hoạt động cùng hostname, port và trạng thái. **Registry Client** trong mỗi microservice đăng ký instance, gửi heartbeat và truy vấn registry để tìm dịch vụ khác. Bài này xác minh PricingService đăng ký thành công; không yêu cầu viết mới toàn bộ các dịch vụ ở phụ lục kiến trúc.

Tài liệu tham khảo: [Steeltoe 3 - Initialize Discovery Client](https://steeltoe.io/docs/v3/discovery/initialize-discovery-client.html), [Spring - Service Registration and Discovery](https://spring.io/guides/gs/service-registration-and-discovery/). Với Steeltoe từ 3.1, `UseDiscoveryClient()` không còn bắt buộc; giữ lời gọi để đối chiếu trực tiếp yêu cầu trong đề, nên có cảnh báo obsolete. Các cảnh báo dependency cũ của code bài 4 vẫn được ghi trong log; NuGet audit không bị tắt. Cấu hình này dùng cho bài thực hành local.
