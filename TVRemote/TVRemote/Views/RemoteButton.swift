import UIKit

// MARK: - Remote Button Style
enum RemoteButtonStyle {
    case primary        // Accent color fill
    case secondary      // Surface fill
    case danger         // Red
    case ghost          // Transparent border only
    case icon           // Icon only circle
}

// MARK: - Remote Button
class RemoteButton: UIControl {

    var command: RemoteCommand?
    var onTap: ((RemoteCommand) -> Void)?

    private let style: RemoteButtonStyle
    private let iconName: String?
    private let labelText: String?

    private lazy var iconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private lazy var label: UILabel = {
        let l = UILabel()
        l.font = Theme.Font.rounded(13, weight: .semibold)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Init
    init(icon: String? = nil, text: String? = nil, command: RemoteCommand? = nil,
         style: RemoteButtonStyle = .secondary) {
        self.iconName = icon
        self.labelText = text
        self.command = command
        self.style = style
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup
    private func setup() {
        layer.cornerRadius = Theme.Radius.md
        clipsToBounds = false

        applyStyle()

        if let icon = iconName {
            let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
            iconView.image = UIImage(systemName: icon, withConfiguration: config)
            addSubview(iconView)
            NSLayoutConstraint.activate([
                iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
                iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
                iconView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -16),
                iconView.heightAnchor.constraint(lessThanOrEqualToConstant: 28),
            ])
        } else if let text = labelText {
            label.text = text
            addSubview(label)
            label.pinToEdges(of: self, insets: UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4))
        }

        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        addTarget(self, action: #selector(touchDown), for: .touchDown)
        addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    private func applyStyle() {
        switch style {
        case .primary:
            backgroundColor = Theme.Color.accent
            iconView.tintColor = .white
            label.textColor = .white
            addGlow(color: Theme.Color.accent, radius: 10, opacity: 0.5)

        case .secondary:
            backgroundColor = Theme.Color.surfaceElevated
            layer.borderWidth = 1
            layer.borderColor = Theme.Color.border.cgColor
            iconView.tintColor = Theme.Color.textPrimary
            label.textColor = Theme.Color.textPrimary

        case .danger:
            backgroundColor = Theme.Color.powerRed.withAlphaComponent(0.15)
            layer.borderWidth = 1
            layer.borderColor = Theme.Color.powerRed.withAlphaComponent(0.4).cgColor
            iconView.tintColor = Theme.Color.powerRed
            label.textColor = Theme.Color.powerRed
            addGlow(color: Theme.Color.powerRed, radius: 8, opacity: 0.3)

        case .ghost:
            backgroundColor = .clear
            layer.borderWidth = 1.5
            layer.borderColor = Theme.Color.border.cgColor
            iconView.tintColor = Theme.Color.textSecondary
            label.textColor = Theme.Color.textSecondary

        case .icon:
            backgroundColor = Theme.Color.surfaceElevated
            layer.cornerRadius = Theme.Radius.circle
            layer.borderWidth = 1
            layer.borderColor = Theme.Color.border.cgColor
            iconView.tintColor = Theme.Color.textPrimary
        }
    }

    // MARK: - Interactions
    @objc private func handleTap() {
        HapticManager.impact(.light)
        if let cmd = command {
            onTap?(cmd)
        }
    }

    @objc private func touchDown() {
        UIView.animate(withDuration: 0.1) {
            self.transform = CGAffineTransform(scaleX: 0.93, y: 0.93)
            self.alpha = 0.85
        }
    }

    @objc private func touchUp() {
        UIView.animate(withDuration: 0.18, delay: 0,
                       usingSpringWithDamping: 0.6, initialSpringVelocity: 0.3,
                       options: []) {
            self.transform = .identity
            self.alpha = 1.0
        }
    }
}

// MARK: - Glow Button (CTA style)
class GlowButton: UIButton {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = Theme.Color.accent
        layer.cornerRadius = 14
        titleLabel?.font = Theme.Font.rounded(16, weight: .semibold)
        setTitleColor(.white, for: .normal)
        addGlow(color: Theme.Color.accent, radius: 14, opacity: 0.6)

        addTarget(self, action: #selector(down), for: .touchDown)
        addTarget(self, action: #selector(up), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    @objc private func down() {
        UIView.animate(withDuration: 0.1) { self.transform = CGAffineTransform(scaleX: 0.96, y: 0.96) }
    }
    @objc private func up() {
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: []) {
            self.transform = .identity
        }
    }
}
