import AVKit
import PhotosUI
import UIKit
import UniformTypeIdentifiers

final class CastViewController: UIViewController {

    private let device: TVDevice

    private lazy var gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            Theme.Color.background.cgColor,
            UIColor(hex: "#10101C").cgColor
        ]
        layer.startPoint = CGPoint(x: 0, y: 0)
        layer.endPoint = CGPoint(x: 1, y: 1)
        return layer
    }()

    private lazy var headerLabel: UILabel = {
        let label = UILabel()
        label.text = "Cast"
        label.font = Theme.Font.rounded(24, weight: .bold)
        label.textColor = Theme.Color.textPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var deviceLabel: UILabel = {
        let label = UILabel()
        label.text = device.name
        label.font = Theme.Font.rounded(13, weight: .medium)
        label.textColor = Theme.Color.textSecondary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = Theme.Color.textSecondary
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        return button
    }()

    private lazy var routePicker: AVRoutePickerView = {
        let picker = AVRoutePickerView()
        picker.tintColor = Theme.Color.textPrimary
        picker.activeTintColor = Theme.Color.success
        picker.prioritizesVideoDevices = true
        picker.translatesAutoresizingMaskIntoConstraints = false
        return picker
    }()

    private lazy var screenMirrorButton = makeActionButton(
        title: "Screen Mirroring",
        subtitle: "Chọn TV/AirPlay trong bảng hệ thống",
        icon: "rectangle.on.rectangle"
    )

    private lazy var mediaButton = makeActionButton(
        title: "Photo & Video Cast",
        subtitle: "Chọn ảnh hoặc video từ thư viện",
        icon: "photo.on.rectangle.angled"
    )

    private lazy var noteLabel: UILabel = {
        let label = UILabel()
        label.text = "Video sẽ phát qua AirPlay route đang chọn. Ảnh sẽ mở toàn màn hình để mirror lên TV."
        label.font = Theme.Font.rounded(12)
        label.textColor = Theme.Color.textTertiary
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    init(device: TVDevice) {
        self.device = device
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
    }

    private func setupUI() {
        view.layer.insertSublayer(gradientLayer, at: 0)

        let titleStack = UIStackView(arrangedSubviews: [headerLabel, deviceLabel])
        titleStack.axis = .vertical
        titleStack.spacing = 4
        titleStack.translatesAutoresizingMaskIntoConstraints = false

        let routeCard = UIView()
        routeCard.backgroundColor = Theme.Color.surface
        routeCard.layer.cornerRadius = Theme.Radius.lg
        routeCard.layer.borderWidth = 1
        routeCard.layer.borderColor = Theme.Color.border.cgColor
        routeCard.translatesAutoresizingMaskIntoConstraints = false

        let routeTitle = UILabel()
        routeTitle.text = "AirPlay"
        routeTitle.font = Theme.Font.rounded(16, weight: .semibold)
        routeTitle.textColor = Theme.Color.textPrimary
        routeTitle.translatesAutoresizingMaskIntoConstraints = false

        let routeSubtitle = UILabel()
        routeSubtitle.text = "Chọn thiết bị phát"
        routeSubtitle.font = Theme.Font.rounded(12)
        routeSubtitle.textColor = Theme.Color.textSecondary
        routeSubtitle.translatesAutoresizingMaskIntoConstraints = false

        let routeTextStack = UIStackView(arrangedSubviews: [routeTitle, routeSubtitle])
        routeTextStack.axis = .vertical
        routeTextStack.spacing = 3
        routeTextStack.translatesAutoresizingMaskIntoConstraints = false

        routeCard.addSubview(routeTextStack)
        routeCard.addSubview(routePicker)

        let actionStack = UIStackView(arrangedSubviews: [routeCard, screenMirrorButton, mediaButton, noteLabel])
        actionStack.axis = .vertical
        actionStack.spacing = 14
        actionStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(titleStack)
        view.addSubview(closeButton)
        view.addSubview(actionStack)

        NSLayoutConstraint.activate([
            titleStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 22),
            titleStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleStack.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -16),

            closeButton.centerYAnchor.constraint(equalTo: titleStack.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),

            actionStack.topAnchor.constraint(equalTo: titleStack.bottomAnchor, constant: 28),
            actionStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            actionStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            routeCard.heightAnchor.constraint(equalToConstant: 76),
            routeTextStack.leadingAnchor.constraint(equalTo: routeCard.leadingAnchor, constant: 18),
            routeTextStack.centerYAnchor.constraint(equalTo: routeCard.centerYAnchor),
            routeTextStack.trailingAnchor.constraint(lessThanOrEqualTo: routePicker.leadingAnchor, constant: -12),

            routePicker.trailingAnchor.constraint(equalTo: routeCard.trailingAnchor, constant: -18),
            routePicker.centerYAnchor.constraint(equalTo: routeCard.centerYAnchor),
            routePicker.widthAnchor.constraint(equalToConstant: 46),
            routePicker.heightAnchor.constraint(equalToConstant: 46),
        ])

        screenMirrorButton.addTarget(self, action: #selector(screenMirrorTapped), for: .touchUpInside)
        mediaButton.addTarget(self, action: #selector(mediaTapped), for: .touchUpInside)
    }

    private func makeActionButton(title: String, subtitle: String, icon: String) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = Theme.Color.surfaceElevated
        config.baseForegroundColor = Theme.Color.textPrimary
        config.cornerStyle = .medium
        config.image = UIImage(systemName: icon)
        config.imagePadding = 12
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        config.title = title
        config.subtitle = subtitle
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = Theme.Font.rounded(16, weight: .semibold)
            return outgoing
        }
        config.subtitleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = Theme.Font.rounded(12)
            outgoing.foregroundColor = Theme.Color.textSecondary
            return outgoing
        }

        let button = UIButton(configuration: config)
        button.contentHorizontalAlignment = .leading
        button.layer.borderWidth = 1
        button.layer.borderColor = Theme.Color.border.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 74).isActive = true
        return button
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func screenMirrorTapped() {
        HapticManager.impact(.light)
        openRoutePicker()
    }

    @objc private func mediaTapped() {
        HapticManager.impact(.light)
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .any(of: [.images, .videos])
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func openRoutePicker() {
        for subview in routePicker.subviews {
            if let button = subview as? UIButton {
                button.sendActions(for: .touchUpInside)
                return
            }
        }
    }

    private func playVideo(from url: URL) {
        let player = AVPlayer(url: url)
        let playerVC = AVPlayerViewController()
        playerVC.player = player
        playerVC.allowsPictureInPicturePlayback = true
        present(playerVC, animated: true) {
            player.play()
        }
    }

    private func showImage(_ image: UIImage) {
        let imageVC = CastImageViewController(image: image)
        imageVC.modalPresentationStyle = .fullScreen
        present(imageVC, animated: true)
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Không thể cast", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension CastViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let provider = results.first?.itemProvider else { return }

        if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] url, error in
                guard let self else { return }

                if let error {
                    DispatchQueue.main.async { self.showError(error.localizedDescription) }
                    return
                }

                guard let url else {
                    DispatchQueue.main.async { self.showError("Không đọc được video đã chọn.") }
                    return
                }

                let targetURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(url.pathExtension.isEmpty ? "mov" : url.pathExtension)

                do {
                    if FileManager.default.fileExists(atPath: targetURL.path) {
                        try FileManager.default.removeItem(at: targetURL)
                    }
                    try FileManager.default.copyItem(at: url, to: targetURL)
                    DispatchQueue.main.async { self.playVideo(from: targetURL) }
                } catch {
                    DispatchQueue.main.async { self.showError(error.localizedDescription) }
                }
            }
            return
        }

        if provider.canLoadObject(ofClass: UIImage.self) {
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                guard let self else { return }

                if let error {
                    DispatchQueue.main.async { self.showError(error.localizedDescription) }
                    return
                }

                guard let image = object as? UIImage else {
                    DispatchQueue.main.async { self.showError("Không đọc được ảnh đã chọn.") }
                    return
                }

                DispatchQueue.main.async { self.showImage(image) }
            }
        }
    }
}

private final class CastImageViewController: UIViewController {
    private let image: UIImage

    init(image: UIImage) {
        self.image = image
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)

        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .white
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}
