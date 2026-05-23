import AVFoundation
import Speech
import UIKit

class RemoteViewController: UIViewController {

    // MARK: - Properties
    private let device: TVDevice
    private let service = TVRemoteService.shared
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "vi_VN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var isListeningForVoice = false

    // MARK: - UI
    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.alwaysBounceVertical = true
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private lazy var contentStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 20
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private lazy var headerView = RemoteHeaderView(device: device)
    private lazy var powerSection = PowerSectionView(frame: .zero)
    private lazy var voiceSection = VoiceControlSectionView(frame: .zero)
    private lazy var volumeChannelSection = VolumeChannelSectionView(frame: .zero)
    private lazy var navSection = NavigationSectionView(frame: .zero)
    private lazy var mediaSection = MediaSectionView(frame: .zero)
    private lazy var castSection = CastSectionView(frame: .zero)
    private lazy var numpadSection = NumpadSectionView(frame: .zero)
    private lazy var appsSection = AppShortcutsSectionView(frame: .zero)

    private lazy var backgroundView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        let gradient = CAGradientLayer()
        gradient.colors = [
            Theme.Color.background.cgColor,
            UIColor(hex: "#0E0E1C").cgColor,
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        v.layer.insertSublayer(gradient, at: 0)
        v.layer.name = "gradient"
        return v
    }()

    // MARK: - Init
    init(device: TVDevice) {
        self.device = device
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCallbacks()
        service.delegate = self
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopVoiceControl()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let gradient = backgroundView.layer.sublayers?.first(where: { $0.name == "gradient" }) as? CAGradientLayer {
            gradient.frame = backgroundView.bounds
        }
    }

    // MARK: - Setup
    private func setupUI() {
        view.addSubview(backgroundView)
        backgroundView.pinToEdges(of: view)

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),
        ])

        [headerView, powerSection, voiceSection, volumeChannelSection, navSection,
         mediaSection, castSection, numpadSection, appsSection].forEach {
            contentStack.addArrangedSubview($0)
        }

        headerView.onBackTapped = { [weak self] in
            self?.service.disconnect()
            self?.navigationController?.popViewController(animated: true)
        }
    }

    private func setupCallbacks() {
        // Power
        powerSection.onCommand = { [weak self] cmd in self?.sendCommand(cmd) }

        voiceSection.onMicTapped = { [weak self] in
            self?.toggleVoiceControl()
        }

        // Volume / Channel
        volumeChannelSection.onCommand = { [weak self] cmd in self?.sendCommand(cmd) }

        // Navigation
        navSection.onCommand = { [weak self] cmd in self?.sendCommand(cmd) }

        // Media
        mediaSection.onCommand = { [weak self] cmd in self?.sendCommand(cmd) }

        // Numpad
        numpadSection.onCommand = { [weak self] cmd in self?.sendCommand(cmd) }

        // Apps
        appsSection.onCommand = { [weak self] cmd in self?.sendCommand(cmd) }

        // Source button in header
        headerView.onSourceTapped = { [weak self] in
            self?.sendCommand(.source)
        }

        castSection.onCastTapped = { [weak self] in
            guard let self else { return }
            let castVC = CastViewController(device: self.device)
            castVC.modalPresentationStyle = .fullScreen
            self.present(castVC, animated: true)
        }
    }

    // MARK: - Send Command
    private func sendCommand(_ command: RemoteCommand) {
        service.sendCommand(command)
    }

    // MARK: - Voice Control
    private func toggleVoiceControl() {
        isListeningForVoice ? stopVoiceControl() : requestVoicePermissionsAndStart()
    }

    private func requestVoicePermissionsAndStart() {
        SFSpeechRecognizer.requestAuthorization { [weak self] speechStatus in
            guard let self else { return }

            AVAudioSession.sharedInstance().requestRecordPermission { micAllowed in
                DispatchQueue.main.async {
                    guard speechStatus == .authorized, micAllowed else {
                        self.voiceSection.update(isListening: false,
                                                 text: "Cần quyền Microphone và Speech Recognition để điều khiển bằng giọng nói.")
                        return
                    }

                    self.startVoiceControl()
                }
            }
        }
    }

    private func startVoiceControl() {
        guard !audioEngine.isRunning else { return }
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            voiceSection.update(isListening: false,
                                text: "Nhận diện giọng nói tiếng Việt hiện chưa khả dụng trên thiết bị này.")
            return
        }

        recognitionTask?.cancel()
        recognitionTask = nil

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            voiceSection.update(isListening: false, text: "Không mở được microphone: \(error.localizedDescription)")
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            voiceSection.update(isListening: false, text: "Không bắt đầu nghe được: \(error.localizedDescription)")
            return
        }

        isListeningForVoice = true
        voiceSection.update(isListening: true, text: "Đang nghe...")

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let transcript = result?.bestTranscription.formattedString, !transcript.isEmpty {
                self.voiceSection.update(isListening: true, text: transcript)

                if let command = self.command(from: transcript) {
                    self.sendCommand(command)
                    self.stopVoiceControl(statusText: "Đã gửi lệnh: \(self.voiceLabel(for: command))")
                    return
                }
            }

            if error != nil || result?.isFinal == true {
                self.stopVoiceControl(statusText: "Không nhận ra lệnh phù hợp.")
            }
        }
    }

    private func stopVoiceControl(statusText: String? = nil) {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListeningForVoice = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        voiceSection.update(
            isListening: false,
            text: statusText ?? "Chạm mic rồi nói: tăng âm lượng, qua phải, OK..."
        )
    }

    private func command(from transcript: String) -> RemoteCommand? {
        let text = normalizedVoiceText(transcript)

        let commands: [(phrases: [String], command: RemoteCommand)] = [
            (["mo youtube", "youtube", "you tube", "open youtube"], .youtube),
            (["mo netflix", "netflix", "net flix", "open netflix"], .netflix),
            (["nguon vao", "dau vao", "source", "input"], .source),
            (["bat tv", "tat tv", "power", "nguon"], .power),
            (["tang am luong", "lon hon", "volume up", "vol up"], .volumeUp),
            (["giam am luong", "nho hon", "volume down", "vol down"], .volumeDown),
            (["tat tieng", "mute"], .mute),
            (["kenh tiep", "chuyen kenh len", "channel up"], .channelUp),
            (["kenh truoc", "chuyen kenh xuong", "channel down"], .channelDown),
            (["len", "up"], .up),
            (["xuong", "down"], .down),
            (["trai", "qua trai", "left"], .left),
            (["phai", "qua phai", "right"], .right),
            (["ok", "dong y", "chon", "enter"], .ok),
            (["quay lai", "tro lai", "back"], .back),
            (["home", "man hinh chinh"], .home),
            (["menu", "cai dat"], .menu),
            (["phat", "play"], .play),
            (["tam dung", "pause"], .pause),
            (["dung", "stop"], .stop)
        ]

        return commands.first { item in
            item.phrases.contains { phrase in text.contains(phrase) }
        }?.command
    }

    private func normalizedVoiceText(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func voiceLabel(for command: RemoteCommand) -> String {
        switch command {
        case .power: return "Power"
        case .volumeUp: return "Tăng âm lượng"
        case .volumeDown: return "Giảm âm lượng"
        case .mute: return "Tắt tiếng"
        case .channelUp: return "Kênh tiếp"
        case .channelDown: return "Kênh trước"
        case .up: return "Lên"
        case .down: return "Xuống"
        case .left: return "Trái"
        case .right: return "Phải"
        case .ok: return "OK"
        case .back: return "Quay lại"
        case .home: return "Home"
        case .menu: return "Menu"
        case .play: return "Play"
        case .pause: return "Pause"
        case .stop: return "Stop"
        case .youtube: return "YouTube"
        case .netflix: return "Netflix"
        case .source: return "Source"
        default: return command.rawValue
        }
    }
}

// MARK: - Service Delegate
extension RemoteViewController: TVRemoteServiceDelegate {
    func didDiscoverDevice(_ device: TVDevice) {}
    func didConnect(to device: TVDevice) {}

    func didDisconnect(from device: TVDevice) {
        DispatchQueue.main.async { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
    }

    func didFailToConnect(error: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.presentedViewController == nil else { return }

            let alert = UIAlertController(title: "Không gửi được lệnh",
                                          message: error,
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
    func didReceiveResponse(_ response: String) {}
    func didRequestPairingCode(for device: TVDevice) {}
}
