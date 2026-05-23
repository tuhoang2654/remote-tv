import UIKit

// MARK: - Base Card View
class CardSectionView: UIView {
    init() {
        super.init(frame: .zero)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = Theme.Color.surface
        layer.cornerRadius = Theme.Radius.lg
        layer.borderWidth = 1
        layer.borderColor = Theme.Color.border.cgColor
        translatesAutoresizingMaskIntoConstraints = false
    }
}

// MARK: - Remote Header View
class RemoteHeaderView: UIView {
    var onBackTapped: (() -> Void)?
    var onSourceTapped: (() -> Void)?

    private let device: TVDevice

    private lazy var backButton: UIButton = {
        let btn = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        btn.setImage(UIImage(systemName: "chevron.left", withConfiguration: config), for: .normal)
        btn.tintColor = Theme.Color.textSecondary
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var tvNameLabel: UILabel = {
        let l = UILabel()
        l.text = device.name
        l.font = Theme.Font.rounded(17, weight: .bold)
        l.textColor = Theme.Color.textPrimary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var statusDot: UIView = {
        let v = UIView()
        v.backgroundColor = Theme.Color.success
        v.layer.cornerRadius = 4
        v.translatesAutoresizingMaskIntoConstraints = false
        v.addGlow(color: Theme.Color.success, radius: 6, opacity: 0.8)
        return v
    }()

    private lazy var ipLabel: UILabel = {
        let l = UILabel()
        l.text = device.ipAddress
        l.font = Theme.Font.mono(12)
        l.textColor = Theme.Color.textTertiary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var sourceButton: RemoteButton = {
        let btn = RemoteButton(icon: "rectangle.on.rectangle", command: .source, style: .ghost)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.onTap = { [weak self] _ in self?.onSourceTapped?() }
        return btn
    }()

    init(device: TVDevice) {
        self.device = device
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        let titleStack = UIStackView(arrangedSubviews: [tvNameLabel])
        titleStack.axis = .vertical
        titleStack.spacing = 2

        let statusStack = UIStackView(arrangedSubviews: [statusDot, ipLabel])
        statusStack.axis = .horizontal
        statusStack.spacing = 6
        statusStack.alignment = .center
        titleStack.addArrangedSubview(statusStack)

        [backButton, titleStack, sourceButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            backButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 36),
            backButton.heightAnchor.constraint(equalToConstant: 44),

            titleStack.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 8),
            titleStack.centerYAnchor.constraint(equalTo: centerYAnchor),

            sourceButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            sourceButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            sourceButton.widthAnchor.constraint(equalToConstant: 44),
            sourceButton.heightAnchor.constraint(equalToConstant: 36),

            statusDot.widthAnchor.constraint(equalToConstant: 8),
            statusDot.heightAnchor.constraint(equalToConstant: 8),

            heightAnchor.constraint(equalToConstant: 60),
        ])
    }

    @objc private func backTapped() {
        HapticManager.impact(.light)
        onBackTapped?()
    }
}

// MARK: - Power Section
class PowerSectionView: CardSectionView {
    var onCommand: ((RemoteCommand) -> Void)?

    private lazy var powerBtn: RemoteButton = {
        let btn = RemoteButton(icon: "power", command: .power, style: .danger)
        btn.onTap = { [weak self] cmd in self?.onCommand?(cmd) }
        return btn
    }()

    private lazy var inputBtn: RemoteButton = {
        let btn = RemoteButton(icon: "rectangle.3.group.fill", command: .source, style: .secondary)
        btn.onTap = { [weak self] cmd in self?.onCommand?(cmd) }
        return btn
    }()

    private lazy var settingsBtn: RemoteButton = {
        let btn = RemoteButton(icon: "gearshape.fill", command: .menu, style: .secondary)
        btn.onTap = { [weak self] cmd in self?.onCommand?(cmd) }
        return btn
    }()

    private lazy var powerLabel: UILabel = {
        let l = UILabel()
        l.text = "Power"
        l.font = Theme.Font.rounded(10, weight: .medium)
        l.textColor = Theme.Color.powerRed
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    private func setupUI() {
        let stack = UIStackView(arrangedSubviews: [powerBtn, inputBtn, settingsBtn])
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            stack.heightAnchor.constraint(equalToConstant: 52),
        ])
    }
}

// MARK: - Voice Control Section
class VoiceControlSectionView: CardSectionView {
    var onMicTapped: (() -> Void)?

    private lazy var micButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = Theme.Color.accent
        button.layer.cornerRadius = 24
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(micTapped), for: .touchUpInside)
        return button
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Voice Control"
        label.font = Theme.Font.rounded(15, weight: .semibold)
        label.textColor = Theme.Color.textPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Chạm mic rồi nói: tăng âm lượng, qua phải, OK..."
        label.font = Theme.Font.rounded(12)
        label.textColor = Theme.Color.textSecondary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    private func setupUI() {
        let textStack = UIStackView(arrangedSubviews: [titleLabel, statusLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(micButton)
        addSubview(textStack)

        NSLayoutConstraint.activate([
            micButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            micButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            micButton.widthAnchor.constraint(equalToConstant: 48),
            micButton.heightAnchor.constraint(equalToConstant: 48),

            textStack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            textStack.leadingAnchor.constraint(equalTo: micButton.trailingAnchor, constant: 14),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            textStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
        ])
    }

    func update(isListening: Bool, text: String) {
        statusLabel.text = text
        micButton.backgroundColor = isListening ? Theme.Color.danger : Theme.Color.accent
        micButton.setImage(UIImage(systemName: isListening ? "stop.fill" : "mic.fill"), for: .normal)
        if isListening {
            micButton.addGlow(color: Theme.Color.danger, radius: 10, opacity: 0.45)
        } else {
            micButton.removeGlow()
        }
    }

    @objc private func micTapped() {
        HapticManager.impact(.light)
        onMicTapped?()
    }
}

// MARK: - Volume & Channel Section
class VolumeChannelSectionView: CardSectionView {
    var onCommand: ((RemoteCommand) -> Void)?

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    private func makeBtn(_ icon: String, cmd: RemoteCommand, style: RemoteButtonStyle = .secondary) -> RemoteButton {
        let btn = RemoteButton(icon: icon, command: cmd, style: style)
        btn.onTap = { [weak self] c in self?.onCommand?(c) }
        return btn
    }

    private func makeLabel(_ text: String, color: UIColor = Theme.Color.textTertiary) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = Theme.Font.rounded(10, weight: .semibold)
        l.textColor = color
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    private func setupUI() {
        let volUp = makeBtn("speaker.wave.3.fill", cmd: .volumeUp, style: .primary)
        let volDown = makeBtn("speaker.wave.1.fill", cmd: .volumeDown)
        let mute = makeBtn("speaker.slash.fill", cmd: .mute, style: .ghost)

        let chUp = makeBtn("chevron.up.circle.fill", cmd: .channelUp)
        let chDown = makeBtn("chevron.down.circle.fill", cmd: .channelDown)

        let volLabel = makeLabel("VOL", color: Theme.Color.accentLight)
        let chLabel = makeLabel("CH", color: Theme.Color.textTertiary)

        // Volume column
        let volStack = UIStackView(arrangedSubviews: [volLabel, volUp, mute, volDown])
        volStack.axis = .vertical
        volStack.spacing = 8

        // Divider
        let divider = UIView()
        divider.backgroundColor = Theme.Color.border
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.widthAnchor.constraint(equalToConstant: 1).isActive = true

        // Channel column
        let chStack = UIStackView(arrangedSubviews: [chLabel, chUp, chDown])
        chStack.axis = .vertical
        chStack.spacing = 8

        let mainStack = UIStackView(arrangedSubviews: [volStack, divider, chStack])
        mainStack.axis = .horizontal
        mainStack.spacing = 16
        mainStack.alignment = .center
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),

            volUp.heightAnchor.constraint(equalToConstant: 48),
            volDown.heightAnchor.constraint(equalToConstant: 48),
            mute.heightAnchor.constraint(equalToConstant: 40),
            chUp.heightAnchor.constraint(equalToConstant: 48),
            chDown.heightAnchor.constraint(equalToConstant: 48),

            divider.heightAnchor.constraint(equalToConstant: 120),
            volStack.widthAnchor.constraint(equalTo: chStack.widthAnchor),
        ])
    }
}

// MARK: - Navigation Section (D-Pad)
class NavigationSectionView: CardSectionView {
    var onCommand: ((RemoteCommand) -> Void)?

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    private func makeNavBtn(_ icon: String, cmd: RemoteCommand) -> RemoteButton {
        let btn = RemoteButton(icon: icon, command: cmd, style: .secondary)
        btn.onTap = { [weak self] c in self?.onCommand?(c) }
        return btn
    }

    private func setupUI() {
        let up = makeNavBtn("chevron.up", cmd: .up)
        let down = makeNavBtn("chevron.down", cmd: .down)
        let left = makeNavBtn("chevron.left", cmd: .left)
        let right = makeNavBtn("chevron.right", cmd: .right)

        let okBtn = RemoteButton(text: "OK", command: .ok, style: .primary)
        okBtn.onTap = { [weak self] c in self?.onCommand?(c) }

        let backBtn = RemoteButton(icon: "arrow.uturn.left", command: .back, style: .ghost)
        backBtn.onTap = { [weak self] c in self?.onCommand?(c) }

        let homeBtn = RemoteButton(icon: "house.fill", command: .home, style: .secondary)
        homeBtn.onTap = { [weak self] c in self?.onCommand?(c) }

        // D-Pad layout using grid
        let dpad = DPadView(up: up, down: down, left: left, right: right, center: okBtn)

        let bottomRow = UIStackView(arrangedSubviews: [backBtn, homeBtn])
        bottomRow.axis = .horizontal
        bottomRow.distribution = .fillEqually
        bottomRow.spacing = 12

        let stack = UIStackView(arrangedSubviews: [dpad, bottomRow])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),

            dpad.heightAnchor.constraint(equalToConstant: 160),
            bottomRow.heightAnchor.constraint(equalToConstant: 48),
        ])
    }
}

// MARK: - D-Pad Custom View
class DPadView: UIView {
    init(up: RemoteButton, down: RemoteButton, left: RemoteButton, right: RemoteButton, center: RemoteButton) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        [up, down, left, right, center].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        let btnSize: CGFloat = 50

        NSLayoutConstraint.activate([
            // Up
            up.topAnchor.constraint(equalTo: topAnchor),
            up.centerXAnchor.constraint(equalTo: centerXAnchor),
            up.widthAnchor.constraint(equalToConstant: btnSize),
            up.heightAnchor.constraint(equalToConstant: btnSize),

            // Down
            down.bottomAnchor.constraint(equalTo: bottomAnchor),
            down.centerXAnchor.constraint(equalTo: centerXAnchor),
            down.widthAnchor.constraint(equalToConstant: btnSize),
            down.heightAnchor.constraint(equalToConstant: btnSize),

            // Left
            left.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            left.centerYAnchor.constraint(equalTo: centerYAnchor),
            left.widthAnchor.constraint(equalToConstant: btnSize),
            left.heightAnchor.constraint(equalToConstant: btnSize),

            // Right
            right.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            right.centerYAnchor.constraint(equalTo: centerYAnchor),
            right.widthAnchor.constraint(equalToConstant: btnSize),
            right.heightAnchor.constraint(equalToConstant: btnSize),

            // Center OK
            center.centerXAnchor.constraint(equalTo: centerXAnchor),
            center.centerYAnchor.constraint(equalTo: centerYAnchor),
            center.widthAnchor.constraint(equalToConstant: 62),
            center.heightAnchor.constraint(equalToConstant: 62),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Media Section
class MediaSectionView: CardSectionView {
    var onCommand: ((RemoteCommand) -> Void)?

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    private func makeBtn(_ icon: String, cmd: RemoteCommand) -> RemoteButton {
        let btn = RemoteButton(icon: icon, command: cmd, style: .secondary)
        btn.onTap = { [weak self] c in self?.onCommand?(c) }
        return btn
    }

    private func setupUI() {
        let label = makeLabel("MEDIA")

        let rewind = makeBtn("backward.fill", cmd: .rewind)
        let play = RemoteButton(icon: "play.fill", command: .play, style: .primary)
        play.onTap = { [weak self] c in self?.onCommand?(c) }
        let pause = makeBtn("pause.fill", cmd: .pause)
        let stop = makeBtn("stop.fill", cmd: .stop)
        let ff = makeBtn("forward.fill", cmd: .fastForward)

        let rec = RemoteButton(icon: "record.circle.fill", command: .record, style: .danger)
        rec.onTap = { [weak self] c in self?.onCommand?(c) }

        let btnRow = UIStackView(arrangedSubviews: [rewind, play, pause, stop, ff, rec])
        btnRow.axis = .horizontal
        btnRow.distribution = .fillEqually
        btnRow.spacing = 8

        let stack = UIStackView(arrangedSubviews: [label, btnRow])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            btnRow.heightAnchor.constraint(equalToConstant: 48),
        ])
    }

    private func makeLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = Theme.Font.rounded(11, weight: .semibold)
        l.textColor = Theme.Color.textTertiary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }
}

// MARK: - Cast Section
class CastSectionView: CardSectionView {
    var onCastTapped: (() -> Void)?

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    private func setupUI() {
        let iconView = UIView()
        iconView.backgroundColor = Theme.Color.accent.withAlphaComponent(0.16)
        iconView.layer.cornerRadius = Theme.Radius.md
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: "airplayvideo"))
        icon.tintColor = Theme.Color.accentLight
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconView.addSubview(icon)

        let titleLabel = UILabel()
        titleLabel.text = "Screen Mirroring"
        titleLabel.font = Theme.Font.rounded(15, weight: .semibold)
        titleLabel.textColor = Theme.Color.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Photo & Video Cast"
        subtitleLabel.font = Theme.Font.rounded(12, weight: .medium)
        subtitleLabel.textColor = Theme.Color.textSecondary
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 3
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = Theme.Color.textTertiary
        chevron.translatesAutoresizingMaskIntoConstraints = false

        let button = UIControl()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(castTapped), for: .touchUpInside)

        [iconView, textStack, chevron, button].forEach { addSubview($0) }

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            iconView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            iconView.widthAnchor.constraint(equalToConstant: 50),
            iconView.heightAnchor.constraint(equalToConstant: 50),

            icon.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 26),
            icon.heightAnchor.constraint(equalToConstant: 24),

            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 14),
            textStack.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -12),

            chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 12),
            chevron.heightAnchor.constraint(equalToConstant: 20),

            button.topAnchor.constraint(equalTo: topAnchor),
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @objc private func castTapped() {
        HapticManager.impact(.light)
        onCastTapped?()
    }
}

// MARK: - Numpad Section
class NumpadSectionView: CardSectionView {
    var onCommand: ((RemoteCommand) -> Void)?

    private let numCommands: [(String, RemoteCommand)] = [
        ("1", .num1), ("2", .num2), ("3", .num3),
        ("4", .num4), ("5", .num5), ("6", .num6),
        ("7", .num7), ("8", .num8), ("9", .num9),
        ("⊙", .source), ("0", .num0), ("⌫", .back)
    ]

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    private func setupUI() {
        let label = UILabel()
        label.text = "BÀN PHÍM SỐ"
        label.font = Theme.Font.rounded(11, weight: .semibold)
        label.textColor = Theme.Color.textTertiary
        label.translatesAutoresizingMaskIntoConstraints = false

        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 8
        grid.translatesAutoresizingMaskIntoConstraints = false

        for row in 0..<4 {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.distribution = .fillEqually
            rowStack.spacing = 8

            for col in 0..<3 {
                let idx = row * 3 + col
                let (text, cmd) = numCommands[idx]
                let btn = RemoteButton(text: text, command: cmd, style: .secondary)
                btn.onTap = { [weak self] c in self?.onCommand?(c) }
                rowStack.addArrangedSubview(btn)
                btn.heightAnchor.constraint(equalToConstant: 48).isActive = true
            }
            grid.addArrangedSubview(rowStack)
        }

        let stack = UIStackView(arrangedSubviews: [label, grid])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
        ])
    }
}

// MARK: - App Shortcuts Section
class AppShortcutsSectionView: CardSectionView {
    var onCommand: ((RemoteCommand) -> Void)?

    private let apps: [(String, String, RemoteCommand)] = [
        ("N", "#E50914", .netflix),
        ("▶", "#FF0000", .youtube),
        ("⋯", "#6C63FF", .home),
    ]

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    private func setupUI() {
        let label = UILabel()
        label.text = "ỨNG DỤNG NHANH"
        label.font = Theme.Font.rounded(11, weight: .semibold)
        label.textColor = Theme.Color.textTertiary
        label.translatesAutoresizingMaskIntoConstraints = false

        let appNames = ["Netflix", "YouTube", "Thêm"]
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false

        for (index, (text, hexColor, cmd)) in apps.enumerated() {
            let container = UIStackView()
            container.axis = .vertical
            container.spacing = 6
            container.alignment = .center

            let btn = AppIconButton(text: text, color: UIColor(hex: hexColor), command: cmd)
            btn.onTap = { [weak self] c in self?.onCommand?(c) }

            let nameLabel = UILabel()
            nameLabel.text = appNames[index]
            nameLabel.font = Theme.Font.rounded(11, weight: .medium)
            nameLabel.textColor = Theme.Color.textSecondary
            nameLabel.textAlignment = .center

            container.addArrangedSubview(btn)
            container.addArrangedSubview(nameLabel)
            btn.heightAnchor.constraint(equalToConstant: 52).isActive = true
            row.addArrangedSubview(container)
        }

        let stack = UIStackView(arrangedSubviews: [label, row])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
        ])
    }
}

// MARK: - App Icon Button
class AppIconButton: UIControl {
    var command: RemoteCommand?
    var onTap: ((RemoteCommand) -> Void)?

    private let iconLabel: UILabel

    init(text: String, color: UIColor, command: RemoteCommand) {
        self.command = command
        self.iconLabel = UILabel()
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        backgroundColor = color.withAlphaComponent(0.15)
        layer.cornerRadius = Theme.Radius.md
        layer.borderWidth = 1
        layer.borderColor = color.withAlphaComponent(0.3).cgColor
        addGlow(color: color, radius: 8, opacity: 0.25)

        iconLabel.text = text
        iconLabel.font = Theme.Font.rounded(22, weight: .bold)
        iconLabel.textColor = color
        iconLabel.textAlignment = .center
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconLabel)
        iconLabel.pinToEdges(of: self)

        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        addTarget(self, action: #selector(down), for: .touchDown)
        addTarget(self, action: #selector(up), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func tapped() {
        HapticManager.impact(.light)
        if let cmd = command { onTap?(cmd) }
    }
    @objc private func down() {
        UIView.animate(withDuration: 0.1) { self.transform = CGAffineTransform(scaleX: 0.92, y: 0.92) }
    }
    @objc private func up() {
        UIView.animate(withDuration: 0.18, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.3, options: []) {
            self.transform = .identity
        }
    }
}
