import Foundation
import Darwin

// MARK: - TV Remote Service Protocol
protocol TVRemoteServiceDelegate: AnyObject {
    func didDiscoverDevice(_ device: TVDevice)
    func didConnect(to device: TVDevice)
    func didDisconnect(from device: TVDevice)
    func didFailToConnect(error: String)
    func didReceiveResponse(_ response: String)
    func didRequestPairingCode(for device: TVDevice)
}

// MARK: - TV Remote Service
final class TVRemoteService: NSObject {

    static let shared = TVRemoteService()
    weak var delegate: TVRemoteServiceDelegate?

    private var currentDevice: TVDevice?
    private var webSocketTask: URLSessionWebSocketTask?
    private var androidTVRemoteManager: AndroidTVBoxRemoteManager?
    private lazy var urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)

    private var pendingConnectDevice: TVDevice?
    private var pendingConnectTimer: Timer?
    private var isScanning = false
    private let scanQueue = DispatchQueue(label: "tvremote.ssdp.scan", qos: .userInitiated)
    private let scanLock = NSLock()
    private var discoveredScanIDs = Set<String>()

    private let appName = "TV Remote"

    private override init() {
        super.init()
    }

    // MARK: - Scanning
    func startScanning() {
        guard !isScanning else { return }
        isScanning = true
        discoveredScanIDs.removeAll()

        scanQueue.async { [weak self] in
            guard let self else { return }
            self.scanSSDPDevices()
            if self.isScanning {
                self.scanSubnetDevices()
            }
            if self.isScanning && self.discoveredScanIDs.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.didFailToConnect(
                        error: "Không tìm thấy thiết bị. Kiểm tra iPhone cùng Wi-Fi với TV/thiết bị và router không chặn quét mạng nội bộ."
                    )
                }
            }
            self.isScanning = false
        }
    }

    func stopScanning() {
        isScanning = false
    }

    private func scanSSDPDevices() {
        let socketFD = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard socketFD >= 0 else {
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.didFailToConnect(error: "Không tạo được UDP socket để quét mạng.")
            }
            return
        }
        defer { close(socketFD) }

        var timeout = timeval(tv_sec: 0, tv_usec: 500_000)
        setsockopt(socketFD, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        sendSSDPDiscovery(socketFD: socketFD, searchTarget: "ssdp:all")
        sendSSDPDiscovery(socketFD: socketFD, searchTarget: "urn:schemas-upnp-org:device:MediaRenderer:1")
        sendSSDPDiscovery(socketFD: socketFD, searchTarget: "urn:dial-multiscreen-org:service:dial:1")

        let deadline = Date().addingTimeInterval(3)
        var buffer = [UInt8](repeating: 0, count: 8192)

        while Date() < deadline && isScanning {
            var sender = sockaddr_storage()
            var senderLength = socklen_t(MemoryLayout<sockaddr_storage>.size)
            let byteCount = withUnsafeMutablePointer(to: &sender) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                    recvfrom(socketFD, &buffer, buffer.count - 1, 0, sockaddrPointer, &senderLength)
                }
            }

            guard byteCount > 0,
                  let response = String(bytes: buffer[0..<byteCount], encoding: .utf8),
                  let device = deviceFromSSDPResponse(response) else {
                continue
            }

            publishScannedDevice(device)
        }
    }

    private func sendSSDPDiscovery(socketFD: Int32, searchTarget: String) {
        let message = """
        M-SEARCH * HTTP/1.1\r
        HOST: 239.255.255.250:1900\r
        MAN: "ssdp:discover"\r
        MX: 2\r
        ST: \(searchTarget)\r
        \r

        """

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(1900).bigEndian
        inet_pton(AF_INET, "239.255.255.250", &address.sin_addr)

        message.withCString { pointer in
            withUnsafePointer(to: &address) { addressPointer in
                addressPointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                    _ = sendto(socketFD,
                               pointer,
                               strlen(pointer),
                               0,
                               sockaddrPointer,
                               socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
    }

    private func deviceFromSSDPResponse(_ response: String) -> TVDevice? {
        guard let location = headerValue("location", in: response),
              let url = URL(string: location),
              let host = url.host else {
            return nil
        }

        let description = loadDeviceDescription(from: url)
        let combinedText = "\(response)\n\(description ?? "")"
        let brand = inferBrand(from: combinedText)
        guard brand == .samsung || brand == .sony else { return nil }

        let friendlyName = xmlValue("friendlyName", in: description ?? "")
        let displayName = friendlyName?.isEmpty == false ? friendlyName! : "\(brand.rawValue) TV"
        let port = brand == .sony ? 80 : 8001

        return TVDevice(id: "\(brand.rawValue)-\(host)",
                        name: displayName,
                        ipAddress: host,
                        port: port,
                        brand: brand)
    }

    private func headerValue(_ name: String, in response: String) -> String? {
        for line in response.components(separatedBy: .newlines) {
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2,
                  parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == name.lowercased() else {
                continue
            }
            return parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private func loadDeviceDescription(from url: URL) -> String? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: String?

        var request = URLRequest(url: url)
        request.timeoutInterval = 1.5

        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data {
                result = String(data: data, encoding: .utf8)
            }
            semaphore.signal()
        }.resume()

        _ = semaphore.wait(timeout: .now() + 2)
        return result
    }

    private func inferBrand(from text: String) -> TVBrand {
        let lowercased = text.lowercased()
        if lowercased.contains("samsung") {
            return .samsung
        }
        if lowercased.contains("sony") || lowercased.contains("bravia") {
            return .sony
        }
        return .generic
    }

    private func xmlValue(_ tag: String, in xml: String) -> String? {
        guard let startRange = xml.range(of: "<\(tag)>", options: .caseInsensitive),
              let endRange = xml.range(of: "</\(tag)>", options: .caseInsensitive, range: startRange.upperBound..<xml.endIndex) else {
            return nil
        }
        return String(xml[startRange.upperBound..<endRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func scanSubnetDevices() {
        guard let network = localIPv4Network() else {
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.didFailToConnect(error: "Không xác định được IP Wi-Fi hiện tại để quét subnet.")
            }
            return
        }

        let group = DispatchGroup()
        let throttle = DispatchSemaphore(value: 32)
        let commonPorts = [6467, 6466, 8001, 8002, 55000, 80, 8080, 8008, 8009, 3000, 3001, 7000, 9197, 9080]
        let lowerHost = max(network.network + 1, network.local & 0xFFFFFF00 + 1)
        let upperHost = min(network.broadcast - 1, (network.local & 0xFFFFFF00) + 254)

        guard lowerHost <= upperHost else { return }

        for host in lowerHost...upperHost where isScanning {
            if host == network.local { continue }

            group.enter()
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                throttle.wait()
                defer {
                    throttle.signal()
                    group.leave()
                }

                guard let self, self.isScanning else { return }
                let ip = self.ipString(fromHostOrderAddress: host)

                for port in commonPorts where self.isScanning {
                    guard self.isTCPPortOpen(ip: ip, port: port, timeoutMS: 180) else { continue }
                    let device = self.deviceFromOpenPort(ip: ip, port: port)
                    self.publishScannedDevice(device)
                    break
                }
            }
        }

        _ = group.wait(timeout: .now() + 8)
    }

    private func deviceFromOpenPort(ip: String, port: Int) -> TVDevice {
        switch port {
        case 6467, 6466:
            let friendly = "Android TV Box (\(ip))"
            return TVDevice(id: "AndroidTV-\(ip)",
                            name: friendly,
                            ipAddress: ip,
                            port: port,
                            brand: .androidTV)

        case 8001, 8002:
            let friendly = samsungFriendlyName(ip: ip, port: port) ?? "Samsung TV (\(ip))"
            return TVDevice(id: "Samsung-\(ip)",
                            name: friendly,
                            ipAddress: ip,
                            port: port,
                            brand: .samsung)

        case 55000:
            let friendly = samsungFriendlyName(ip: ip, port: 8001) ?? "Samsung TV cũ (\(ip))"
            return TVDevice(id: "SamsungLegacy-\(ip)",
                            name: friendly,
                            ipAddress: ip,
                            port: port,
                            brand: .samsung)

        case 3000, 3001:
            let friendly = "LG/webOS TV hoặc thiết bị (\(ip))"
            return TVDevice(id: "LG-\(ip)",
                            name: friendly,
                            ipAddress: ip,
                            port: port,
                            brand: .lg)

        case 80:
            if let sonyName = sonyFriendlyNameIfAvailable(ip: ip) {
                return TVDevice(id: "Sony-\(ip)",
                                name: sonyName,
                                ipAddress: ip,
                                port: 80,
                                brand: .sony)
            } else {
                return TVDevice(id: "HTTP-\(ip)",
                                name: "Thiết bị mạng / Sony có thể dùng IP Control (\(ip))",
                                ipAddress: ip,
                                port: port,
                                brand: .generic)
            }

        default:
            return TVDevice(id: "Network-\(ip)-\(port)",
                            name: "Thiết bị mạng \(ip):\(port)",
                            ipAddress: ip,
                            port: port,
                            brand: .generic)
        }
    }

    private func publishScannedDevice(_ device: TVDevice) {
        let scanID = "\(device.ipAddress)"
        scanLock.lock()
        let isNew = !discoveredScanIDs.contains(scanID)
        if isNew {
            discoveredScanIDs.insert(scanID)
        }
        scanLock.unlock()

        guard isNew else { return }
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.didDiscoverDevice(device)
        }
    }

    private func localIPv4Network() -> (network: UInt32, broadcast: UInt32, local: UInt32)? {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let firstInterface = interfaces else { return nil }
        defer { freeifaddrs(interfaces) }

        var fallback: (network: UInt32, broadcast: UInt32, local: UInt32)?
        var pointer: UnsafeMutablePointer<ifaddrs>? = firstInterface

        while let current = pointer {
            defer { pointer = current.pointee.ifa_next }

            let flags = Int32(current.pointee.ifa_flags)
            guard flags & IFF_UP != 0,
                  flags & IFF_LOOPBACK == 0,
                  let address = current.pointee.ifa_addr,
                  let netmask = current.pointee.ifa_netmask,
                  address.pointee.sa_family == UInt8(AF_INET) else {
                continue
            }

            let name = String(cString: current.pointee.ifa_name)
            let local = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
            }
            let mask = netmask.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
            }
            let network = local & mask
            let broadcast = network | ~mask
            let result = (network: network, broadcast: broadcast, local: local)

            if name == "en0" {
                return result
            }
            fallback = fallback ?? result
        }

        return fallback
    }

    private func ipString(fromHostOrderAddress address: UInt32) -> String {
        var addr = in_addr(s_addr: address.bigEndian)
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        inet_ntop(AF_INET, &addr, &buffer, socklen_t(INET_ADDRSTRLEN))
        return String(cString: buffer)
    }

    private func isTCPPortOpen(ip: String, port: Int, timeoutMS: Int32) -> Bool {
        let socketFD = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard socketFD >= 0 else { return false }
        defer { close(socketFD) }

        let flags = fcntl(socketFD, F_GETFL, 0)
        guard flags >= 0, fcntl(socketFD, F_SETFL, flags | O_NONBLOCK) >= 0 else { return false }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(port).bigEndian
        guard inet_pton(AF_INET, ip, &address.sin_addr) == 1 else { return false }

        let connectResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Darwin.connect(socketFD, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        if connectResult == 0 {
            return true
        }
        guard errno == EINPROGRESS else {
            return false
        }

        var pollFD = pollfd(fd: socketFD, events: Int16(POLLOUT), revents: 0)
        guard poll(&pollFD, 1, timeoutMS) > 0 else {
            return false
        }

        var socketError: Int32 = 0
        var socketErrorLength = socklen_t(MemoryLayout<Int32>.size)
        let optionResult = getsockopt(socketFD,
                                      SOL_SOCKET,
                                      SO_ERROR,
                                      &socketError,
                                      &socketErrorLength)
        return optionResult == 0 && socketError == 0
    }

    // MARK: - Friendly name resolvers for subnet scan
    private func samsungFriendlyName(ip: String, port: Int) -> String? {
        // Try common ports for Samsung device info endpoint
        let tryPorts: [Int] = port == 8002 ? [8001, 8002] : [port, 8002]
        for p in tryPorts {
            var components = URLComponents()
            components.scheme = "http"
            components.host = ip
            components.port = p
            components.path = "/api/v2/"
            guard let url = components.url else { continue }

            var request = URLRequest(url: url)
            request.timeoutInterval = 0.6

            let semaphore = DispatchSemaphore(value: 0)
            var resolvedName: String?

            URLSession.shared.dataTask(with: request) { data, _, _ in
                defer { semaphore.signal() }
                guard let data else { return }
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let device = json["device"] as? [String: Any] {
                        resolvedName = (device["name"] as? String) ?? (device["modelName"] as? String)
                    } else if let name = json["name"] as? String {
                        resolvedName = name
                    }
                }
            }.resume()

            _ = semaphore.wait(timeout: .now() + 0.7)
            if let name = resolvedName, !name.isEmpty {
                return name
            }
        }
        return nil
    }

    private func sonyFriendlyNameIfAvailable(ip: String) -> String? {
        var components = URLComponents()
        components.scheme = "http"
        components.host = ip
        components.port = 80
        components.path = "/sony/system"
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 0.7
        request.httpBody = """
        {"method":"getSystemInformation","params":[],"id":1,"version":"1.0"}
        """.data(using: .utf8)

        let semaphore = DispatchSemaphore(value: 0)
        var resolvedName: String?
        var ok = false

        URLSession.shared.dataTask(with: request) { data, response, _ in
            defer { semaphore.signal() }
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), let data else { return }
            ok = true
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let result = json["result"] as? [Any], let first = result.first as? [String: Any] {
                    resolvedName = first["name"] as? String
                }
            }
        }.resume()

        _ = semaphore.wait(timeout: .now() + 0.8)
        return ok ? (resolvedName ?? "Sony TV (\(ip))") : nil
    }

    // MARK: - Connection
    func connect(to device: TVDevice) {
        disconnectSilently()

        switch device.brand {
        case .samsung:
            connectSamsung(to: device)
        case .sony:
            connectSony(to: device)
        case .androidTV:
            connectAndroidTV(to: device)
        case .generic:
            delegate?.didFailToConnect(error: "Thiết bị này được phát hiện trên mạng nhưng chưa hỗ trợ điều khiển. Hãy chọn Samsung/Sony hoặc nhập IP thủ công đúng hãng.")
        default:
            delegate?.didFailToConnect(error: "Hiện tại app chỉ hỗ trợ Samsung và Sony Bravia.")
        }
    }

    private func connectSamsung(to device: TVDevice) {
        guard let url = samsungWebSocketURL(for: device) else {
            delegate?.didFailToConnect(error: "IP hoặc port không hợp lệ.")
            return
        }

        pendingConnectDevice = TVDevice(id: device.id,
                                        name: device.name,
                                        ipAddress: device.ipAddress,
                                        port: normalizedSamsungPort(device.port),
                                        brand: .samsung,
                                        authToken: device.authToken)

        let task = urlSession.webSocketTask(with: url)
        webSocketTask = task
        task.resume()
        receiveMessages()

        pendingConnectTimer?.invalidate()
        pendingConnectTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            guard let self = self, self.currentDevice == nil else { return }
            self.disconnectSilently()
            self.delegate?.didFailToConnect(
                error: "Không kết nối được Samsung TV. Kiểm tra IP, cùng Wi-Fi, TV đang bật và đã bấm Allow trên TV."
            )
        }
    }

    func disconnect() {
        guard let device = currentDevice ?? pendingConnectDevice else { return }
        disconnectSilently()
        delegate?.didDisconnect(from: device)
    }

    private func disconnectSilently() {
        pendingConnectTimer?.invalidate()
        pendingConnectTimer = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        androidTVRemoteManager?.disconnect()
        androidTVRemoteManager = nil
        currentDevice = nil
        pendingConnectDevice = nil
    }

    // MARK: - Send Command
    func sendCommand(_ command: RemoteCommand, completion: ((Bool) -> Void)? = nil) {
        guard let device = currentDevice else {
            completion?(false)
            return
        }

        switch device.brand {
        case .sony:
            sendSonyCommand(command, to: device, completion: completion)
        case .androidTV:
            androidTVRemoteManager?.send(command: command)
            delegate?.didReceiveResponse("SENT")
            completion?(true)
        case .samsung, .generic:
            sendSamsungCommand(command, completion: completion)
        default:
            completion?(false)
        }
    }

    private func sendSamsungCommand(_ command: RemoteCommand, completion: ((Bool) -> Void)?) {
        guard webSocketTask != nil else {
            completion?(false)
            return
        }

        let payload: [String: Any] = [
            "method": "ms.remote.control",
            "params": [
                "Cmd": "Click",
                "DataOfCmd": command.rawValue,
                "Option": "false",
                "TypeOfRemote": "SendRemoteKey"
            ]
        ]

        sendJSONObject(payload, completion: completion)
    }

    func sendText(_ text: String, completion: ((Bool) -> Void)? = nil) {
        guard webSocketTask != nil, currentDevice != nil else {
            completion?(false)
            return
        }

        let payload: [String: Any] = [
            "method": "ms.remote.control",
            "params": [
                "Cmd": text,
                "DataOfCmd": "base64",
                "TypeOfRemote": "SendInputString"
            ]
        ]

        sendJSONObject(payload, completion: completion)
    }

    private func sendJSONObject(_ object: [String: Any], completion: ((Bool) -> Void)?) {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let json = String(data: data, encoding: .utf8) else {
            completion?(false)
            return
        }

        webSocketTask?.send(.string(json)) { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.delegate?.didFailToConnect(error: "Gửi lệnh thất bại: \(error.localizedDescription)")
                    completion?(false)
                } else {
                    self?.delegate?.didReceiveResponse("SENT")
                    completion?(true)
                }
            }
        }
    }

    // MARK: - Samsung WebSocket
    private func samsungWebSocketURL(for device: TVDevice) -> URL? {
        let port = normalizedSamsungPort(device.port)
        let scheme = port == 8002 ? "wss" : "ws"
        let encodedName = Data(appName.utf8).base64EncodedString()
        let token = samsungToken(for: device.ipAddress)

        var components = URLComponents()
        components.scheme = scheme
        components.host = device.ipAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        components.port = port
        components.path = "/api/v2/channels/samsung.remote.control"

        var items = [URLQueryItem(name: "name", value: encodedName)]
        if let token, !token.isEmpty {
            items.append(URLQueryItem(name: "token", value: token))
        }
        components.queryItems = items

        return components.url
    }

    private func normalizedSamsungPort(_ port: Int) -> Int {
        return port > 0 ? port : 8001
    }

    private func receiveMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let message):
                self.handle(message)
                self.receiveMessages()

            case .failure(let error):
                DispatchQueue.main.async {
                    if self.currentDevice != nil {
                        let device = self.currentDevice
                        self.disconnectSilently()
                        if let device {
                            self.delegate?.didDisconnect(from: device)
                        }
                    } else {
                        self.disconnectSilently()
                        self.delegate?.didFailToConnect(error: "Mất kết nối Samsung TV: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        let text: String?
        switch message {
        case .string(let value):
            text = value
        case .data(let data):
            text = String(data: data, encoding: .utf8)
        @unknown default:
            text = nil
        }

        guard let text else { return }
        storeSamsungTokenIfNeeded(from: text)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.didReceiveResponse(text)

            if self.currentDevice == nil, var device = self.pendingConnectDevice {
                device.isConnected = true
                self.currentDevice = device
                self.pendingConnectDevice = nil
                self.pendingConnectTimer?.invalidate()
                self.pendingConnectTimer = nil
                self.delegate?.didConnect(to: device)
            }
        }
    }

    private func storeSamsungTokenIfNeeded(from text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObject = json["data"] as? [String: Any],
              let token = dataObject["token"] as? String,
              let ip = pendingConnectDevice?.ipAddress ?? currentDevice?.ipAddress else {
            return
        }

        UserDefaults.standard.set(token, forKey: samsungTokenKey(ip: ip))
    }

    private func samsungToken(for ip: String) -> String? {
        return UserDefaults.standard.string(forKey: samsungTokenKey(ip: ip))
    }

    private func samsungTokenKey(ip: String) -> String {
        return "samsung.remote.token.\(ip)"
    }

    // MARK: - Sony Bravia IRCC
    private func connectSony(to device: TVDevice) {
        guard let url = sonySystemURL(for: device) else {
            delegate?.didFailToConnect(error: "IP hoặc port Sony không hợp lệ.")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setSonyAuthHeader(on: &request, device: device)
        request.httpBody = """
        {"method":"getPowerStatus","params":[],"id":1,"version":"1.0"}
        """.data(using: .utf8)

        urlSession.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }

                if let error {
                    self.delegate?.didFailToConnect(error: "Không kết nối được Sony TV: \(error.localizedDescription)")
                    return
                }

                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                guard (200..<300).contains(statusCode) else {
                    let message = data.flatMap { String(data: $0, encoding: .utf8) } ?? "HTTP \(statusCode)"
                    self.delegate?.didFailToConnect(
                        error: "Sony TV từ chối kết nối (\(statusCode)). Kiểm tra IP Control và Pre-Shared Key. \(message)"
                    )
                    return
                }

                var connectedDevice = device
                connectedDevice.isConnected = true
                self.currentDevice = connectedDevice
                self.delegate?.didConnect(to: connectedDevice)
            }
        }.resume()
    }

    private func sendSonyCommand(_ command: RemoteCommand,
                                 to device: TVDevice,
                                 completion: ((Bool) -> Void)?) {
        guard let irccCode = sonyIRCCCode(for: command),
              let url = sonyIRCCURL(for: device) else {
            delegate?.didFailToConnect(error: "Lệnh này chưa được map cho Sony Bravia.")
            completion?(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/xml; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("\"urn:schemas-sony-com:service:IRCC:1#X_SendIRCC\"", forHTTPHeaderField: "SOAPACTION")
        setSonyAuthHeader(on: &request, device: device)
        request.httpBody = sonyIRCCSOAPBody(code: irccCode).data(using: .utf8)

        urlSession.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error {
                    self?.delegate?.didFailToConnect(error: "Gửi lệnh Sony thất bại: \(error.localizedDescription)")
                    completion?(false)
                    return
                }

                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                if (200..<300).contains(statusCode) {
                    self?.delegate?.didReceiveResponse("SENT")
                    completion?(true)
                } else {
                    let message = data.flatMap { String(data: $0, encoding: .utf8) } ?? "HTTP \(statusCode)"
                    self?.delegate?.didFailToConnect(error: "Sony TV không nhận lệnh (\(statusCode)). \(message)")
                    completion?(false)
                }
            }
        }.resume()
    }

    private func sonySystemURL(for device: TVDevice) -> URL? {
        sonyURL(for: device, path: "/sony/system")
    }

    private func sonyIRCCURL(for device: TVDevice) -> URL? {
        sonyURL(for: device, path: "/sony/IRCC")
    }

    private func sonyURL(for device: TVDevice, path: String) -> URL? {
        var components = URLComponents()
        components.scheme = "http"
        components.host = device.ipAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        components.port = device.port > 0 ? device.port : 80
        components.path = path
        return components.url
    }

    private func setSonyAuthHeader(on request: inout URLRequest, device: TVDevice) {
        if let key = device.authToken, !key.isEmpty {
            request.setValue(key, forHTTPHeaderField: "X-Auth-PSK")
        }
    }

    private func sonyIRCCSOAPBody(code: String) -> String {
        """
        <?xml version="1.0"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body>
            <u:X_SendIRCC xmlns:u="urn:schemas-sony-com:service:IRCC:1">
              <IRCCCode>\(code)</IRCCCode>
            </u:X_SendIRCC>
          </s:Body>
        </s:Envelope>
        """
    }

    private func sonyIRCCCode(for command: RemoteCommand) -> String? {
        switch command {
        case .power: return "AAAAAQAAAAEAAAAVAw=="
        case .powerOn: return "AAAAAQAAAAEAAAAuAw=="
        case .powerOff: return "AAAAAQAAAAEAAAAvAw=="
        case .up: return "AAAAAQAAAAEAAAB0Aw=="
        case .down: return "AAAAAQAAAAEAAAB1Aw=="
        case .left: return "AAAAAQAAAAEAAAA0Aw=="
        case .right: return "AAAAAQAAAAEAAAAzAw=="
        case .ok: return "AAAAAQAAAAEAAABlAw=="
        case .back: return "AAAAAgAAAJcAAAAjAw=="
        case .home: return "AAAAAQAAAAEAAABgAw=="
        case .menu: return "AAAAAgAAAJcAAAA2Aw=="
        case .volumeUp: return "AAAAAQAAAAEAAAASAw=="
        case .volumeDown: return "AAAAAQAAAAEAAAATAw=="
        case .mute: return "AAAAAQAAAAEAAAAUAw=="
        case .channelUp: return "AAAAAQAAAAEAAAAQAw=="
        case .channelDown: return "AAAAAQAAAAEAAAARAw=="
        case .play: return "AAAAAgAAAJcAAAAaAw=="
        case .pause: return "AAAAAgAAAJcAAAAZAw=="
        case .stop: return "AAAAAgAAAJcAAAAYAw=="
        case .rewind: return "AAAAAgAAAJcAAAAbAw=="
        case .fastForward: return "AAAAAgAAAJcAAAAcAw=="
        case .num0: return "AAAAAQAAAAEAAAAJAw=="
        case .num1: return "AAAAAQAAAAEAAAAAAw=="
        case .num2: return "AAAAAQAAAAEAAAABAw=="
        case .num3: return "AAAAAQAAAAEAAAACAw=="
        case .num4: return "AAAAAQAAAAEAAAADAw=="
        case .num5: return "AAAAAQAAAAEAAAAEAw=="
        case .num6: return "AAAAAQAAAAEAAAAFAw=="
        case .num7: return "AAAAAQAAAAEAAAAGAw=="
        case .num8: return "AAAAAQAAAAEAAAAHAw=="
        case .num9: return "AAAAAQAAAAEAAAAIAw=="
        case .source: return "AAAAAQAAAAEAAAAlAw=="
        case .hdmi1: return "AAAAAgAAABoAAABaAw=="
        case .hdmi2: return "AAAAAgAAABoAAABbAw=="
        case .record, .netflix, .youtube:
            return nil
        }
    }

    // MARK: - Android TV Remote v2
    private func connectAndroidTV(to device: TVDevice) {
        guard let manager = AndroidTVBoxRemoteManager() else {
            delegate?.didFailToConnect(error: "Không chuẩn bị được Android TV pairing certificate.")
            return
        }

        pendingConnectDevice = device
        androidTVRemoteManager = manager

        // Start a timeout guard so we don't hang forever
        pendingConnectTimer?.invalidate()
        pendingConnectTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: false) { [weak self] _ in
            guard let self = self, self.currentDevice == nil else { return }
            self.androidTVRemoteManager?.disconnect()
            self.disconnectSilently()
            self.delegate?.didFailToConnect(error: "Không kết nối được Android TV Box. Kiểm tra cùng Wi‑Fi, port 6467 mở và thử ghép đôi lại.")
        }

        manager.onStateChanged = { [weak self] state in
            guard let self else { return }

            switch state {
            case .needsPairingCode:
                if let device = self.pendingConnectDevice {
                    self.delegate?.didRequestPairingCode(for: device)
                }

            case .paired:
                self.delegate?.didReceiveResponse("Android TV paired")

            case .connected:
                self.pendingConnectTimer?.invalidate()
                self.pendingConnectTimer = nil

                var connectedDevice = device
                connectedDevice.isConnected = true
                self.currentDevice = connectedDevice
                self.pendingConnectDevice = nil
                self.delegate?.didConnect(to: connectedDevice)

            case .error(let message):
                self.pendingConnectTimer?.invalidate()
                self.pendingConnectTimer = nil
                self.delegate?.didFailToConnect(error: "Android TV lỗi kết nối/pairing: \(message)")
            }
        }

        manager.connect(host: device.ipAddress)
    }

    func submitAndroidTVPairingCode(_ code: String) {
        androidTVRemoteManager?.sendPairingCode(code)
    }

    var isConnected: Bool {
        return currentDevice?.isConnected ?? false
    }

    var connectedDevice: TVDevice? {
        return currentDevice
    }
}

extension TVRemoteService: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.didReceiveResponse("Samsung WebSocket opened")
        }
    }

    func urlSession(_ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                    reason: Data?) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let device = self.currentDevice else { return }
            self.disconnectSilently()
            self.delegate?.didDisconnect(from: device)
        }
    }
}
