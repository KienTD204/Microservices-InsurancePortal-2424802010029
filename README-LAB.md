# Bài thực hành Microservices - Trương Đắc Kiên

**Bài thực hành 5:** xem [README-LAB5.md](README-LAB5.md) để chạy PricingService, Eureka và xem bằng chứng nộp bài mới.

- Sinh viên: **Trương Đắc Kiên**
- MSSV: **2424802010029**
- Lớp: **D24CNTT05**
- GitHub: **KienTD204**
- Bài thực hành 3: Task 1 (21 đối tượng), Task 2 (nghiệp vụ và UML).
- Bài thực hành 4: solution, tích hợp source, môi trường, build và backup PostgreSQL.

Source tham khảo: [asc-lab/dotnetcore-microservices-poc](https://github.com/asc-lab/dotnetcore-microservices-poc), commit `6500daaf5ca6287385bfdfe5246cd1f3959c73fd`. Giữ LICENSE của tác giả. Sáu RAR được đối chiếu và tích hợp trên source đầy đủ; phần khung bổ sung ghi trong `SCAFFOLD.md` của từng project.

## Chạy trên Windows

Yêu cầu: .NET SDK 8.0.425, Git và Docker Desktop với Linux engine. Web cũ cần Node **10.24.0** do `node-sass` 4.9.2; sử dụng runtime riêng cho lab. `global.json` chọn SDK .NET 8.

Trong PowerShell tại root repository, chạy từng bước và chỉ chuyển tiếp khi lệnh trước thành công:

```powershell
dotnet build .\DotNetMicroservicesPoc.sln -c Release
docker compose -p insurance-lab -f .\scripts\infra.windows.yml up -d --build
docker exec postgres pg_isready -U postgres -d postgres
docker exec rabbit rabbitmq-diagnostics -q ping
Invoke-RestMethod http://localhost:9200
Invoke-WebRequest http://localhost:8761 -UseBasicParsing
& .\scripts\start-services.windows.ps1
```

Script khởi động các host .NET từ bản Release, ghi PID và log vào `.runtime`. Auth 6060, Chat 4099, Product 5030, Pricing **5041**, Policy 5050, Search 5065, Payment 5070, Dashboard 5035, Gateway 8099, Blazor 5081. Pricing dùng 5041 vì 5040 bị CDPSvc trên máy Windows chiếm; script đăng ký đúng port mới với Eureka. Script không khởi động DocumentService scaffold.

Mở Blazor tại `http://localhost:5081`. Tài khoản demo: `jimmy.solid/secret`; `danny.solid/secret`; `admin/admin`. Auth cấp JWT, gateway kiểm tra quyền; backend và database là môi trường lab local.

Với Vue, chọn đường dẫn Node 10.24.0 đã cài trên máy (không nhập nguyên placeholder):

```powershell
$taskNode10Directory = 'C:\Tools\node-v10.24.0-win-x64'
$env:PATH = "$taskNode10Directory;" + $env:PATH
Set-Location .\Web
npm.cmd ci
Set-Location ..
& .\scripts\start-vue.windows.ps1 -NodeExecutable "$taskNode10Directory\node.exe"
```

Script tạo `.env.local` nếu chưa có với gateway 8099, auth 6060 và chat 4099; mở `http://localhost:8080`. Để build Vue cho cấu hình local, tạo `.env.local` với ba biến trên rồi chạy `npm.cmd run build` trong Web. Thư mục `dist` được tạo lại, không đưa dependency cache/build output vào Git.

## Kiểm thử

```powershell
$env:Eureka__Client__ShouldRegisterWithEureka='false'
$env:Eureka__Client__ShouldFetchRegistry='false'
$env:Logging__EventLog__LogLevel__Default='None'
foreach ($taskProject in @('ProductService.Test','PricingService.Test','PolicyService.Test','PaymentService.Test','DashboardService.Test','PricingService.IntegrationTest')) {
    dotnet test ".\$taskProject\$taskProject.csproj" -c Release --no-build --no-restore
    if ($LASTEXITCODE -ne 0) { throw "Test thất bại: $taskProject" }
}
```

Dùng terminal riêng cho test để các biến tắt discovery không áp dụng sang lần chạy ứng dụng. Integration tests dùng Docker và container tạm; Dashboard lấy port random, Pricing dùng PostgreSQL 16. Sáu suite có **46 test case đạt** tại máy Windows; các Test scaffold chưa có test case mới.

## Hồ sơ và bằng chứng

- `submission/reports`: ba báo cáo PDF và use case UML.
- `submission/evidence/Build-Success.png`: ảnh chụp thật cửa sổ VS Code hiển thị kết quả build.
- `submission/evidence/solution-build.txt`: log build cuối, 0 lỗi và 23 cảnh báo (incremental).
- `submission/evidence/solution-build-before-runtime-fix.txt`: full build ban đầu, 0 lỗi và 57 cảnh báo.
- `submission/evidence/tests`: TRX cuối cùng và TRX lần lỗi đầu được ghi riêng.
- `submission/evidence/runtime-checks.json`: HTTP checks, token đã được loại khỏi dữ liệu public.
- `submission/postgres`: bốn backup custom-format, TOC, manifest SHA256 và hướng dẫn restore.

Các chỉnh sửa: Eureka runtime chuyển sang Eclipse Temurin Java 8 bằng Dockerfile bổ sung; PostgreSQL 16 cùng owner/schema permissions; consumer RabbitMQ `async/await` giữ DI scope tới khi hoàn tất; fixture integration không chiếm cổng lab; Pricing dùng cổng Windows phù hợp. Các assertion test nghiệp vụ được giữ.

## Phạm vi chưa triển khai

DocumentService chỉ là khung theo Task 1; **chưa có JS Report/chứng chỉ PDF**. Search đã kiểm tra tìm hợp đồng, chưa triển khai tìm toàn bộ báo giá. SignalR đã kiểm tra negotiation có JWT, chưa kiểm thử trọn luồng chat hai chiều. Cảnh báo bảo mật NuGet của Marten/Steeltoe/NHibernate còn được giữ và báo cáo; audit không bị tắt. Cấu hình demo và dependency cũ phục vụ bài thực hành, không phải cấu hình triển khai production.

Workflow `Lab build and tests` tự chạy build/test khi push; kết quả GitHub Actions phải xem ở tab Actions, không suy ra từ log local.
