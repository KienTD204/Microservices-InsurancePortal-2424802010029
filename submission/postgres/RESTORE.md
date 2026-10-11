# Khôi phục PostgreSQL cho bài nộp

Sinh viên: Trương Đắc Kiên - 2424802010029 - D24CNTT05.

Bốn file `.backup` dùng custom format của `pg_dump` PostgreSQL 16. Version server/tool cụ thể ở `backup-environment.txt`; kích thước và SHA256 ở `backup-manifest.csv`. Đã thử restore riêng cho cả bốn database bằng `pg_restore --exit-on-error`; xem `../evidence/restore-verification.json`. Archive chứa dữ liệu demo và metadata nghiệp vụ của lab tại thời điểm dump.

## Cách restore trên máy giảng viên

Dùng PostgreSQL 16 và công cụ `pg_restore` 16. Chuẩn bị một instance lab mới; không restore đè database đang dùng cho công việc khác. Có thể dùng pgAdmin (Custom/tar) hoặc các lệnh dưới.

1. Tạo role `lab_user` nếu instance mới chưa có role này. Trong `psql` với tài khoản quản trị:

```sql
CREATE ROLE lab_user LOGIN PASSWORD 'lab_pass';
```

2. Tạo **bốn database rỗng** owner `lab_user`, tên đúng như sau (chạy bằng công cụ PostgreSQL trong terminal):

```powershell
createdb -h localhost -U postgres -O lab_user lab_netmicro_payments
createdb -h localhost -U postgres -O lab_user lab_netmicro_jobs
createdb -h localhost -U postgres -O lab_user lab_netmicro_policy
createdb -h localhost -U postgres -O lab_user lab_netmicro_pricing
```

3. Tại thư mục có các file backup, chạy từng lệnh; nhập mật khẩu quản trị khi công cụ hỏi:

```powershell
pg_restore -h localhost -U postgres --exit-on-error -d lab_netmicro_payments .\lab_netmicro_payments.backup
pg_restore -h localhost -U postgres --exit-on-error -d lab_netmicro_jobs .\lab_netmicro_jobs.backup
pg_restore -h localhost -U postgres --exit-on-error -d lab_netmicro_policy .\lab_netmicro_policy.backup
pg_restore -h localhost -U postgres --exit-on-error -d lab_netmicro_pricing .\lab_netmicro_pricing.backup
```

Các archive không dùng `--create`; database cần được tạo trước. Không cần chạy lại SQL khởi tạo role/database của RAR khi đã thực hiện các bước này. Các object owner `lab_user` được phục hồi nhờ role đã có sẵn.

4. Xem schema/bảng và kiểm tra dữ liệu. Bài này đã khôi phục: payments 1 bảng, jobs 12 bảng, policy 6 bảng, pricing 1 bảng. Số dòng của Hangfire có thể thay đổi trong database nguồn khi worker tiếp tục chạy sau lúc dump; file backup là ảnh tại thời điểm sao lưu.

Nếu dùng Docker, `docker cp` file vào container PostgreSQL rồi chạy `docker exec postgres pg_restore ...`; tránh tạo archive bằng chuyển hướng nhị phân qua PowerShell.

Để tạo backup mới trên máy lab, dùng `scripts/backup-postgres-docker.ps1` với **thư mục mới**; script không ghi đè archive cũ. Không dùng `docker compose down -v` để tắt lab vì lệnh đó xóa volume dữ liệu.
