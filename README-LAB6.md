# Bài thực hành 6 - API Gateway Ocelot, Auth, Chat và Dashboard

**Trương Đắc Kiên - 2424802010029 - D24CNTT05**

- Kho nộp bài: https://github.com/KienTD204/Microservices-InsurancePortal-2424802010029/tree/student/lab6
- Nhánh: `student/lab6`, kế thừa Bài thực hành 5 tại commit `a0ce3a3`.
- Solution: `DotNetMicroservicesPoc.sln`, .NET 8; `global.json` chọn SDK 8.0.425.
- Đề gốc và 6 RAR được giữ nguyên trong [submission/lab6/provided](submission/lab6/provided).
- Bài này triển khai 4 task của phần 4 trong đề. Phụ lục kiến trúc là bối cảnh của các bài trước.

## Đối chiếu yêu cầu

| Task trong đề | Nội dung đã có trong solution |
| --- | --- |
| #1 - Ocelot | `AgentPortalApiGateway` tham chiếu `Ocelot`, `Ocelot.Provider.Eureka`, `Ocelot.Cache.CacheManager` cùng phiên bản 23.3.3; khởi tạo `AddOcelot().AddEureka().AddCacheManager(x => x.WithDictionaryHandle())`; gọi `UseOcelot()` trước khi chạy host. |
| #1 - Cấu hình | Gateway mặc định `http://localhost:8099`; đọc appsettings, cấu hình môi trường, ocelot.json và biến môi trường. Eureka URL `http://localhost:8761/eureka/`, không đăng ký chính Gateway, `ValidateCertificates=false` theo đề. |
| #1 - Định tuyến | `/Products/{everything}` -> `/api/Products/{everything}`, `ServiceName=ProductService`, HTTP GET, khám phá dịch vụ Eureka. Giữ `/api/Products/...` cho giao diện từ bài trước; thêm `/Products` để lấy danh mục. |
| #1 - GlobalConfiguration | Có `RequestIdKey=OcRequestId`, `AdministrationPath=/administration`, `UseServiceDiscovery=true`, provider Eureka tại localhost:8761. Các route cũng bật `UseServiceDiscovery` rõ ràng. |
| #2 - Auth | Thư mục `AuthService`, controller `/api/User`, kho agent mẫu, xác thực mật khẩu, cấp JWT với tên/role/avatar, bảo vệ GET hồ sơ. |
| #3 - Chat | Hai project `ChatService`, `ChatService.Api`; SignalR `/agentsChat`, JWT, CQRS notification, consumer RabbitMQ `PolicyCreated`. |
| #4 - Dashboard | Ba project `DashboardService`, `DashboardService.Api`, `DashboardService.Test`; Elasticsearch, thống kê tổng/đại lý/xu hướng, nhận `PolicyCreated`, các bộ kiểm thử từ mẫu. |
| Không lỗi project mới | Kiểm tra toàn bộ solution, không chỉ từng project. Log build, TRX và kết quả chạy thật nằm tại [submission/lab6/evidence](submission/lab6/evidence). |

**Khác biệt cú pháp với ảnh đề:** ảnh minh họa dùng .NET Core 2.1/Ocelot 12 và `ReRoutes`. Các project đính kèm đã dùng .NET 8, nên cấu hình thực thi dùng `Routes` của Ocelot 23.3.3. Sao chép nguyên khóa `ReRoutes` cũ sẽ không tạo ra các route trên phiên bản này. Tham khảo [Routing của Ocelot](https://ocelot.readthedocs.io/en/23.4.3/features/routing.html) và [cấu hình Eureka](https://ocelot.readthedocs.io/en/23.0.0/features/servicediscovery.html). `AdministrationPath` được giữ để đối chiếu đề; bài không cài thêm Administration API/IdentityServer.

## Chạy bằng Docker

Cần Git và Docker Desktop với Linux engine. Tại thư mục gốc repository, chạy từng lệnh và chỉ chuyển bước nếu lệnh trước thành công:

```powershell
git switch student/lab6
docker compose -p insurance-lab -f scripts/infra.windows.yml up -d --build eureka rabbitmq elasticsearch
docker compose -p insurance-lab6 -f scripts/lab6.docker.yml up -d --build lab6
docker compose -p insurance-lab6 -f scripts/lab6.docker.yml ps
```

Đợi `lab6` báo `healthy`, rồi chạy bộ kiểm tra:

```powershell
docker compose -p insurance-lab6 -f scripts/lab6.docker.yml run --rm verify
```

Container `lab6` là môi trường phát triển/kiểm chứng, chạy 5 host bằng SDK .NET 8.0.425. Container `verify` dùng Docker socket để tạo các PostgreSQL/Elasticsearch tạm của Testcontainers; các test không dùng lại database nghiệp vụ. Dữ liệu RabbitMQ/Elasticsearch của lab được giữ trong các volume có sẵn. Mỗi lần chạy verifier tạo một hợp đồng thử có số `LAB6-...` và đại lý riêng để xác minh sự kiện, tránh nhầm với dữ liệu bán hàng có sẵn.

| Thành phần | Địa chỉ |
| --- | --- |
| Gateway | http://localhost:8099 |
| Auth Swagger | http://localhost:6060/swagger |
| Product Swagger | http://localhost:5030/swagger |
| Chat Swagger / Hub | http://localhost:4099/swagger / http://localhost:4099/agentsChat |
| Dashboard Swagger | http://localhost:5035/swagger |
| Eureka | http://localhost:8761 |
| RabbitMQ Management | http://localhost:15672 |

Tài khoản demo: `jimmy.solid/secret`, `danny.solid/secret`, `admin/admin`. Các giá trị cấu hình demo kế thừa mã mẫu.

Ví dụ kiểm tra đúng route trong đề:

```powershell
$taskLogin = Invoke-RestMethod http://localhost:6060/api/User -Method Post -ContentType application/json -Body '{"login":"jimmy.solid","password":"secret"}'
Invoke-RestMethod http://localhost:8099/Products/TRI -Headers @{Authorization="Bearer $($taskLogin.token)"}
```

Dừng các host của Bài 6:

```powershell
docker compose -p insurance-lab6 -f scripts/lab6.docker.yml down
```

## Chạy trực tiếp trên Windows

Nếu máy cho phép chạy DLL được build tại chỗ, có thể dùng:

```powershell
dotnet build DotNetMicroservicesPoc.sln -c Release
& ./scripts/start-lab6.ps1 -SkipBuild
& ./scripts/verify-lab6.ps1
& ./scripts/stop-lab6.ps1
```

Không chạy đồng thời các bản Windows và Docker vì chúng dùng chung cổng. Trong lần kiểm chứng ngày 25/10/2026, build Windows thành công nhưng Application Control từ chối nạp một số DLL (`0x800711C7`), nên kết quả chạy chính thức được lấy từ Docker/Linux. Chính sách Windows không bị thay đổi. Chẩn đoán lần chạy Windows được lưu riêng ở `evidence/windows-attempt` và không tính vào kết quả PASS.

## Nguồn mẫu và các chỉnh sửa

Chạy `./scripts/audit-lab6-sources.ps1` để giải nén bản RAR được lưu cùng bài nộp, kiểm tra từng tệp và ghi SHA256. Đối chiếu đủ **86 tệp**: **74 tệp giữ nguyên**, **12 tệp điều chỉnh**, **0 tệp thiếu**, sau khi chuẩn hóa CRLF/LF. Các archive gốc được giữ nguyên từng byte. Các project trong solution giữ đúng tên thầy cung cấp và dùng `PolicyService.Api` có sẵn từ bài trước.

| Tệp mẫu được điều chỉnh | Lý do |
| --- | --- |
| `AuthService/Controllers/UserController.cs` | Sửa thông báo đăng nhập sai; GET hồ sơ trả login/avatar/sản phẩm, tránh trả cả mật khẩu. |
| `AuthService/DataAccess/InsuranceAgentsInMemoryDb.cs` | Login không tồn tại/null trả kết quả không tìm thấy thay vì exception/HTTP 500. |
| `AuthService/Domain/AuthRequest.cs` | Bắt buộc login và password tại biên API. |
| `ChatService/Commands/SendNotificationHandler.cs` | Notification dùng sự kiện `ReceiveNotification` một tham số, khớp client và consumer; `ReceiveMessage` vẫn dùng ba tham số cho tin nhắn chat. |
| Hai tệp `Messaging/RabbitMq/RabbitEventListener.cs` | Giữ bản sửa từ bài trước: `await Publish` trước khi dispose scope. |
| `DashboardService/Init/SalesData.cs` | Không xóa index đã tồn tại khi khởi động lại; seed chỉ refresh một lần, kiểm tra lỗi ghi dữ liệu. |
| `DashboardService/DataAccess/Elastic/NestInstaller.cs`, `ElasticPolicyRepository.cs` | Dùng chỉ mục `policy_lab_stats_v2` có mapping tiền tệ rõ ràng để không mất phần thập phân. |
| `DashboardService.Test/ElasticSearchInContainerFixture.cs` | Giữ fixture bài trước: image Elasticsearch đúng phiên bản, port ngẫu nhiên và địa chỉ container thực; bổ sung dữ liệu kiểm tra chuyển đổi mapping cũ. |
| `DashboardService.Test/GetAgentsSalesQueryTest.cs` | Giữ bản sửa kỳ vọng từ bài trước: 6 hợp đồng của Jimmy tổng 630, 5 hợp đồng của Danny tổng 325 theo dữ liệu fixture. |
| `DashboardService.Test/GetSalesTrendsResultAssert.cs` | So sánh với `expectedCount`, thay cho phép so sánh một biến với chính nó. |

Gateway được cập nhật riêng trong task #1. `AuthService.Test/AuthenticationTests.cs`, `DashboardService.Test/PremiumPrecisionTest.cs`, `tools/Lab6.Verifier` và các script Bài 6 là phần kiểm chứng bổ sung của bài làm. `PolicyIndex.cs` khởi tạo mapping `scaled_float` với hệ số 100 và sao chép dữ liệu từ `_source` của chỉ mục cũ sang `policy_lab_stats_v2`. Chỉ mục cũ được giữ nguyên; khi chạy lại, các ID đã có được bỏ qua để không ghi đè dữ liệu mới. Tham khảo [kiểu số của Elasticsearch](https://www.elastic.co/docs/reference/elasticsearch/mapping-reference/number). Giữ LICENSE và ghi nguồn upstream trong README gốc.

## Minh chứng và giới hạn

Kết quả kiểm chứng ngày **25/10/2026**: solution build **0 lỗi**, **56/56 test đạt**, **20/20 kiểm tra chạy thật đạt**, dữ liệu hợp đồng vẫn giữ nguyên sau khi khởi động lại dịch vụ. Build Linux đầy đủ có **55 cảnh báo** từ mã/thư viện nền. Chi tiết máy đọc được ở [verification-summary.json](submission/lab6/evidence/verification-summary.json).

| Suite | Số test đạt |
| --- | ---: |
| AuthService.Test | 8 |
| ProductService.Test | 14 |
| PricingService.Test | 10 |
| PolicyService.Test | 8 |
| PaymentService.Test | 6 |
| DashboardService.Test | 8 |
| PricingService.IntegrationTest | 2 |

- `solution-build.txt`: build trên Windows; `solution-build-linux.txt`: build trong Docker.
- `tests-linux/*.trx`: 7 suite kiểm thử, gồm các suite từ bài trước và kiểm thử JWT mới.
- `runtime-verification.json`: kiểm tra HTTP, JWT, 4 route sản phẩm, hai client SignalR, notification, sự kiện RabbitMQ tới Chat/Dashboard và Eureka. Không lưu token vào minh chứng.
- `restart-persistence.json` và `restart-before-runtime-verification.json`: dữ liệu trước/sau khi khởi động lại dịch vụ.
- `teacher-source-audit.json`: đối chiếu sáu archive với các project.
- Workflow GitHub Actions được cập nhật để chạy 7 suite. Kết quả CI xem tại tab Actions của commit được nộp.

`first-linux-attempt` giữ kết quả trước khi sửa việc mất phần thập phân. Khi chạy lại toàn solution, bộ test Policy từ bài trước bộc lộ lỗi chạy song song: hai lớp cùng thay đổi `SysTime.CurrentTimeProvider`. Bài làm đưa `OfferTest` và `PolicyTerminationTest` vào cùng collection `Shared policy clock` để chúng chạy lần lượt, giữ nguyên các assertion và nghiệp vụ. TRX lần lỗi được lưu riêng tại `clock-race-attempt`.

Các project scaffold ngoài phạm vi Bài 6 vẫn được ghi rõ trong tài liệu bài trước. Những cảnh báo NuGet và API cũ của source nền được giữ nguyên và hiện trong log build; bài này không nâng cấp hàng loạt các dependency ngoài yêu cầu. Build 0 lỗi không đồng nghĩa 0 cảnh báo.
