import Foundation

// MARK: - TV Device Model
struct TVDevice: Equatable {
    let id: String
    let name: String
    let ipAddress: String
    let port: Int
    let brand: TVBrand
    let authToken: String?
    var isConnected: Bool = false

    init(id: String,
         name: String,
         ipAddress: String,
         port: Int,
         brand: TVBrand,
         authToken: String? = nil,
         isConnected: Bool = false) {
        self.id = id
        self.name = name
        self.ipAddress = ipAddress
        self.port = port
        self.brand = brand
        self.authToken = authToken
        self.isConnected = isConnected
    }

    static func == (lhs: TVDevice, rhs: TVDevice) -> Bool {
        return lhs.id == rhs.id
    }
}

enum TVBrand: String, CaseIterable {
    case samsung = "Samsung"
    case lg = "LG"
    case sony = "Sony"
    case androidTV = "Android TV"
    case toshiba = "Toshiba"
    case philips = "Philips"
    case generic = "Generic"

    var icon: String {
        switch self {
        case .samsung: return "tv.fill"
        case .lg: return "tv.fill"
        case .sony: return "tv.fill"
        case .androidTV: return "play.tv.fill"
        case .toshiba: return "tv.fill"
        case .philips: return "tv.fill"
        case .generic: return "tv"
        }
    }

    var accentColor: String {
        switch self {
        case .samsung: return "#1428A0"
        case .lg: return "#A50034"
        case .sony: return "#003087"
        case .androidTV: return "#3DDC84"
        case .toshiba: return "#E4002B"
        case .philips: return "#0A3D91"
        case .generic: return "#6C63FF"
        }
    }
}

// MARK: - Remote Command
enum RemoteCommand: String {
    // Power
    case power = "KEY_POWER"
    case powerOn = "KEY_POWERON"
    case powerOff = "KEY_POWEROFF"

    // Navigation
    case up = "KEY_UP"
    case down = "KEY_DOWN"
    case left = "KEY_LEFT"
    case right = "KEY_RIGHT"
    case ok = "KEY_ENTER"
    case back = "KEY_RETURN"
    case home = "KEY_HOME"
    case menu = "KEY_MENU"

    // Volume
    case volumeUp = "KEY_VOLUP"
    case volumeDown = "KEY_VOLDOWN"
    case mute = "KEY_MUTE"

    // Channel
    case channelUp = "KEY_CHUP"
    case channelDown = "KEY_CHDOWN"

    // Media
    case play = "KEY_PLAY"
    case pause = "KEY_PAUSE"
    case stop = "KEY_STOP"
    case rewind = "KEY_REWIND"
    case fastForward = "KEY_FF"
    case record = "KEY_REC"

    // Numbers
    case num0 = "KEY_0"
    case num1 = "KEY_1"
    case num2 = "KEY_2"
    case num3 = "KEY_3"
    case num4 = "KEY_4"
    case num5 = "KEY_5"
    case num6 = "KEY_6"
    case num7 = "KEY_7"
    case num8 = "KEY_8"
    case num9 = "KEY_9"

    // Sources
    case source = "KEY_SOURCE"
    case hdmi1 = "KEY_HDMI1"
    case hdmi2 = "KEY_HDMI2"

    // Apps
    case netflix = "KEY_NETFLIX"
    case youtube = "KEY_YOUTUBE"
}

// MARK: - Connection State
enum ConnectionState {
    case disconnected
    case scanning
    case connecting
    case connected
    case error(String)
}
