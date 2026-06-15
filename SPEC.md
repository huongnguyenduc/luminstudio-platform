
# Product & Technical Specification: 3D E-Commerce Platform

**Version:** 2.0 (Tích hợp NATS, Rust FFI, BLoC & Event-Driven Sync)

## 1. System Architecture & Tech Stack

Hệ thống được thiết kế theo mô hình Event-Driven, đảm bảo các tác vụ xử lý đồ họa nặng không gây ảnh hưởng đến luồng API chính, tối ưu hóa tài nguyên cho môi trường local server.

**Component**

**Technology**

**Purpose**

**Build System**

Bazel

Quản lý build và cache cho đa ngôn ngữ (Go, Rust, JS, Dart) nhất quán, tối ưu thời gian compile.

**Infrastructure**

Đã dựng trên PC: K3d (điều khiển qua kubectl cli), Traefik, Cloudflare Tunnel, Self-hosted github-runner.

Quản lý container nội bộ và routing ra public network.

**Storage & Database**

PostgreSQL, MinIO

Lưu dữ liệu quan hệ và Object Storage (File 3D gốc, file đã nén, ảnh 360).

**Message Broker**

NATS

Lightweight queue quản lý các event bất đồng bộ (3D task, Search sync) với độ trễ thấp và ít tốn RAM.

**Search Engine**

Meilisearch

Xử lý tìm kiếm full-text tốc độ cao, hỗ trợ typo-tolerance.

**Core API Backend**

Golang (Fiber/Gin)

Xử lý business logic, REST/gRPC API. Quản lý publish/subscribe event.

**Async 3D Worker**

Rust + C++ FFI

Lắng nghe NATS, gọi C++ (`meshoptimizer`) để decimation và render ảnh 360° qua headless engine.

**Web Admin Panel**

ReactJS + Vite

Giao diện quản trị, upload file, chỉ định mesh và màu sắc tùy chỉnh.

**End-User Mobile App**

Flutter (BLoC)

Ứng dụng mua hàng (Clean Architecture), tối ưu trải nghiệm 3D dựa trên cấu hình phần cứng.

## 2. Monorepo Organization (Bazel Structure)

Hệ thống mã nguồn được tổ chức module hóa, đảm bảo Worker, API, và App tách biệt nhưng dùng chung một nguồn quản lý duy nhất.

Plaintext

```
ecommerce-3d-platform/
├── WORKSPACE / MODULE.bazel  # Cấu hình Bazel root
├── apps/
│   ├── mobile-flutter/       # End-user App (Dart) - Clean Architecture + BLoC
│   └── web-admin/            # React + Vite (JS/TS)
├── services/
│   ├── api-gateway/          # Core API (Golang) + Event Sync Handlers
│   └── worker-3d/            # Async 3D Processor (Rust) + C++ FFI headers
├── packages/
│   ├── shared-types/         # Protobuf / OpenAPI specs / JSON schemas dùng chung
│   └── third-party/          # Native C++ libraries (meshoptimizer, etc.)
├── infra/
│   ├── k8s/                  # Kustomize configs (Postgres, MinIO, NATS, Meili)
│   └── scripts/              # CI/CD scripts
└── .github/workflows/        # CI/CD Pipelines

```

## 3. Developer Workflow (CI/CD với Bazel & K3d)

1.  **Local Development:** Developer sử dụng lệnh `bazel build //...` để compile toàn bộ project. Bazel sẽ tận dụng cache tối đa cho các module không có sự thay đổi.
    
2.  **Push to Branch:** Mã nguồn được commit theo từng nhánh tính năng độc lập (`feature/*`).
    
3.  **CI/CD Pipeline (Self-hosted Runner):**
    
    -   **Test:** Chạy `bazel test //...` để thực thi unit test cho Go, Rust, React và Flutter.
        
    -   **Containerize:** Đóng gói Docker image cho `api-gateway`, `worker-3d`, và `web-admin` thông qua các rules tích hợp sẵn của Bazel.
        
    -   **Load & Deploy:** Sideload image trực tiếp vào K3d (`k3d image import`) và apply Kustomize để cập nhật môi trường Kubernetes local/dev tự động.
        

## 4. Implementation Phases & Acceptance Criteria (AC)

> **Lưu ý:** Hệ thống Authentication & Authorization (Đăng nhập, Phân quyền User/Admin) tạm thời được lược bỏ trong các phase này để tập trung hoàn thiện luồng 3D cốt lõi.

### Phase 1: Infrastructure, Monorepo Bootstrap & Event Bus

Thiết lập môi trường nền tảng, cơ sở dữ liệu, hệ thống tìm kiếm và message broker.

**User Stories:**

-   **US1.1:** Là Developer, tôi muốn Bazel quản lý toàn bộ repo để dùng một lệnh build duy nhất.
    
-   **US1.2:** Là Developer, tôi muốn PostgreSQL, MinIO, Meilisearch và NATS sẵn sàng chạy trên K3d (điều khiển bằng kubectl CLI) (`dev` namespace) để các service có thể kết nối.
    

**Acceptance Criteria (AC):**

-   [ ] Lệnh build cho từng component (Web, API, Worker) chạy thành công không lỗi dependencies.
    
-   [ ] Cụm K3d chạy ổn định các pod: PostgreSQL, MinIO, Meilisearch và NATS.
    
-   [ ] MinIO UI và Meilisearch Dashboard truy cập được qua local domain (ví dụ: `minio-dev.local`, `search-dev.local`).
    
-   [ ] Golang API kết nối thành công tới PostgreSQL, MinIO, NATS và Meilisearch. Có script test publish/subscribe message cơ bản với NATS chạy thành công.
    

### Phase 2: Web Admin, Core API & Rust 3D Processing Pipeline

Xây dựng luồng nhập liệu sản phẩm, luồng đồng bộ tìm kiếm và tự động hóa xử lý đồ họa qua FFI.

**User Stories:**

-   **US2.1:** Là Admin, tôi muốn tạo/sửa sản phẩm. Khi lưu thành công, hệ thống tự động bắn event qua NATS để đồng bộ dữ liệu sang Meilisearch.
    
-   **US2.2:** Là Admin, tôi muốn tải lên **một file 3D chất lượng cao (high-poly)** duy nhất và chỉ định rõ ID của lưới (mesh) nào được phép đổi màu, màu mặc định, và danh sách mã màu.
    
-   **US2.3:** Là System (Rust Worker), khi nhận được event có file 3D mới từ NATS, tôi dùng C++ wrapper (meshoptimizer) để tự động giảm đa giác tạo file `low-poly`. Đồng thời, tôi dùng headless renderer tạo chuỗi ảnh 360°.
    
-   **US2.4:** Là Admin, tôi muốn cấu hình các trường thông tin động (Collapsible Sections) cho từng loại sản phẩm.
    

**Acceptance Criteria (AC):**

-   [ ] Admin upload file `.glb` thành công lên MinIO qua Go API.
    
-   [ ] Giao diện Admin cho phép nhập chuỗi JSON cấu hình mesh màu (VD: `{"mesh_body": {"default": "#FFFFFF", "allowed": ["#000000", "#FF0000"]}}`).
    
-   [ ] Event `product.updated` được publish vào NATS; Go API subcribe event này và index dữ liệu vào Meilisearch ngay lập tức (Event-driven sync).
    
-   [ ] Rust Worker nhận event `3d.task.created` từ NATS, chạy thành công C++ FFI (không bị memory leak), sinh ra file `[id]_low.glb` và tệp `[id]_360_sprite.jpg`.
    
-   [ ] Rust upload file sau xử lý lên MinIO, bắn event `3d.task.completed` để Go API cập nhật URL vào database.
    

### Phase 3: Flutter Mobile App - Clean Architecture, BLoC & Catalog

Triển khai giao diện, luồng điều hướng và tìm kiếm thông minh trên nền tảng Clean Architecture.

**User Stories:**

-   **US3.1:** Là User, tôi dùng Bottom Navigation Bar để chuyển giữa Home, Category, Cart mà không bị mất trạng thái màn hình (được quản lý bởi BLoC).
    
-   **US3.2:** Là User, tại Trang chủ/Danh mục, nếu tôi dừng cuộn ở một sản phẩm khoảng **3 giây**, hình ảnh sản phẩm sẽ tự xoay 360 độ mượt mà.
    
-   **US3.3:** Là User, tôi gõ từ khóa vào Search, hệ thống trả về kết quả ngay cả khi gõ sai chính tả.
    

**Acceptance Criteria (AC):**

-   [ ] Cấu trúc code Flutter tuân thủ Clean Architecture (Presentation, Domain, Data, chia theo tính năng).
    
-   [ ] Bottom Nav Bar duy trì state của từng tab qua BLoC (không re-render lại trang từ đầu khi chuyển tab).
    
-   [ ] Logic "Hover 3s": Sử dụng `VisibilityDetector`. Khi item hiện diện > 80% viewport và dừng trong 3s, load chuỗi ảnh (sprite sheet) từ MinIO và play animation.
    
-   [ ] Search Delegate trong Flutter gọi qua Go Gateway -> Meilisearch. Trả về kết quả chuẩn xác với độ trễ thấp (< 100ms), hỗ trợ typo-tolerance.
    
-   [ ] Category Detail có tính năng Pagination (Infinite scroll) và Sort.

-   [ ] Có nút để scroll nhanh trở về đầu trang, khi scroll đến đầu trang, nút này biến mất.
    

### Phase 4: 3D Product Detail, Device Detection & Cart Management

Tương tác 3D cốt lõi dựa trên phần cứng và quản lý giỏ hàng nội bộ.

**User Stories:**

-   **US4.1:** Là System (Flutter App), khi khởi động, tôi đánh giá RAM/OS của thiết bị để quyết định tải file 3D `high-poly` hay `low-poly`.
    
-   **US4.2:** Là User, tôi có thể xoay, zoom mô hình 3D và thay đổi màu sắc các bộ phận theo cấu hình Admin.

-   **US4.3:** Là User, tôi có thể xem thêm thông tin chi tiết của sản phẩm mà người bán hàng cung cấp. Ở phía dưới tôi có thể xem các mặt hàng tương tự.
    
-   **US4.4:** Là User, tôi thêm sản phẩm vào giỏ hàng với đúng cấu hình màu và số lượng vừa chọn.
    
-   **US4.5:** Là User, tôi check/uncheck sản phẩm trong Giỏ hàng, hệ thống tự tính Tạm tính và Số tiền tiết kiệm realtime.
    

**Acceptance Criteria (AC):**

-   [ ] Logic phân loại `device_tier` chạy ngầm lúc app startup sử dụng package `device_info_plus`.
    
-   [ ] BLoC gọi API lấy Product Detail với param `?tier=low` hoặc `high`. API trả về URL file `.glb` chính xác.
    
-   [ ] 3D Viewer load thành công file model. Nút chọn màu gọi JavaScript/Bridge method để đổi material color của `mesh_id` ngay lập tức.
    
-   [ ] `CartBloc` lưu trữ dữ liệu local storage dưới dạng: `{ product_id, selected_colors: { mesh_body: "#FF0000" }, qty: 1 }`.
    
-   [ ] Màn hình Cart tính toán chính xác tổng tiền khi thay đổi số lượng/tick chọn; UI phản hồi tức thời nhờ state stream của BLoC.

