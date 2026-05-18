# 📺 TV Remote - iOS App

Ứng dụng điều khiển TV từ xa cho iOS, được viết bằng Swift và UIKit.

## 🗂 Cấu trúc Project

```
TVRemote/
├── TVRemote.xcodeproj/
│   └── project.pbxproj
└── TVRemote/
    ├── AppDelegate.swift              # Entry point
    ├── Info.plist                     # App configuration
    ├── Controllers/
    │   ├── ScanViewController.swift   # Màn hình quét thiết bị
    │   ├── ConnectingViewController.swift  # Màn hình đang kết nối
    │   └── RemoteViewController.swift # Màn hình remote chính
    ├── Views/
    │   ├── RemoteButton.swift         # Component nút bấm
    │   ├── SectionViews.swift         # Các phần điều khiển
    │   └── ScanViews.swift            # Animation quét + Device cell
    ├── Models/
    │   └── TVDevice.swift             # Model TV, Brand, Command
    ├── Services/
    │   └── TVRemoteService.swift      # Network service
    └── Resources/
        └── Theme.swift                # Design system
```

## ✨ Tính năng

- 🔍 **Quét mạng** - Tự động phát hiện TV trên cùng mạng WiFi
- 🔌 **Kết nối thủ công** - Nhập IP để kết nối trực tiếp
- 📺 **Hỗ trợ đa thương hiệu** - Samsung, LG, Sony, Toshiba, Philips
- 🎮 **Điều khiển đầy đủ:**
  - Nguồn (Power on/off)
  - Âm lượng & Tắt tiếng
  - Chuyển kênh
  - D-Pad điều hướng (Lên/Xuống/Trái/Phải/OK)
  - Home, Back, Menu
  - Điều khiển media (Play/Pause/Stop/Rewind/FF/Record)
  - Bàn phím số 0-9
  - Phím tắt ứng dụng (Netflix, YouTube)
  - Chọn nguồn (HDMI)
- 🎨 **Dark theme** đẹp với hiệu ứng glow
- 📳 **Haptic feedback** trên mỗi nút bấm
- 📱 Animation mượt mà

## 🚀 Cài đặt

### Yêu cầu
- Xcode 15+
- iOS 15.0+
- Swift 5.0+

### Các bước
1. Mở file `TVRemote.xcodeproj` trong Xcode
2. Chọn Target → Signing & Capabilities → chọn Team của bạn
3. Build & Run (⌘R) trên simulator hoặc thiết bị thật

## 🔧 Tích hợp TV thật

Hiện tại app sử dụng mock data để demo. Để kết nối TV thật:

### Samsung Smart TV (WS-API)
```swift
// Trong TVRemoteService.swift, thay sendCommand bằng:
let urlString = "http://\(device.ipAddress):\(device.port)/api/v2/channels/\(command.rawValue)"
// Hoặc WebSocket: ws://192.168.1.x:8001/api/v2/channels/samsung.remote.control
```

### LG WebOS
```swift
// LG dùng WebSocket port 3000
// ws://192.168.1.x:3000
// Cần handshake đăng ký app trước
```

### Sony Bravia
```swift
// POST request đến:
// http://192.168.1.x/sony/IRCC
// Content-Type: text/xml
// Body: SOAP XML với IRCCCode
```

## 🎨 Customization

### Thêm nút mới
```swift
// Trong TVDevice.swift, thêm RemoteCommand:
case myCommand = "KEY_MYCOMMAND"

// Trong SectionViews.swift, thêm button:
let btn = RemoteButton(icon: "star.fill", command: .myCommand, style: .secondary)
```

### Đổi theme màu sắc
```swift
// Trong Resources/Theme.swift:
enum Color {
    static let accent = UIColor(hex: "#FF6B6B") // Đổi màu accent
    static let background = UIColor(hex: "#1A1A2E") // Đổi màu nền
}
```

## 📝 Kiến trúc

- **MVC** pattern với separation of concerns rõ ràng
- **Delegate pattern** cho communication giữa Service và Controllers  
- **Programmatic UIKit** - không dùng Storyboard
- **Auto Layout** với NSLayoutConstraint
- **Singleton Service** cho TVRemoteService

## 🔐 Permissions (Info.plist)

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Cần quyền truy cập mạng nội bộ để tìm TV</string>
<key>NSBonjourServices</key>
<array>
    <string>_samsungtv._tcp</string>
    ...
</array>
```
