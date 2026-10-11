# Kiểm tra bổ sung: chờ dữ liệu báo giá trước khi nhận request

CI đầu tiên build thành công nhưng test tích hợp báo giá nhận HTTP 500. `Startup.Configure` gọi `UseInitializer()` trả về Task và không chờ hoàn tất: việc seed PostgreSQL chạy đồng thời với request đầu tiên. Đã sửa để chờ initializer hoàn tất trước khi đăng ký endpoint.

Hai test PricingService.IntegrationTest chạy lại trên Windows đều đạt; không đổi assertion giá 98 hoặc HTTP 200/400. File TRX ở `tests/seed-fix/`. Kết quả GitHub riêng ở `ci-status.json`; không dùng kết quả Windows để khẳng định CI.

Lần chạy GitHub Actions 38133718612 sau sửa đã hoàn tất thành công: build 0 lỗi và 46 test đạt ở sáu suite. Log riêng ở `github-ci-fixed-run.log`, commit source `af1cedb9b766fb38f9c9d4bfcb6d14a06c89ebb5`.

Lời mời collaborator đến `caotxuan` đã gửi và đang chờ chấp nhận. File `teacher-invitation.json` lưu ID lời mời, không chứa credential.
