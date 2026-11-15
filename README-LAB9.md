# Bài thực hành 9 - Triển khai hệ thống (PolicyService, PolicySearchService)

**Trương Đắc Kiên - 2424802010029 - D24CNTT05**

- Kho bài làm: https://github.com/KienTD204/Microservices-InsurancePortal-2424802010029/tree/student/lab9
- Nhánh `student/lab9`, kế thừa đầy đủ Bài 7 tại commit `b2b990c`.
- Solution `DotNetMicroservicesPoc.sln`, .NET 8; SDK 8.0.425 theo `global.json`.
- Đề PDF và năm RAR gốc: [submission/lab9/provided](submission/lab9/provided).
- Tệp `.txt` để nộp: [2424802010029_TruongDacKien_BTH9_GitHub.txt](submission/lab9/2424802010029_TruongDacKien_BTH9_GitHub.txt).

## Task 1 - Bổ sung code PolicyService và PolicySearchService (5 thư mục)

| Yêu cầu trong đề | Phần hoàn thành |
| --- | --- |
| Bổ sung code 5 thư mục từ file nén | Đủ năm project `PolicyService`, `PolicyService.Api`, `PolicyService.Test`, `PolicySearchService`, `PolicySearchService.Api` trong solution, đúng cấu trúc thư mục và tên file của mã mẫu. |
| Xử lý khác biệt tên project/file | Chọn phương án thầy khuyên dùng: **giữ nguyên tên theo mã mẫu**. Namespace, `ProjectReference` và tên file trùng với RAR, không phải đổi tên ở nơi sử dụng. |
| Hệ thống không còn lỗi | Build toàn bộ solution trên Windows: **0 lỗi** ([log](submission/lab9/evidence/solution-build-windows.txt)). `PolicyService.Test`: **8/8 test đạt** ([TRX](submission/lab9/evidence/tests/PolicyService.Test.trx)). |

### Đối chiếu với năm RAR

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\audit-lab9-sources.ps1
```

Kết quả: **97/97 tệp có mặt**, **94 tệp giữ nguyên**, **3 tệp điều chỉnh**, **0 tệp thiếu**. So sánh sau khi chuẩn hóa CRLF/LF; SHA256 từng tệp và từng archive nằm trong [teacher-source-audit.json](submission/lab9/evidence/teacher-source-audit.json).

| Tệp điều chỉnh so với mẫu | Lý do |
| --- | --- |
| `PolicySearchService/Messaging/RabbitMq/RabbitEventListener.cs` | `await` handler trước khi hủy DI scope, để việc ghi vào Elasticsearch hoàn tất trước khi scope bị đóng. |
| `PolicyService.Test/Domain/OfferTest.cs` | Hai lớp test cùng thay đồng hồ tĩnh `SysTime`; đặt chung một xUnit collection để không chạy song song và ghi đè thời gian của nhau. |
| `PolicyService.Test/Domain/PolicyTerminationTest.cs` | Cùng lý do trên. Các assertion của mã mẫu được giữ nguyên. |

### Vai trò của hai service trong hệ thống

- **PolicyService** (cổng 5050): tạo báo giá (`POST /api/Offer`, gọi PricingService qua REST + Eureka), chuyển báo giá thành hợp đồng (`POST /api/Policy`), xem hợp đồng (`GET /api/Policy/{number}`), hủy hợp đồng. Lưu PostgreSQL bằng NHibernate; phát sự kiện `PolicyCreated`/`PolicyTerminated` lên RabbitMQ theo mẫu Outbox.
- **PolicySearchService** (cổng 5065): nghe `PolicyCreated` từ RabbitMQ, lập chỉ mục hợp đồng vào Elasticsearch và cung cấp `GET /api/PolicySearch?q=...`.

## Task 2 - Triển khai và demo

### Cách triển khai

Toàn bộ hệ thống được triển khai bằng Docker Compose: [scripts/lab9.docker.yml](scripts/lab9.docker.yml) gồm 4 dịch vụ hạ tầng (Eureka, PostgreSQL 16, Elasticsearch 8.9.2, RabbitMQ), 9 microservice .NET và giao diện Blazor. Một image duy nhất ([scripts/lab9.Dockerfile](scripts/lab9.Dockerfile)) build cả solution; mỗi container chạy một service từ image đó với môi trường `docker` (dùng các `appsettings.docker.json` có sẵn).

Lý do chọn Docker thay vì chạy `dotnet` trực tiếp: trên máy làm bài, Windows Smart App Control chặn một số DLL vừa build (Gateway, Chat, Payment, PolicySearch, Pricing báo `An Application Control policy has blocked this file`). Container Linux không bị ảnh hưởng và không cần thay đổi thiết lập bảo mật của Windows.

Yêu cầu: Docker Desktop (Linux engine) đang chạy, **ổ chứa dữ liệu Docker còn trống khoảng 10 GB**, RAM cấp cho Docker từ 6 GB.

```powershell
git switch student/lab9
docker compose -p insurance-lab9 -f scripts/lab9.docker.yml up -d --build --wait --wait-timeout 900
docker compose -p insurance-lab9 -f scripts/lab9.docker.yml ps
powershell -ExecutionPolicy Bypass -File .\scripts\verify-lab9.ps1
```

| Thành phần | Địa chỉ |
| --- | --- |
| Giao diện web (Blazor) | http://localhost:5081 |
| API Gateway (Ocelot) | http://localhost:8099 |
| AuthService / ChatService | http://localhost:6060 / http://localhost:4099 |
| Product / Policy / PolicySearch / Payment / Dashboard | 5030 / 5050 / 5065 / 5070 / 5035 |
| Eureka | http://localhost:8761 |
| RabbitMQ Management | http://localhost:15672 (guest / guest) |
| Elasticsearch | http://localhost:9200 |

Tài khoản demo: `jimmy.solid / secret`, `danny.solid / secret`, `admin / admin`.

`verify-lab9.ps1` kiểm tra tự động chuỗi: Eureka → đăng nhập JWT → danh mục sản phẩm qua Gateway → tạo báo giá (Policy gọi Pricing) → tạo hợp đồng → tìm thấy hợp đồng trong PolicySearch (RabbitMQ → Elasticsearch) → tài khoản thanh toán được mở trong PaymentService → Dashboard → SignalR của ChatService. Kết quả ghi vào `submission/lab9/evidence/runtime-verification.json`.

Dừng hệ thống: `docker compose -p insurance-lab9 -f scripts/lab9.docker.yml down` (thêm `-v` để xóa luôn dữ liệu).

### Kết quả kiểm chứng (15/11/2026)

- Đối chiếu mã nguồn 97/97, build Windows 0 lỗi, 8/8 test PolicyService.
- Build image Linux thành công; **14/14 container `healthy`** ([docker-status.txt](submission/lab9/evidence/docker-status.txt)).
- `verify-lab9.ps1`: **11/11 bước đạt** ([runtime-verification.json](submission/lab9/evidence/runtime-verification.json)).
- Thử tay trên giao diện Blazor: đăng nhập, xem sản phẩm, tính giá (108.00 EUR), tạo hợp đồng, tìm hợp đồng theo tên người mua và gửi tin nhắn Chat đều chạy.

### Lỗi đã sửa khi triển khai

| Tệp | Lỗi và cách sửa |
| --- | --- |
| `BlazorWasmClient/Components/Auth/AuthResponse.cs` | AuthService trả hạn token ở trường `expiryTimeStamp`, còn client đọc thuộc tính `ExpiresIn`, nên hạn luôn là `DateTime.MinValue`: phiên bị coi là hết hạn, mọi lời gọi Gateway sau khi đăng nhập không kèm token và nhận **HTTP 401** (trang Products trắng). Thêm `[JsonPropertyName("expiryTimeStamp")]` để ánh xạ đúng trường. |

Lưu ý: bản sửa này đã được build lại và chạy thử ngay trong container `web` đang chạy; do ổ đĩa của máy làm bài gần đầy nên image `insurance-lab9` chưa được build lại từ đầu sau khi sửa. Lần `up --build` kế tiếp sẽ đưa bản sửa vào image.

### Kịch bản quay video (ít nhất 2 chức năng)

1. **Bán bảo hiểm và tìm kiếm hợp đồng** (PolicyService + PolicySearchService): đăng nhập `jimmy.solid` → *Products* → chọn sản phẩm → nhập tham số → tính giá → nhập thông tin người mua → tạo hợp đồng → *Policies* → tìm theo tên người mua vừa nhập.
2. **Chat trực tuyến** (ChatService/SignalR): mở thêm một cửa sổ ẩn danh, đăng nhập `danny.solid`; cả hai vào *Chat* và nhắn qua lại. Khi một bên tạo hợp đồng mới, bên kia nhận thông báo tức thời.
Lưu ý khi thao tác: ô ngày nhập theo dạng tháng/ngày/năm; sau khi bấm **Calculate price** phải bấm **Buy**, điền đủ 7 ô thông tin người mua rồi bấm **Confirm**. Ở trang *Policies*, gõ họ người mua vào ô **Policy holder** rồi bấm **Search**.

3. (Tùy chọn) **Thanh toán**: mở `http://localhost:5070/api/Payment/accounts/<số hợp đồng>` để thấy tài khoản hợp đồng do PaymentService tạo từ sự kiện `PolicyCreated`.
