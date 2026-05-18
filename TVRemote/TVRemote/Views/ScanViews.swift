import UIKit

// MARK: - Scan Animation View
class ScanAnimationView: UIView {

    private var rings: [UIView] = []
    private var isAnimating = false

    private lazy var tvIcon: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 36, weight: .medium)
        let iv = UIImageView(image: UIImage(systemName: "tv.fill", withConfiguration: config))
        iv.tintColor = Theme.Color.accent
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private lazy var centerDot: UIView = {
        let v = UIView()
        v.backgroundColor = Theme.Color.accent
        v.layer.cornerRadius = 6
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        backgroundColor = .clear

        // Create rings
        let ringCount = 3
        for i in 0..<ringCount {
            let ring = UIView()
            ring.backgroundColor = .clear
            ring.layer.borderWidth = 1.5
            ring.layer.borderColor = Theme.Color.accent.withAlphaComponent(0.6 - Double(i) * 0.15).cgColor
            ring.translatesAutoresizingMaskIntoConstraints = false
            insertSubview(ring, at: 0)
            rings.append(ring)
        }

        addSubview(tvIcon)
        addSubview(centerDot)

        NSLayoutConstraint.activate([
            tvIcon.centerXAnchor.constraint(equalTo: centerXAnchor),
            tvIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
            tvIcon.widthAnchor.constraint(equalToConstant: 50),
            tvIcon.heightAnchor.constraint(equalToConstant: 44),

            centerDot.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerDot.centerYAnchor.constraint(equalTo: centerYAnchor),
            centerDot.widthAnchor.constraint(equalToConstant: 12),
            centerDot.heightAnchor.constraint(equalToConstant: 12),
        ])

        tvIcon.addGlow(color: Theme.Color.accent, radius: 16, opacity: 0.6)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let sizes: [CGFloat] = [60, 100, 150]
        for (i, ring) in rings.enumerated() {
            let size = sizes[i]
            ring.frame = CGRect(x: (bounds.width - size) / 2,
                                y: (bounds.height - size) / 2,
                                width: size, height: size)
            ring.layer.cornerRadius = size / 2
        }
    }

    func startAnimating() {
        guard !isAnimating else { return }
        isAnimating = true

        for (i, ring) in rings.enumerated() {
            let delay = Double(i) * 0.4
            animateRing(ring, delay: delay)
        }

        // Pulse the TV icon
        UIView.animate(withDuration: 0.8, delay: 0,
                       options: [.autoreverse, .repeat, .curveEaseInOut]) {
            self.tvIcon.transform = CGAffineTransform(scaleX: 1.08, y: 1.08)
        }
    }

    func stopAnimating() {
        isAnimating = false
        rings.forEach { $0.layer.removeAllAnimations() }
        tvIcon.layer.removeAllAnimations()
        tvIcon.transform = .identity
        rings.forEach { $0.alpha = 1.0; $0.transform = .identity }
    }

    private func animateRing(_ ring: UIView, delay: Double) {
        ring.alpha = 0.8
        ring.transform = .identity

        UIView.animate(withDuration: 1.6, delay: delay,
                       options: [.repeat, .curveEaseOut]) {
            ring.transform = CGAffineTransform(scaleX: 1.4, y: 1.4)
            ring.alpha = 0
        }
    }
}

// MARK: - Device Cell
class DeviceCell: UITableViewCell {
    static let reuseID = "DeviceCell"

    private lazy var cardView: UIView = {
        let v = UIView()
        v.backgroundColor = Theme.Color.surface
        v.layer.cornerRadius = Theme.Radius.md
        v.layer.borderWidth = 1
        v.layer.borderColor = Theme.Color.border.cgColor
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var iconContainer: UIView = {
        let v = UIView()
        v.backgroundColor = Theme.Color.accent.withAlphaComponent(0.15)
        v.layer.cornerRadius = 10
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var tvIcon: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let iv = UIImageView(image: UIImage(systemName: "tv.fill", withConfiguration: config))
        iv.tintColor = Theme.Color.accent
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private lazy var nameLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Font.rounded(16, weight: .semibold)
        l.textColor = Theme.Color.textPrimary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var ipLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Font.mono(12)
        l.textColor = Theme.Color.textSecondary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var brandLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Font.rounded(11, weight: .medium)
        l.textColor = Theme.Color.textTertiary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var chevron: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        let iv = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: config))
        iv.tintColor = Theme.Color.textTertiary
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(cardView)
        iconContainer.addSubview(tvIcon)
        [iconContainer, nameLabel, ipLabel, brandLabel, chevron].forEach { cardView.addSubview($0) }

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            iconContainer.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            iconContainer.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 44),
            iconContainer.heightAnchor.constraint(equalToConstant: 44),

            tvIcon.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            tvIcon.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            tvIcon.widthAnchor.constraint(equalToConstant: 24),
            tvIcon.heightAnchor.constraint(equalToConstant: 22),

            nameLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            nameLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),

            ipLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            ipLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),

            brandLabel.topAnchor.constraint(equalTo: ipLabel.bottomAnchor, constant: 2),
            brandLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),

            chevron.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            chevron.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
        ])
    }

    func configure(with device: TVDevice) {
        nameLabel.text = device.name
        ipLabel.text = "\(device.ipAddress):\(device.port)"
        brandLabel.text = device.brand.rawValue
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        UIView.animate(withDuration: 0.12) {
            self.cardView.backgroundColor = highlighted ? Theme.Color.surfaceElevated : Theme.Color.surface
            self.cardView.transform = highlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
        }
    }
}
