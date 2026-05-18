import Foundation

final class AndroidTVBoxRemoteManager {
    enum State {
        case needsPairingCode
        case paired
        case connected
        case error(String)
    }

    var onStateChanged: ((State) -> Void)?

    private let queue = DispatchQueue(label: "tvremote.androidtv.remote")
    private let pairingManager: PairingManager
    private let remoteManager: RemoteManager
    private var host = ""

    init?() {
        let cryptoManager = CryptoManager()

        // Early checks for certificate presence to surface clear errors
        guard Bundle.main.url(forResource: "cert", withExtension: "der") != nil else {
            return nil
        }
        guard Bundle.main.url(forResource: "cert", withExtension: "p12") != nil else {
            return nil
        }

        cryptoManager.clientPublicCertificate = {
            guard let url = Bundle.main.url(forResource: "cert", withExtension: "der") else {
                return .Error(.loadCertFromURLError(AndroidTVBoxRemoteError.certificateNotFound))
            }

            return CertManager().getSecKey(url)
        }

        let tlsManager = TLSManager {
            guard let url = Bundle.main.url(forResource: "cert", withExtension: "p12") else {
                return .Error(.loadCertFromURLError(AndroidTVBoxRemoteError.certificateNotFound))
            }

            return CertManager().cert(url, "")
        }

        tlsManager.secTrustClosure = { secTrust in
            cryptoManager.serverPublicCertificate = {
                if #available(iOS 14.0, *) {
                    guard let key = SecTrustCopyKey(secTrust) else {
                        return .Error(.secTrustCopyKeyError)
                    }
                    return .Result(key)
                } else {
                    guard let key = SecTrustCopyPublicKey(secTrust) else {
                        return .Error(.secTrustCopyKeyError)
                    }
                    return .Result(key)
                }
            }
        }

        pairingManager = PairingManager(tlsManager, cryptoManager)
        remoteManager = RemoteManager(
            tlsManager,
            CommandNetwork.DeviceInfo("TV Remote", "iPhone", "1.0.0", "tvremote", "1")
        )
    }

    func connect(host: String) {
        self.host = host

        queue.async { [weak self] in
            guard let self else { return }

            self.remoteManager.stateChanged = { [weak self] state in
                guard let self else { return }

                switch state {
                case .paired:
                    DispatchQueue.main.async { self.onStateChanged?(.connected) }

                case .error(.connectionWaitingError), .error(.connectionFailed):
                    self.startPairing()

                case .error(let error):
                    DispatchQueue.main.async { self.onStateChanged?(.error(error.localizedDescription)) }

                default:
                    break
                }
            }

            self.remoteManager.connect(host, timeout: 8)
        }
    }

    func sendPairingCode(_ code: String) {
        queue.async { [weak self] in
            self?.pairingManager.sendSecret(code.uppercased())
        }
    }

    func disconnect() {
        queue.async { [weak self] in
            self?.pairingManager.disconnect()
            self?.remoteManager.disconnect()
        }
    }

    func send(command: RemoteCommand) {
        guard let key = androidKey(for: command) else { return }
        queue.async { [weak self] in
            self?.remoteManager.send(KeyPress(key))
        }
    }

    private func startPairing() {
        pairingManager.stateChanged = { [weak self] state in
            guard let self else { return }

            switch state {
            case .waitingCode:
                DispatchQueue.main.async { self.onStateChanged?(.needsPairingCode) }

            case .successPaired:
                DispatchQueue.main.async { self.onStateChanged?(.paired) }
                self.remoteManager.connect(self.host, timeout: 8)

            case .error(let error):
                DispatchQueue.main.async { self.onStateChanged?(.error(error.localizedDescription)) }

            default:
                break
            }
        }

        pairingManager.connect(host, "TV Remote", "iPhone", timeout: 8)
    }

    private func androidKey(for command: RemoteCommand) -> Key? {
        switch command {
        case .power: return .KEYCODE_POWER
        case .up: return .KEYCODE_DPAD_UP
        case .down: return .KEYCODE_DPAD_DOWN
        case .left: return .KEYCODE_DPAD_LEFT
        case .right: return .KEYCODE_DPAD_RIGHT
        case .ok: return .KEYCODE_DPAD_CENTER
        case .back: return .KEYCODE_BACK
        case .home: return .KEYCODE_HOME
        case .menu: return .KEYCODE_MENU
        case .volumeUp: return .KEYCODE_VOLUME_UP
        case .volumeDown: return .KEYCODE_VOLUME_DOWN
        case .mute: return .KEYCODE_MUTE
        case .channelUp: return .KEYCODE_CHANNEL_UP
        case .channelDown: return .KEYCODE_CHANNEL_DOWN
        case .play: return .KEYCODE_MEDIA_PLAY
        case .pause: return .KEYCODE_MEDIA_PAUSE
        case .stop: return .KEYCODE_MEDIA_STOP
        case .rewind: return .KEYCODE_MEDIA_REWIND
        case .fastForward: return .KEYCODE_MEDIA_FAST_FORWARD
        case .num0: return .KEYCODE_0
        case .num1: return .KEYCODE_1
        case .num2: return .KEYCODE_2
        case .num3: return .KEYCODE_3
        case .num4: return .KEYCODE_4
        case .num5: return .KEYCODE_5
        case .num6: return .KEYCODE_6
        case .num7: return .KEYCODE_7
        case .num8: return .KEYCODE_8
        case .num9: return .KEYCODE_9
        case .source: return .KEYCODE_TV_INPUT
        case .record: return .KEYCODE_MEDIA_RECORD
        case .netflix, .youtube, .powerOn, .powerOff, .hdmi1, .hdmi2:
            return nil
        }
    }
}

private enum AndroidTVBoxRemoteError: Error {
    case certificateNotFound
}
