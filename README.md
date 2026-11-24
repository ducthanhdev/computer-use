# 📱 DeskPulse (Enterprise Edition) - Rust & Flutter Remote PC Controller

Dự án giám sát & điều khiển máy tính từ xa qua điện thoại được xây dựng theo kiến trúc công nghiệp chuẩn mực (tương tự như **RustDesk**):
- **Desktop Agent (Máy tính Linux)**: Viết bằng **Rust** (Tokio, Axum, Sysinfo) với độ trễ microsecond, tiêu thụ cực ít tài nguyên (< 10MB RAM).
- **Mobile Client (Điện thoại Android)**: Viết bằng **Flutter** (Dart, fl_chart, WebSocket) hiển thị biểu đồ telemetry 120Hz mượt mà và hỗ trợ bàn rê chuột ảo (Virtual Trackpad).

---

## 🏛️ Kiến trúc hệ thống
```text
┌──────────────────────────────────────────────┐
│       MÁY TÍNH (Desktop Agent Daemon)        │
│                    RUST                      │
│   • Tokio (Async Runtime)                    │
│   • Axum WebSocket Server (ws://.../ws)      │
│   • Sysinfo Telemetry (CPU, RAM, Disks, Net) │
│   • Linux Controller (Input, Audio, Power)   │
└──────────────────────┬───────────────────────┘
                       │ WebSocket (Full-Duplex)
                       │ Bi-directional, < 15ms latency
┌──────────────────────▼───────────────────────┐
│        ĐIỆN THOẠI (Mobile Client)            │
│                   FLUTTER                    │
│   • Provider State Management                │
│   • fl_chart (Biểu đồ sóng CPU/RAM mượt mà)  │
│   • Virtual Trackpad (Pan, Click, Scroll)    │
│   • Điều khiển Âm lượng, Media, Nguồn        │
└──────────────────────────────────────────────┘
```

---

## 🌟 Các tính năng nổi bật
1. **Giám sát thời gian thực (Real-time Telemetry)**:
   - **Biểu đồ sóng CPU**: Cập nhật liên tục 800ms/lần qua WebSocket với biểu đồ vector mượt mà (`fl_chart`).
   - **Chi tiết CPU**: % Tổng tải, 12 nhân riêng biệt, xung nhịp MHz, nhiệt độ cảm biến (°C).
   - **RAM & Swap**: Dung lượng đã dùng / tổng dung lượng, thanh tiến trình màu sắc động theo mức tải.
   - **Tốc độ Mạng**: Băng thông Tải xuống (Down) & Tải lên (Up) thời gian thực theo KB/s hoặc MB/s.
   - **Pin Laptop**: % Pin và trạng thái đang sạc / đang dùng pin.
   - **Tiến trình**: Xem top ứng dụng ngốn nhiều CPU/RAM nhất với thanh tìm kiếm thời gian thực.
2. **Điều khiển từ xa (Remote Control)**:
   - **Bàn rê chuột ảo (Virtual Trackpad)**: Chạm và vuốt để di chuyển con trỏ chuột trên màn hình máy tính với độ trễ cực thấp. Nút bấm Chuột trái / Chuột phải riêng biệt.
   - **Âm lượng**: Tăng (+5%), Giảm (-5%), Bật/Tắt tiếng (Mute).
   - **Trình phát Media**: Play/Pause, Bài trước, Bài tiếp theo.
   - **Nguồn & Bảo mật**: Khóa màn hình PC (`Lock Screen`), Đưa PC vào chế độ ngủ (`Sleep/Suspend`).
   - **Thông báo**: Gửi tin nhắn test hiển thị pop-up trên desktop PC.

---

## 🚀 Khởi động trên máy tính (Linux PC)

Chỉ cần chạy lệnh:
```bash
./start.sh
```

Màn hình terminal sẽ xuất hiện:
```text
==============================================================
  🦀  DeskPulse Desktop Daemon (Rust Enterprise Edition)
==============================================================
  • Cổng (Port):     8765
  • Địa chỉ LAN:     http://192.168.1.50:8765
  • WebSocket URL:   ws://192.168.1.50:8765/ws
==============================================================
  📱 FLUTTER MOBILE APP: Nhập địa chỉ: 192.168.1.50:8765
==============================================================
```

---

## 📲 Cài đặt & Build App Flutter cho Android

### Cách 1: Tự động Build APK qua GitHub Actions (Khuyên dùng)
Bạn không cần phải cài đặt Flutter SDK hay Android Studio nặng máy:
1. Đẩy mã nguồn này lên GitHub:
   ```bash
   git init
   git add .
   git commit -m "DeskPulse Rust + Flutter Enterprise Edition"
   git remote add origin <URL_REPO_GITHUB_CUA_BAN>
   git push -u origin main
   ```
2. Vào tab **Actions** trên GitHub, workflow `.github/workflows/build-flutter-apk.yml` sẽ tự động biên dịch:
   - File binary Rust cho Linux (`deskpulse-agent`).
   - File cài đặt Android APK (`DeskPulse-Flutter-Release-APK`).
3. Tải file **`app-release.apk`** trực tiếp về điện thoại và cài đặt!

### Cách 2: Tự build bằng Flutter CLI trên máy
Nếu bạn đã có Flutter SDK trên máy tính:
```bash
cd mobile
flutter pub get
flutter build apk --release
```
File APK sẽ xuất hiện tại `mobile/build/app/outputs/flutter-apk/app-release.apk`.

### Cách 3: Mở trực tiếp trên Web Browser / PWA (Dự phòng)
Ngay cả khi chưa kịp cài Flutter APK, bạn vẫn có thể mở trình duyệt trên điện thoại và truy cập địa chỉ `http://<IP_MÁY_TÍNH>:8765` để dùng ngay giao diện web dự phòng đã được tích hợp sẵn bên trong Rust Agent!

---

## 📁 Cấu trúc thư mục Monorepo
```text
Computer-use/
├── agent/                       # Rust Desktop Daemon
│   ├── Cargo.toml               # Cấu hình Tokio, Axum, Sysinfo
│   └── src/
│       ├── main.rs              # Entrypoint, Router & CLI
│       ├── monitor.rs           # Đọc CPU, RAM, Disk, Net, Temp, Battery
│       ├── controller.rs        # Xử lý chuột, âm lượng, nguồn, phím
│       ├── ws.rs                # WebSocket streaming handler
│       └── models.rs            # Data structs & protocols
│
├── mobile/                      # Ứng dụng Flutter Mobile
│   ├── pubspec.yaml             # Cấu hình dependencies (fl_chart, web_socket_channel, provider)
│   ├── lib/
│   │   ├── main.dart            # Entrypoint & Material 3 Dark UI
│   │   ├── models/              # Telemetry data models
│   │   ├── services/            # WebSocket Client & Reconnect Loop
│   │   └── screens/
│   │       ├── dashboard_screen.dart  # Biểu đồ sóng CPU/RAM, Network
│   │       ├── remote_screen.dart     # Virtual Trackpad, Media, Volume
│   │       ├── processes_screen.dart  # Danh sách tiến trình
│   │       └── settings_sheet.dart    # Cài đặt IP/Port kết nối
│   └── android/                 # Cấu hình Android Native & Permissions
│
├── .github/workflows/
│   └── build-flutter-apk.yml    # CI/CD tự động build APK release & Rust binary
├── start.sh                     # Script khởi động 1 lệnh duy nhất
└── README.md                    # Tài liệu hướng dẫn
```
