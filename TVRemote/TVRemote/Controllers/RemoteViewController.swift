import UIKit

class RemoteViewController: UIViewController {

    // MARK: - Properties
    private let device: TVDevice
    private let service = TVRemoteService.shared

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
    private lazy var volumeChannelSection = VolumeChannelSectionView(frame: .zero)
    private lazy var navSection = NavigationSectionView(frame: .zero)
    private lazy var mediaSection = MediaSectionView(frame: .zero)
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

        [headerView, powerSection, volumeChannelSection, navSection,
         mediaSection, numpadSection, appsSection].forEach {
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
    }

    // MARK: - Send Command
    private func sendCommand(_ command: RemoteCommand) {
        service.sendCommand(command)
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

    func didFailToConnect(error: String) {}
    func didReceiveResponse(_ response: String) {}
    func didRequestPairingCode(for device: TVDevice) {}
}
