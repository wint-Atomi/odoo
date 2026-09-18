# AI Execution & Permission Guidelines

## 1. Toàn quyền tự động thực thi (Autonomous Operations)
- **Toàn quyền chỉnh sửa mã nguồn & dự án:** AI có toàn quyền tự động tạo, đọc, ghi, sửa file, refactor mã nguồn, cấu hình Docker, Git, kịch bản triển khai, chạy kiểm thử trong workspace mà KHÔNG CẦN yêu cầu người dùng xác nhận hay submit từng bước.
- **Tự động commit và push Git:** Sau khi hoàn thành một tác vụ chỉnh sửa mã nguồn hoặc cấu hình, AI chủ động chạy lệnh git add, commit (thông điệp rõ ràng chuẩn semantic commit, tuyệt đối không dùng emoji/icon) và push trực tiếp lên GitHub (origin) mà không cần chờ người dùng nhắc.
- **Tác vụ lấy thông tin laptop (GET / Read-only):** Mọi lệnh kiểm tra, lấy thông tin máy tính/hệ điều hành (như thông số phần cứng CPU, RAM, dung lượng ổ đĩa, địa chỉ IP mạng, danh sách tiến trình, kiểm tra file/thư mục, biến môi trường...) được phép chạy trực tiếp NGAY LẬP TỨC mà không cần hỏi người dùng.

## 2. Chỉ hỏi người dùng khi can thiệp sâu hệ thống (Deep System Interventions Only)
CHỈ dừng lại để hỏi ý kiến dev hoặc yêu cầu dev xác nhận trong các trường hợp can thiệp sâu, có rủi ro phá hủy hệ thống của laptop:
- Chỉnh sửa hệ thống Windows sâu (Windows Registry, chính sách bảo mật hệ thống, cấu hình phân vùng/format ổ cứng).
- Lệnh xóa file mang tính phá hủy diện rộng cấp hệ điều hành (xóa các thư mục hệ thống `C:\Windows`, `C:\Program Files`, format ổ đĩa...).
- Cài đặt driver hoặc phần mềm cấp OS làm thay đổi cấu hình toàn máy hoặc yêu cầu khởi động lại máy tính (Shutdown / Reboot).
- Xóa sạch dữ liệu sản xuất (drop database production) không thể khôi phục.

Mọi tác vụ kỹ thuật, lập trình và vận hành dự án còn lại đều được tự động thực hiện hoàn toàn và báo cáo kết quả sau khi hoàn thành.
