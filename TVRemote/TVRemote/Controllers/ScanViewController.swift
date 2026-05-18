import UIKit

class ScanViewController: UIViewController {

    // MARK: - Properties
    private var discoveredDevices: [TVDevice] = []
    private let service = TVRemoteService.shared

    // MARK: - UI Components
    private lazy var gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            Theme.Color.background.cgColor,
            UIColor(hex: "#0D0D1A").cgColor
        ]
        layer.startPoint = CGPoint(x: 0, y: 0)
        layer.endPoint = CGPoint(x: 1, y: 1)
        return layer
    }()

    private lazy var logoLabel: UILabel = {
        let label = UILabel()
        label.text = "TV Remote"
        label.font = Theme.Font.rounded(28, weight: .bold)
        label.textColor = Theme.Color.textPrimary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Tìm kiếm thiết bị trên mạng"
        label.font = Theme.Font.rounded(14, weight: .regular)
        label.textColor = Theme.Color.textSecondary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var scanAnimationView: ScanAnimationView = {
        let view = ScanAnimationView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var scanButton: GlowButton = {
        let btn = GlowButton()
        btn.setTitle("Bắt đầu quét", for: .normal)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(scanTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.backgroundColor = .clear
        tv.separatorStyle = .none
        tv.register(DeviceCell.self, forCellReuseIdentifier: DeviceCell.reuseID)
        tv.delegate = self
        tv.dataSource = self
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 20, right: 0)
        return tv
    }()

    private lazy var devicesLabel: UILabel = {
        let label = UILabel()
        label.text = "THIẾT BỊ TÌM THẤY"
        label.font = Theme.Font.rounded(11, weight: .semibold)
        label.textColor = Theme.Color.textTertiary
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()

    private lazy var manualConnectButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Kết nối thủ công (IP)", for: .normal)
        btn.titleLabel?.font = Theme.Font.rounded(14, weight: .medium)
        btn.setTitleColor(Theme.Color.accent, for: .normal)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(manualConnectTapped), for: .touchUpInside)
        return btn
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        service.delegate = self
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
    }

    // MARK: - Setup
    private func setupUI() {
        view.layer.insertSublayer(gradientLayer, at: 0)

        view.addSubview(logoLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(scanAnimationView)
        view.addSubview(scanButton)
        view.addSubview(devicesLabel)
        view.addSubview(tableView)
        view.addSubview(manualConnectButton)

        NSLayoutConstraint.activate([
            logoLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            logoLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: logoLabel.bottomAnchor, constant: 6),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            scanAnimationView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 40),
            scanAnimationView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scanAnimationView.widthAnchor.constraint(equalToConstant: 180),
            scanAnimationView.heightAnchor.constraint(equalToConstant: 180),

            scanButton.topAnchor.constraint(equalTo: scanAnimationView.bottomAnchor, constant: 32),
            scanButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scanButton.widthAnchor.constraint(equalToConstant: 200),
            scanButton.heightAnchor.constraint(equalToConstant: 50),

            devicesLabel.topAnchor.constraint(equalTo: scanButton.bottomAnchor, constant: 32),
            devicesLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),

            tableView.topAnchor.constraint(equalTo: devicesLabel.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: manualConnectButton.topAnchor, constant: -8),

            manualConnectButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            manualConnectButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    // MARK: - Actions
    @objc private func scanTapped() {
        HapticManager.impact(.medium)
        discoveredDevices.removeAll()
        tableView.reloadData()
        devicesLabel.isHidden = true

        scanAnimationView.startAnimating()
        scanButton.setTitle("Đang quét...", for: .normal)
        scanButton.isEnabled = false

        service.startScanning()

        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
            self?.stopScanUI()
        }
    }

    private func stopScanUI() {
        scanAnimationView.stopAnimating()
        scanButton.setTitle("Quét lại", for: .normal)
        scanButton.isEnabled = true
        service.stopScanning()
    }

    @objc private func manualConnectTapped() {
        HapticManager.impact(.light)

        let alert = UIAlertController(title: "Chọn hãng TV",
                                      message: nil,
                                      preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Samsung", style: .default) { [weak self] _ in
            self?.showManualConnectAlert(brand: .samsung)
        })
        alert.addAction(UIAlertAction(title: "Sony Bravia", style: .default) { [weak self] _ in
            self?.showManualConnectAlert(brand: .sony)
        })
        alert.addAction(UIAlertAction(title: "Android TV Box", style: .default) { [weak self] _ in
            self?.showManualConnectAlert(brand: .androidTV)
        })
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        present(alert, animated: true)
    }

    private func showManualConnectAlert(brand: TVBrand) {
        let defaultPort: Int
        let portLabel: String
        switch brand {
        case .sony:
            defaultPort = 80
            portLabel = "Port Sony (mặc định: 80)"
        case .androidTV:
            defaultPort = 6467
            portLabel = "Port Android TV pairing (mặc định: 6467)"
        default:
            defaultPort = 8001
            portLabel = "Port Samsung (mặc định: 8001)"
        }
        let alert = UIAlertController(title: "Kết nối \(brand.rawValue)",
                                      message: "Nhập địa chỉ IP của TV",
                                      preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "192.168.1.100"
            tf.keyboardType = .numbersAndPunctuation
        }
        alert.addTextField { tf in
            tf.placeholder = portLabel
            tf.keyboardType = .numberPad
        }
        if brand == .sony {
            alert.addTextField { tf in
                tf.placeholder = "Sony Pre-Shared Key (nếu có)"
                tf.autocapitalizationType = .none
                tf.autocorrectionType = .no
            }
        }
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        alert.addAction(UIAlertAction(title: "Kết nối", style: .default) { [weak self, weak alert] _ in
            let ip = alert?.textFields?[0].text ?? ""
            let portStr = alert?.textFields?[1].text ?? ""
            let port = Int(portStr) ?? defaultPort
            let authToken = brand == .sony ? alert?.textFields?[2].text : nil
            guard !ip.isEmpty else { return }
            let device = TVDevice(id: UUID().uuidString,
                                  name: "\(brand.rawValue) TV (\(ip))",
                                  ipAddress: ip,
                                  port: port,
                                  brand: brand,
                                  authToken: authToken?.isEmpty == false ? authToken : nil)
            self?.connectToDevice(device)
        })
        present(alert, animated: true)
    }

    private func connectToDevice(_ device: TVDevice) {
        let loadingVC = ConnectingViewController(device: device)
        loadingVC.modalPresentationStyle = .overFullScreen
        present(loadingVC, animated: true)
        service.delegate = loadingVC
        service.connect(to: device)
    }
}

// MARK: - TableView
extension ScanViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return discoveredDevices.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DeviceCell.reuseID, for: indexPath) as! DeviceCell
        cell.configure(with: discoveredDevices[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let device = discoveredDevices[indexPath.row]
        HapticManager.impact(.medium)
        connectToDevice(device)
    }
}

// MARK: - Service Delegate
extension ScanViewController: TVRemoteServiceDelegate {
    func didDiscoverDevice(_ device: TVDevice) {
        guard !discoveredDevices.contains(where: { $0.ipAddress == device.ipAddress }) else { return }
        discoveredDevices.append(device)
        devicesLabel.isHidden = false
        tableView.insertRows(at: [IndexPath(row: discoveredDevices.count - 1, section: 0)], with: .fade)
    }

    func didConnect(to device: TVDevice) {}
    func didDisconnect(from device: TVDevice) {}
    func didFailToConnect(error: String) {
        stopScanUI()
        let alert = UIAlertController(title: "Samsung TV",
                                      message: error,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    func didReceiveResponse(_ response: String) {}
    func didRequestPairingCode(for device: TVDevice) {}
}
