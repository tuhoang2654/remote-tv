import UIKit

class ConnectingViewController: UIViewController {

    private let device: TVDevice

    private lazy var blurView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        return UIVisualEffectView(effect: effect)
    }()

    private lazy var cardView: UIView = {
        let v = UIView()
        v.backgroundColor = Theme.Color.surfaceElevated
        v.layer.cornerRadius = Theme.Radius.xl
        v.layer.borderWidth = 1
        v.layer.borderColor = Theme.Color.border.cgColor
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var tvIconView: UIView = {
        let v = UIView()
        v.backgroundColor = Theme.Color.accent.withAlphaComponent(0.15)
        v.layer.cornerRadius = 30
        v.translatesAutoresizingMaskIntoConstraints = false
        let icon = UIImageView(image: UIImage(systemName: "tv.fill"))
        icon.tintColor = Theme.Color.accent
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: v.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 32),
            icon.heightAnchor.constraint(equalToConstant: 28),
        ])
        return v
    }()

    private lazy var titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Đang kết nối..."
        l.font = Theme.Font.rounded(20, weight: .bold)
        l.textColor = Theme.Color.textPrimary
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var deviceNameLabel: UILabel = {
        let l = UILabel()
        l.text = device.name
        l.font = Theme.Font.rounded(15, weight: .medium)
        l.textColor = Theme.Color.accent
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var ipLabel: UILabel = {
        let l = UILabel()
        l.text = "\(device.ipAddress):\(device.port)"
        l.font = Theme.Font.mono(13)
        l.textColor = Theme.Color.textSecondary
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .large)
        ai.color = Theme.Color.accent
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    private lazy var cancelButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Hủy", for: .normal)
        btn.titleLabel?.font = Theme.Font.rounded(16, weight: .medium)
        btn.setTitleColor(Theme.Color.textSecondary, for: .normal)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        return btn
    }()

    init(device: TVDevice) {
        self.device = device
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        activityIndicator.startAnimating()
    }

    private func setupUI() {
        blurView.frame = view.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(blurView)
        view.addSubview(cardView)

        [tvIconView, titleLabel, deviceNameLabel, ipLabel, activityIndicator, cancelButton].forEach {
            cardView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.widthAnchor.constraint(equalToConstant: 280),

            tvIconView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 32),
            tvIconView.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            tvIconView.widthAnchor.constraint(equalToConstant: 60),
            tvIconView.heightAnchor.constraint(equalToConstant: 60),

            titleLabel.topAnchor.constraint(equalTo: tvIconView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),

            deviceNameLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            deviceNameLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            deviceNameLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),

            ipLabel.topAnchor.constraint(equalTo: deviceNameLabel.bottomAnchor, constant: 4),
            ipLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            ipLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),

            activityIndicator.topAnchor.constraint(equalTo: ipLabel.bottomAnchor, constant: 24),
            activityIndicator.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),

            cancelButton.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 20),
            cancelButton.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -24),
        ])
    }

    @objc private func cancelTapped() {
        TVRemoteService.shared.delegate = nil
        dismiss(animated: true)
    }
}

// MARK: - Service Delegate
extension ConnectingViewController: TVRemoteServiceDelegate {
    func didDiscoverDevice(_ device: TVDevice) {}

    func didConnect(to device: TVDevice) {
        HapticManager.notification(.success)
        titleLabel.text = "Đã kết nối!"
        activityIndicator.stopAnimating()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.dismiss(animated: true) {
                let remoteVC = RemoteViewController(device: device)
                let nav = UINavigationController(rootViewController: remoteVC)
                nav.navigationBar.isHidden = true
                nav.modalPresentationStyle = .fullScreen

                // Navigate from scan VC
                if let scanVC = UIApplication.shared.windows.first?.rootViewController as? UINavigationController {
                    scanVC.pushViewController(remoteVC, animated: true)
                }
            }
        }
    }

    func didDisconnect(from device: TVDevice) {}

    func didFailToConnect(error: String) {
        HapticManager.notification(.error)

        // Stop any ongoing tasks and reset
        TVRemoteService.shared.disconnect()

        titleLabel.text = "Kết nối thất bại"
        activityIndicator.stopAnimating()

        // Hide device labels to reduce clutter
        deviceNameLabel.isHidden = true
        ipLabel.isHidden = true

        // Create a container for error message with better readability
        let errorContainer = UIView()
        errorContainer.backgroundColor = Theme.Color.surfaceElevated.withAlphaComponent(0.6)
        errorContainer.layer.cornerRadius = 10
        errorContainer.layer.borderWidth = 1
        errorContainer.layer.borderColor = Theme.Color.border.cgColor
        errorContainer.translatesAutoresizingMaskIntoConstraints = false

        let errorTitle = UILabel()
        errorTitle.text = "Không thể kết nối"
        errorTitle.font = Theme.Font.rounded(15, weight: .semibold)
        errorTitle.textColor = Theme.Color.textPrimary
        errorTitle.textAlignment = .center
        errorTitle.translatesAutoresizingMaskIntoConstraints = false

        let errorLabel = UILabel()
        errorLabel.text = error
        errorLabel.font = Theme.Font.rounded(13)
        errorLabel.textColor = Theme.Color.danger
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.lineBreakMode = .byWordWrapping
        errorLabel.translatesAutoresizingMaskIntoConstraints = false

        errorContainer.addSubview(errorTitle)
        errorContainer.addSubview(errorLabel)
        cardView.addSubview(errorContainer)

        NSLayoutConstraint.activate([
            errorContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            errorContainer.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            errorContainer.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),

            errorTitle.topAnchor.constraint(equalTo: errorContainer.topAnchor, constant: 12),
            errorTitle.leadingAnchor.constraint(equalTo: errorContainer.leadingAnchor, constant: 12),
            errorTitle.trailingAnchor.constraint(equalTo: errorContainer.trailingAnchor, constant: -12),

            errorLabel.topAnchor.constraint(equalTo: errorTitle.bottomAnchor, constant: 6),
            errorLabel.leadingAnchor.constraint(equalTo: errorContainer.leadingAnchor, constant: 12),
            errorLabel.trailingAnchor.constraint(equalTo: errorContainer.trailingAnchor, constant: -12),
            errorLabel.bottomAnchor.constraint(equalTo: errorContainer.bottomAnchor, constant: -12)
        ])

        // Ensure cancel button is visible for retry/exit
        cancelButton.setTitle("Đóng", for: .normal)
    }

    func didReceiveResponse(_ response: String) {}

    func didRequestPairingCode(for device: TVDevice) {
        activityIndicator.stopAnimating()
        titleLabel.text = "Nhập mã ghép đôi"

        let alert = UIAlertController(title: "Android TV Pairing",
                                      message: "Nhập mã 6 ký tự đang hiển thị trên màn hình TV/box.",
                                      preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "VD: A1B2C3"
            tf.autocapitalizationType = .allCharacters
            tf.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel) { _ in
            TVRemoteService.shared.disconnect()
        })
        alert.addAction(UIAlertAction(title: "Ghép đôi", style: .default) { [weak alert, weak self] _ in
            let code = alert?.textFields?.first?.text ?? ""
            self?.titleLabel.text = "Đang ghép đôi..."
            self?.activityIndicator.startAnimating()
            TVRemoteService.shared.submitAndroidTVPairingCode(code)
        })
        present(alert, animated: true)
    }
}
