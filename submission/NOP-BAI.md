# File và link để nộp bài

**Trương Đắc Kiên - 2424802010029 - D24CNTT05**

## GitHub - sản phẩm 1 bài thực hành 4

https://github.com/KienTD204/Microservices-InsurancePortal-2424802010029

Repository **public**, giảng viên có thể mở và clone mà không cần được cấp quyền đọc riêng. Source đã push và đối chiếu commit local/remote. Hướng dẫn chạy ở README-LAB.md, báo cáo và bằng chứng ở submission/.

Chưa gửi lời mời collaborator: không xác định được tài khoản GitHub từ email caotxuan@gmail.com qua GitHub search. Nếu giảng viên yêu cầu thêm tên trong Collaborators, sinh viên vào Settings > Collaborators > Add people và chọn đúng tài khoản GitHub của thầy; không chọn người khác chỉ vì tên giống nhau.

## Upload lên elearning

1. Bài thực hành 3 Task 1: `reports/BTH3-Task1-Kien-thuc-2424802010029.pdf`.
2. Bài thực hành 3 Task 2: `reports/BTH3-Task2-Nghiep-vu-UML-2424802010029.pdf` (đã có UML trong PDF).
3. Bài thực hành 4: dán link GitHub ở trên, nộp bốn file `.backup` trong `postgres/` cùng `RESTORE.md`, và ảnh `evidence/Build-Success.png`. Kèm `reports/BTH4-Bao-cao-cai-dat-2424802010029.pdf` để giải thích cấu hình, lỗi đã sửa và kết quả.

Có thể nộp ZIP chứa bốn backup khi elearning chỉ cho một file; dùng `PostgreSQL-Backups-2424802010029.zip` trong bộ file giao. `Bai-nop-2424802010029.zip` là gói đầy đủ gồm báo cáo, backup, ảnh và bản source ZIP dự phòng. Việc upload/nộp trên elearning vẫn do sinh viên thực hiện.

## Kết quả và giới hạn

- 32 project build thành công, 0 lỗi. Lần full build ban đầu 57 cảnh báo; lần cuối incremental 23 cảnh báo.
- 46 test case đạt. Bốn database được backup và thử restore thành công.
- Luồng sản phẩm, đăng nhập/JWT, báo giá, tạo/xem hợp đồng, search và tạo tài khoản thanh toán qua RabbitMQ đã kiểm tra.
- DocumentService chỉ là scaffold; chức năng chứng chỉ PDF chưa được upstream cung cấp. Cảnh báo bảo mật dependency còn được giữ trong báo cáo.
- Không báo cáo đã gửi email, mời collaborator, upload elearning hoặc đạt CI khi chưa có bằng chứng tương ứng. Xem tab Actions để kiểm tra CI; log local và CI được phân biệt.
