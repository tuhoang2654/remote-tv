import UIKit

// MARK: - App Theme
enum Theme {
    // MARK: Colors
    enum Color {
        static let background = UIColor(hex: "#0A0A0F")
        static let surface = UIColor(hex: "#12121A")
        static let surfaceElevated = UIColor(hex: "#1C1C28")
        static let accent = UIColor(hex: "#6C63FF")
        static let accentLight = UIColor(hex: "#8B85FF")
        static let accentGlow = UIColor(hex: "#6C63FF").withAlphaComponent(0.3)
        static let textPrimary = UIColor(hex: "#FFFFFF")
        static let textSecondary = UIColor(hex: "#8888A0")
        static let textTertiary = UIColor(hex: "#55556A")
        static let border = UIColor(hex: "#2A2A3C")
        static let danger = UIColor(hex: "#FF4757")
        static let success = UIColor(hex: "#2ED573")
        static let warning = UIColor(hex: "#FFA502")
        static let powerRed = UIColor(hex: "#FF3B30")
        static let navBlue = UIColor(hex: "#4A9EFF")
        static let mediaGreen = UIColor(hex: "#34C759")
    }

    // MARK: Font
    enum Font {
        static func rounded(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
            let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
                .withDesign(.rounded) ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
            return UIFont(descriptor: descriptor.addingAttributes([
                .traits: [UIFontDescriptor.TraitKey.weight: weight]
            ]), size: size)
        }

        static func mono(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
            return UIFont.monospacedSystemFont(ofSize: size, weight: weight)
        }
    }

    // MARK: Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: Corner Radius
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let circle: CGFloat = 999
    }
}

// MARK: - UIColor Hex Extension
extension UIColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

// MARK: - Haptic Feedback
class HapticManager {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}

// MARK: - UIView Extensions
extension UIView {
    func addGlow(color: UIColor, radius: CGFloat = 12, opacity: Float = 0.8) {
        layer.shadowColor = color.cgColor
        layer.shadowOffset = .zero
        layer.shadowRadius = radius
        layer.shadowOpacity = opacity
    }

    func removeGlow() {
        layer.shadowColor = UIColor.clear.cgColor
        layer.shadowOpacity = 0
    }

    func pinToEdges(of view: UIView, insets: UIEdgeInsets = .zero) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: view.topAnchor, constant: insets.top),
            leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: insets.left),
            trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -insets.right),
            bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -insets.bottom)
        ])
    }

    func animatePress(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.08, animations: {
            self.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        }) { _ in
            UIView.animate(withDuration: 0.12, delay: 0, usingSpringWithDamping: 0.6,
                           initialSpringVelocity: 0.5, options: [], animations: {
                self.transform = .identity
            }) { _ in
                completion?()
            }
        }
    }
}
