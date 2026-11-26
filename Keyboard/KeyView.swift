import UIKit

/// Reads the palette chosen in the settings app. Call `reload()` when the keyboard appears.
enum Theme {
    private(set) static var palette = ThemePalette.current()

    static func reload() { palette = ThemePalette.current() }

    static var background: UIColor { palette.background }
    static var onBackground: UIColor { palette.onBackground }
    static var accent: UIColor { palette.accent }
    static var hint: UIColor { palette.text.withAlphaComponent(0.55) }
    static var barHint: UIColor { palette.onBackground.withAlphaComponent(0.4) }

    static func fill(_ style: KeyStyle, pressed: Bool) -> UIColor {
        switch (style, pressed) {
        case (.normal, false): return palette.key
        case (.normal, true): return palette.keyPressed
        case (.special, false): return palette.special
        case (.special, true): return palette.specialPressed
        case (.accent, false): return palette.accent
        case (.accent, true): return palette.accentPressed
        }
    }

    static func textColor(for style: KeyStyle) -> UIColor {
        switch style {
        case .normal: return palette.text
        case .special: return palette.specialText
        case .accent: return palette.accentGlyph
        }
    }
}

final class KeyView: UIView {
    var spec: KeySpec { didSet { refresh() } }
    var isPressed = false { didSet { updateColors() } }
    var isActive = false { didSet { updateColors() } }   // shift on / caps

    private let titleLabel = UILabel()
    private let hintLabel = UILabel()

    init(spec: KeySpec) {
        self.spec = spec
        super.init(frame: .zero)
        layer.cornerRadius = 6
        isUserInteractionEnabled = false   // KeyboardView handles all touches

        titleLabel.textAlignment = .center
        hintLabel.font = .systemFont(ofSize: 9)
        hintLabel.textAlignment = .right
        addSubview(titleLabel)
        addSubview(hintLabel)
        refresh()
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Re-applies text, fonts and colours (also used after a theme change).
    func refresh() {
        titleLabel.text = spec.label
        hintLabel.text = spec.hint
        hintLabel.textColor = Theme.hint
        switch spec.kind {
        case .char, .comma, .ret, .shift, .backspace:
            titleLabel.font = .systemFont(ofSize: 22)
        case .space:
            titleLabel.font = .systemFont(ofSize: 11)
        default:
            titleLabel.font = .systemFont(ofSize: 15)
        }
        updateColors()
        setNeedsLayout()
    }

    private func updateColors() {
        // An active shift key is drawn like a normal (light) key.
        let style: KeyStyle = (spec.kind == .shift && isActive) ? .normal : spec.style
        backgroundColor = Theme.fill(style, pressed: isPressed)
        titleLabel.textColor = Theme.textColor(for: style)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        titleLabel.frame = bounds
        hintLabel.frame = CGRect(x: 0, y: 2, width: bounds.width - 4, height: 11)
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        updateColors()
    }
}
