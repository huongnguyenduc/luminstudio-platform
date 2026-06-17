# Tài liệu Đặc tả Mô hình 3D (3D Model Specification)

**Dự án:** 3D E-commerce Platform (LuminStudio)
**Nền tảng hiển thị:** Ứng dụng Mobile (Flutter - Thư viện render 3D đang được đánh giá và lựa chọn)
**Đối tượng mô hình:** Thẻ tên tương tác (Interactive Pet Tag)

---

## 1. Thông tin chung về File
* **Định dạng:** `.glb` (glTF Binary Format).
* **Mục đích sử dụng:** Tải lên thông qua thư viện render 3D trên Flutter, cho phép người dùng tùy biến màu sắc theo thời gian thực (real-time).
* **Lưu trữ & Phân phối:** File `.glb` sẽ được upload qua ReactJS Web Admin, lưu trữ tĩnh tại bucket của MinIO S3 nội bộ và phục vụ tải về cho Mobile App qua mạng CDN/HTTP.
* **Tình trạng tối ưu hóa:**
  * **Mesh tách biệt (Separate Meshes):** Đảm bảo chia tách đúng các bộ phận cần tương tác.
  * **Giảm lưới (Decimate):** Đã áp dụng bộ lọc giảm lưới để tối ưu hóa hiệu năng render trên thiết bị di động (Khuyến nghị dung lượng file hoàn thiện: `< 5MB`).
  * **Chuẩn hóa tọa độ (All Transforms applied):** Tọa độ gốc (Origin) nên được đặt chuẩn nhất có thể. Tuy nhiên, trong trường hợp file không có góc nhìn mặc định tối ưu, Web Admin sẽ cung cấp công cụ tinh chỉnh lại góc xoay trước khi hiển thị cho người dùng cuối.

## 2. Cấu trúc Cấu thành (Scene Hierarchy)
Mô hình chứa 2 vật thể (Objects) độc lập, phục vụ việc quản lý state màu sắc riêng biệt. Các thành phần `Camera` và `Light` mặc định **không** được xuất vào file để tránh xung đột với môi trường ánh sáng của app.

### 2.1. Phần nền của thẻ (Base Object)
* **Node Name (Tên Object):** `Tag_Base`
* **Material Name (Tên Vật liệu):** `Base_Mat`
* **Màu sắc gốc (Base Color Factor):** `#FFFFFF` (Trắng tuyệt đối).
* **Mô tả logic:** Bộ phận này sẽ nhận state màu nền do người dùng chọn từ giao diện app. 

### 2.2. Phần chữ nổi (Text Object)
* **Node Name (Tên Object):** `Tag_Text`
* **Material Name (Tên Vật liệu):** `Text_Mat`
* **Màu sắc gốc (Base Color Factor):** `#FFFFFF` (Trắng tuyệt đối).
* **Mô tả logic:** Bộ phận này sẽ nhận state màu chữ (phần chữ nổi) độc lập với màu nền.

## 3. Đồng bộ Hệ thống & Cấu hình (Web Admin)
Để file 3D hiển thị hoàn hảo và thân thiện với End-User trên Mobile App, luồng cấu hình trên React Web Admin sẽ bao gồm các tính năng sau:
1. **Tùy biến nhãn hiển thị (Display Name Mapping):** Admin có thể định nghĩa lại tên hiển thị của các Material thay vì dùng tên kỹ thuật. Ví dụ: map `Base_Mat` thành "Màu nền thẻ", map `Text_Mat` thành "Màu chữ nổi". App Flutter sẽ đọc cấu hình này để render UI chọn màu.
2. **Tinh chỉnh hướng mặc định (Initial Orientation/Rotation):** Do model tải lên có thể không nằm ở góc nhìn đẹp nhất, Admin panel cung cấp tham số để xoay vật thể (Offset X, Y, Z hoặc Pitch, Yaw, Roll). Cấu hình này được lưu lại thành thông số mặc định (default view) truyền xuống cho Frontend.
3. **Khai báo mảng cấu hình:** Toàn bộ thông tin map tên và góc xoay sẽ được gộp thành một chuỗi JSON để API Golang lưu trữ cùng bản ghi sản phẩm.

## 4. Hướng dẫn Triển khai cho Coding Agent (Implementation Notes)
Khi Agent sinh mã nguồn Flutter (dựa trên thư viện render 3D sẽ chốt sau này), cần áp dụng các nguyên tắc sau:
1. **Khởi tạo góc nhìn Camera/Vật thể:** Khi load file `.glb`, phải đọc cấu hình góc xoay (Orientation/Rotation) từ API trả về để điều chỉnh ngay góc nhìn mặc định, đảm bảo model hiện ra chính xác theo ý đồ cấu hình của Admin.
2. **Truy xuất Node để đổi màu:** Việc thay đổi màu tuyệt đối **không** gọi vào tên Object (ví dụ `Tag_Base`), mà phải duyệt qua mảng vật liệu và tương tác trực tiếp với tên Material (`Base_Mat` hoặc `Text_Mat`).
3. **Cơ chế hòa trộn màu:** Do `Base Color` của file 3D đã được thiết lập là trắng chuẩn (`#FFFFFF`), Agent chỉ cần truyền giá trị mã màu HEX hoặc RGBA từ hệ thống Design Token vào thuộc tính màu của vật liệu tương ứng (ví dụ: `baseColorFactor`). Không cần viết logic tính toán bù trừ độ sáng.
