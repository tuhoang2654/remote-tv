// TVRemoteService.swift

import Foundation
import Network

protocol TVRemoteServiceDelegate: AnyObject {
    func didDiscoverDevice(_ device: TVDevice)
    func didConnect(to device: TVDevice)
    func didDisconnect(from device: TVDevice, error: Error?)
    func didFailToConnect(to device: TVDevice, error: Error)
    func didUpdateStatus(_ status: String)
}

enum TVBrand: String {
    case samsung
    case sony
    case androidTV
    case unknown
}

struct TVDevice: Hashable {
    let id: UUID
    var name: String
    var ip: String
    var port: Int
    var brand: TVBrand
    var authToken: String?
    var isConnected: Bool = false
}

enum RemoteCommand {
    case power
    case volumeUp
    case volumeDown
    case channelUp
    case channelDown
    case navigationUp
    case navigationDown
    case navigationLeft
    case navigationRight
    case navigationSelect
    case back
    case home
    case menu
    // Add more commands as needed
}

final class TVRemoteService {

    weak var delegate: TVRemoteServiceDelegate?

    private var discoveredDevices = Set<TVDevice>()
    private var isScanning = false

    private let ssdpAddress = "239.255.255.250"
    private let ssdpPort: UInt16 = 1900

    private let samsungPorts = [8001, 8002]
    private let androidTVPorts = [6466, 6467]
    private let sonyPort = 80

    private var samsungWebSocketTasks: [String: URLSessionWebSocketTask] = [:]
    private var samsungTokens: [String: String] = [:]

    private let userDefaultsTokenKey = "SamsungTokens"

    private let dispatchQueue = DispatchQueue(label: "tvremote.service.queue", attributes: .concurrent)

    init() {
        loadSamsungTokens()
    }

    // MARK: - Public Scanning Methods

    func startScanning() {
        guard !isScanning else { return }
        isScanning = true
        discoveredDevices.removeAll()
        delegate?.didUpdateStatus("Scanning devices...")
        scanSSDPDevices()
        // Delay subnet scan to avoid network congestion
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.scanSubnetDevices()
        }
    }

    func stopScanning() {
        isScanning = false
    }

    // MARK: - SSDP Scan

    private func scanSSDPDevices() {
        guard isScanning else { return }
        delegate?.didUpdateStatus("Scanning devices via SSDP...")
        let ssdpMessage = """
        M-SEARCH * HTTP/1.1\r
        HOST: \(ssdpAddress):\(ssdpPort)\r
        MAN: "ssdp:discover"\r
        MX: 1\r
        ST: ssdp:all\r
        \r
        """

        guard let udpSocket = try? NWConnection(host: NWEndpoint.Host(ssdpAddress), port: .init(rawValue: ssdpPort)!, using: .udp) else {
            delegate?.didUpdateStatus("Failed to create SSDP UDP socket")
            return
        }

        udpSocket.stateUpdateHandler = { newState in
            switch newState {
            case .ready:
                self.sendSSDPDiscover(with: udpSocket, message: ssdpMessage)
                self.receiveSSDPResponses(on: udpSocket)
            case .failed(let error):
                self.delegate?.didUpdateStatus("SSDP UDP socket failed: \(error)")
                udpSocket.cancel()
            default:
                break
            }
        }

        udpSocket.start(queue: dispatchQueue)
    }

    private func sendSSDPDiscover(with connection: NWConnection, message: String) {
        let data = message.data(using: .utf8)!
        connection.send(content: data, completion: .contentProcessed({ error in
            if let error = error {
                self.delegate?.didUpdateStatus("Failed to send SSDP M-SEARCH: \(error)")
            }
        }))
    }

    private func receiveSSDPResponses(on connection: NWConnection) {
        connection.receiveMessage { [weak self] (data, context, isComplete, error) in
            guard let self = self else { return }
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                self.handleSSDPResponse(responseString)
            }
            if self.isScanning {
                self.receiveSSDPResponses(on: connection)
            } else {
                connection.cancel()
            }
        }
    }

    private func handleSSDPResponse(_ response: String) {
        guard let location = parseHeader(response, header: "LOCATION") ?? parseHeader(response, header: "location") else {
            return
        }

        downloadDeviceDescription(from: location) { [weak self] device in
            guard let device = device else { return }
            if self?.discoveredDevices.contains(device) == false {
                self?.discoveredDevices.insert(device)
                DispatchQueue.main.async {
                    self?.delegate?.didDiscoverDevice(device)
                }
            }
        }
    }

    private func parseHeader(_ httpResponse: String, header: String) -> String? {
        let lines = httpResponse.split(separator: "\r\n")
        for line in lines {
            if line.lowercased().starts(with: header.lowercased() + ":") {
                let parts = line.split(separator: ":")
                if parts.count > 1 {
                    return parts[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return nil
    }

    private func downloadDeviceDescription(from urlString: String, completion: @escaping (TVDevice?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            let device = self.deviceFromDescriptionXML(data: data, baseURL: url)
            completion(device)
        }
        task.resume()
    }

    private func deviceFromDescriptionXML(data: Data, baseURL: URL) -> TVDevice? {
        // Simple XML parsing to find friendlyName and manufacturer (brand)
        // For brevity, using string search - in production use XMLParser

        guard let xmlString = String(data: data, encoding: .utf8) else { return nil }

        func extractTag(_ tag: String) -> String? {
            guard let startRange = xmlString.range(of: "<\(tag)>"),
                  let endRange = xmlString.range(of: "</\(tag)>") else { return nil }
            return String(xmlString[startRange.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let name = extractTag("friendlyName") ?? "Unknown Device"
        let manufacturer = extractTag("manufacturer")?.lowercased() ?? ""
        let ip = baseURL.host ?? ""
        let port = baseURL.port ?? 80

        let brand: TVBrand
        if manufacturer.contains("samsung") {
            brand = .samsung
        } else if manufacturer.contains("sony") {
            brand = .sony
        } else {
            brand = .unknown
        }

        return TVDevice(id: UUID(), name: name, ip: ip, port: port, brand: brand, authToken: nil, isConnected: false)
    }

    // MARK: - Subnet Scan (TCP connect scan)

    private func scanSubnetDevices() {
        guard isScanning else { return }
        delegate?.didUpdateStatus("Scanning subnet devices...")

        guard let localIP = getWiFiAddress() else {
            delegate?.didUpdateStatus("Unable to get local IP address")
            return
        }

        let subnet = localIP.components(separatedBy: ".").dropLast().joined(separator: ".")
        let portsToScan = samsungPorts + androidTVPorts + [sonyPort]

        let semaphore = DispatchSemaphore(value: 30) // Limit concurrency to 30

        for i in 1...254 {
            guard isScanning else { break }
            semaphore.wait()

            dispatchQueue.async {
                let testIP = "\(subnet).\(i)"
                self.scanPortsOnHost(testIP, ports: portsToScan) { device in
                    if let device = device {
                        self.discoveredDevices.insert(device)
                        DispatchQueue.main.async {
                            self.delegate?.didDiscoverDevice(device)
                        }
                    }
                    semaphore.signal()
                }
            }
        }
    }

    private func scanPortsOnHost(_ host: String, ports: [Int], completion: @escaping (TVDevice?) -> Void) {
        let group = DispatchGroup()
        var foundDevice: TVDevice?

        for port in ports {
            group.enter()
            var socketFD: Int32 = -1

            defer {
                if socketFD != -1 {
                    close(socketFD)
                }
            }

            socketFD = socket(AF_INET, SOCK_STREAM, 0)
            guard socketFD >= 0 else {
                group.leave()
                continue
            }

            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = in_port_t(UInt16(port).bigEndian)
            inet_pton(AF_INET, host, &addr.sin_addr)

            let addrLen = socklen_t(MemoryLayout.size(ofValue: addr))

            let flags = fcntl(socketFD, F_GETFL, 0)
            fcntl(socketFD, F_SETFL, flags | O_NONBLOCK)

            let result = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddrPtr in
                    connect(socketFD, sockAddrPtr, addrLen)
                }
            }

            if result == 0 {
                // Connected immediately
                foundDevice = self.deviceFromOpenPort(ip: host, port: port)
                group.leave()
                break
            } else if errno == EINPROGRESS {
                // Wait for connection with timeout
                var writeFDs = fd_set()
                FD_ZERO(&writeFDs)
                FD_SET(socketFD, &writeFDs)

                var timeout = timeval(tv_sec: 1, tv_usec: 0)

                let selectResult = select(socketFD + 1, nil, &writeFDs, nil, &timeout)

                if selectResult > 0 && FD_ISSET(socketFD, &writeFDs) {
                    var err: Int32 = 0
                    var len = socklen_t(MemoryLayout<Int32>.size)
                    getsockopt(socketFD, SOL_SOCKET, SO_ERROR, &err, &len)
                    if err == 0 {
                        foundDevice = self.deviceFromOpenPort(ip: host, port: port)
                        group.leave()
                        break
                    }
                }
            }
            group.leave()
        }

        group.notify(queue: dispatchQueue) {
            completion(foundDevice)
        }
    }

    private func deviceFromOpenPort(ip: String, port: Int) -> TVDevice? {
        let brand: TVBrand
        if samsungPorts.contains(port) {
            brand = .samsung
        } else if androidTVPorts.contains(port) {
            brand = .androidTV
        } else if port == sonyPort {
            brand = .sony
        } else {
            brand = .unknown
        }
        let name = "\(brand.rawValue.capitalized) TV (\(ip))"
        return TVDevice(id: UUID(), name: name, ip: ip, port: port, brand: brand, authToken: nil, isConnected: false)
    }

    // MARK: - Connection Methods

    func connect(to device: TVDevice) {
        switch device.brand {
        case .samsung:
            connectSamsung(device)
        case .sony:
            connectSony(device)
        case .androidTV:
            connectAndroidTV(device)
        default:
            delegate?.didFailToConnect(to: device, error: NSError(domain: "TVRemoteService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unsupported brand"]))
        }
    }

    // MARK: Samsung Connection & WebSocket

    private func connectSamsung(_ device: TVDevice) {
        delegate?.didUpdateStatus("Connecting to Samsung TV \(device.ip)...")

        let useSecure = (device.port == 8002)
        let schema = useSecure ? "wss" : "ws"
        guard let encodedName = "TVRemoteApp".data(using: .utf8)?.base64EncodedString() else {
            delegate?.didFailToConnect(to: device, error: NSError(domain: "TVRemoteService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to encode app name"]))
            return
        }

        var urlComponents = URLComponents()
        urlComponents.scheme = schema
        urlComponents.host = device.ip
        urlComponents.port = device.port
        urlComponents.path = "/api/v2/channels/samsung.remote.control"
        urlComponents.queryItems = [
            URLQueryItem(name: "name", value: encodedName)
        ]

        guard let url = urlComponents.url else {
            delegate?.didFailToConnect(to: device, error: NSError(domain: "TVRemoteService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid WebSocket URL"]))
            return
        }

        var request = URLRequest(url: url)
        if let token = samsungToken(for: device.ip) {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }

        let task = URLSession(configuration: .default).webSocketTask(with: request)
        samsungWebSocketTasks[device.ip] = task

        task.resume()

        // Send initial handshake message (if protocol requires)
        // Wait for welcome message and token

        receiveSamsungMessage(for: device, task: task)

        // Timeout handling
        DispatchQueue.global().asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self = self else { return }
            if !device.isConnected {
                task.cancel(with: .goingAway, reason: nil)
                DispatchQueue.main.async {
                    self.delegate?.didFailToConnect(to: device, error: NSError(domain: "TVRemoteService", code: -4, userInfo: [NSLocalizedDescriptionKey: "Samsung connection timeout"]))
                }
            }
        }
    }

    private func receiveSamsungMessage(for device: TVDevice, task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    // Parse token if included, example format assumed {"token":"..."}
                    if let token = self.extractSamsungToken(from: text) {
                        self.storeSamsungToken(token, for: device.ip)
                    }
                    var connectedDevice = device
                    connectedDevice.isConnected = true
                    DispatchQueue.main.async {
                        self.delegate?.didConnect(to: connectedDevice)
                    }
                case .data(_):
                    break
                @unknown default:
                    break
                }
                if task.state == .running {
                    self.receiveSamsungMessage(for: device, task: task)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.delegate?.didFailToConnect(to: device, error: error)
                }
            }
        }
    }

    private func extractSamsungToken(from message: String) -> String? {
        // Simplified parse for token json
        if let data = message.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let token = json["token"] as? String {
            return token
        }
        return nil
    }

    private func storeSamsungToken(_ token: String, for ip: String) {
        samsungTokens[ip] = token
        UserDefaults.standard.set(samsungTokens, forKey: userDefaultsTokenKey)
    }

    private func samsungToken(for ip: String) -> String? {
        return samsungTokens[ip]
    }

    private func loadSamsungTokens() {
        if let stored = UserDefaults.standard.dictionary(forKey: userDefaultsTokenKey) as? [String: String] {
            samsungTokens = stored
        }
    }

    func sendCommand(_ command: RemoteCommand, to device: TVDevice) {
        switch device.brand {
        case .samsung:
            sendSamsungCommand(command, to: device)
        case .sony:
            sendSonyCommand(command, to: device)
        case .androidTV:
            sendAndroidTVCommand(command, to: device)
        default:
            break
        }
    }

    private func sendSamsungCommand(_ command: RemoteCommand, to device: TVDevice) {
        guard let task = samsungWebSocketTasks[device.ip], device.isConnected else { return }

        let keyCode = samsungKeyCode(for: command)
        let messageDict: [String: Any] = [
            "method": "ms.remote.control",
            "params": [
                "Cmd": "Click",
                "DataOfCmd": keyCode,
                "Option": false,
                "TypeOfRemote": "SendRemoteKey"
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: messageDict, options: []) else { return }
        let message = URLSessionWebSocketTask.Message.string(String(data: data, encoding: .utf8) ?? "")

        task.send(message) { error in
            if let error = error {
                DispatchQueue.main.async {
                    self.delegate?.didDisconnect(from: device, error: error)
                }
            }
        }
    }

    private func samsungKeyCode(for command: RemoteCommand) -> String {
        switch command {
        case .power: return "KEY_POWER"
        case .volumeUp: return "KEY_VOLUP"
        case .volumeDown: return "KEY_VOLDOWN"
        case .channelUp: return "KEY_CHUP"
        case .channelDown: return "KEY_CHDOWN"
        case .navigationUp: return "KEY_UP"
        case .navigationDown: return "KEY_DOWN"
        case .navigationLeft: return "KEY_LEFT"
        case .navigationRight: return "KEY_RIGHT"
        case .navigationSelect: return "KEY_ENTER"
        case .back: return "KEY_RETURN"
        case .home: return "KEY_HOME"
        case .menu: return "KEY_MENU"
        }
    }

    // MARK: Sony Connection & IRCC

    private func connectSony(_ device: TVDevice) {
        delegate?.didUpdateStatus("Connecting to Sony TV \(device.ip)...")
        // Send getPowerStatus request with optional PSK

        let urlStr = "http://\(device.ip):\(device.port)/sony/system"
        guard let url = URL(string: urlStr) else {
            delegate?.didFailToConnect(to: device, error: NSError(domain: "TVRemoteService", code: -5, userInfo: [NSLocalizedDescriptionKey: "Invalid Sony URL"]))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let body: [String: Any] = [
            "id": 1,
            "method": "getPowerStatus",
            "version": "1.0",
            "params": []
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // If PSK needed, add header here
        if let psk = device.authToken {
            request.addValue(psk, forHTTPHeaderField: "X-Auth-PSK")
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.delegate?.didFailToConnect(to: device, error: error)
                }
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  json["result"] != nil else {
                DispatchQueue.main.async {
                    self.delegate?.didFailToConnect(to: device, error: NSError(domain: "TVRemoteService", code: -6, userInfo: [NSLocalizedDescriptionKey: "Sony TV authentication failed"]))
                }
                return
            }

            var connectedDevice = device
            connectedDevice.isConnected = true
            DispatchQueue.main.async {
                self.delegate?.didConnect(to: connectedDevice)
            }
        }
        task.resume()

        // Timeout 10s
        DispatchQueue.global().asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self = self else { return }
            if !device.isConnected {
                DispatchQueue.main.async {
                    self.delegate?.didFailToConnect(to: device, error: NSError(domain: "TVRemoteService", code: -7, userInfo: [NSLocalizedDescriptionKey: "Sony connection timeout"]))
                }
            }
        }
    }

    func sendSonyCommand(_ command: RemoteCommand, to device: TVDevice) {
        guard device.isConnected else { return }

        let irccCode = sonyIRCCCode(for: command)
        let soapBody = """
        <?xml version="1.0"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
            <s:Body>
                <u:X_SendIRCC xmlns:u="urn:schemas-sony-com:service:IRCC:1">
                    <IRCCCode>\(irccCode)</IRCCCode>
                </u:X_SendIRCC>
            </s:Body>
        </s:Envelope>
        """

        let urlStr = "http://\(device.ip):\(device.port)/sony/IRCC"
        guard let url = URL(string: urlStr) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = soapBody.data(using: .utf8)
        request.setValue("text/xml; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("urn:schemas-sony-com:service:IRCC:1#X_SendIRCC", forHTTPHeaderField: "SOAPACTION")

        if let psk = device.authToken {
            request.addValue(psk, forHTTPHeaderField: "X-Auth-PSK")
        }

        let task = URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.delegate?.didDisconnect(from: device, error: error)
                }
            }
        }
        task.resume()
    }

    private func sonyIRCCCode(for command: RemoteCommand) -> String {
        switch command {
        case .power: return "AAAAAQAAAAEAAAAVAw=="
        case .volumeUp: return "AAAAAQAAAAEAAAASAw=="
        case .volumeDown: return "AAAAAQAAAAEAAAATAw=="
        case .channelUp: return "AAAAAQAAAAEAAAAUAw=="
        case .channelDown: return "AAAAAQAAAAEAAAATAw==" // Possibly same as volume down? Adjust if needed
        case .navigationUp: return "AAAAAQAAAAEAAAB0Aw=="
        case .navigationDown: return "AAAAAQAAAAEAAAB1Aw=="
        case .navigationLeft: return "AAAAAQAAAAEAAAB2Aw=="
        case .navigationRight: return "AAAAAQAAAAEAAAB3Aw=="
        case .navigationSelect: return "AAAAAQAAAAEAAABlAw=="
        case .back: return "AAAAAQAAAAEAAAAjAw=="
        case .home: return "AAAAAQAAAAEAAABgAw=="
        case .menu: return "AAAAAQAAAAEAAAAUAw=="
        }
    }

    // MARK: Android TV Connection & Pairing

    private var androidTVManager: AndroidTVBoxRemoteManager?

    private func connectAndroidTV(_ device: TVDevice) {
        delegate?.didUpdateStatus("Connecting to Android TV \(device.ip)...")
        androidTVManager = AndroidTVBoxRemoteManager(device: device)
        androidTVManager?.delegate = self
        androidTVManager?.startPairing()
        // Timeout 20s
        DispatchQueue.global().asyncAfter(deadline: .now() + 20) { [weak self] in
            guard let self = self, let manager = self.androidTVManager else { return }
            if !manager.isConnected {
                DispatchQueue.main.async {
                    self.delegate?.didFailToConnect(to: device, error: NSError(domain: "TVRemoteService", code: -8, userInfo: [NSLocalizedDescriptionKey: "Android TV connection timeout"]))
                }
            }
        }
    }

    func sendAndroidTVCommand(_ command: RemoteCommand, to device: TVDevice) {
        guard let manager = androidTVManager, manager.device.ip == device.ip, device.isConnected else { return }
        manager.sendCommand(command)
    }

    // MARK: - Helpers

    private func getWiFiAddress() -> String? {
        var address: String?

        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                guard let interface = ptr?.pointee else { return nil }
                let name = String(cString: interface.ifa_name)
                let addrFamily = interface.ifa_addr.pointee.sa_family

                if addrFamily == UInt8(AF_INET) && name == "en0" {
                    var addr = interface.ifa_addr.pointee
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if (getnameinfo(&addr, socklen_t(interface.ifa_addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST) == 0) {
                        address = String(cString: hostname)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }

        return address
    }
}

// MARK: - AndroidTVBoxRemoteManagerDelegate

extension TVRemoteService: AndroidTVBoxRemoteManagerDelegate {
    func androidTVBoxRemoteManager(_ manager: AndroidTVBoxRemoteManager, didUpdateState state: AndroidTVBoxRemoteManager.State) {
        switch state {
        case .paired(let device):
            var connectedDevice = device
            connectedDevice.isConnected = true
            DispatchQueue.main.async {
                self.delegate?.didConnect(to: connectedDevice)
            }
        case .failedToPair(let error, let device):
            DispatchQueue.main.async {
                self.delegate?.didFailToConnect(to: device, error: error)
            }
        case .disconnected(let error, let device):
            DispatchQueue.main.async {
                self.delegate?.didDisconnect(from: device, error: error)
            }
        default:
            break
        }
    }
}
