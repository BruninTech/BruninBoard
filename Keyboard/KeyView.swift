import UIKit

enum Theme {
    static let background = UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.02, green: 0.02, blue: 0.02, alpha: 1)
        : UIColor(red: 0.82, green: 0.84, blue: 0.86, alpha: 1) }

    static func fill(_ style: KeyStyle, pressed: Bool) -> UIColor {
        UIColor { t in
            let dark = t.userInterfaceStyle == .dark
            switch (style, pressed) {
            case (.normal, false):  return dark ? UIColor(white: 0.23, alpha: 1) : .white
            case (.normal, true):   return dark ? UIColor(white: 0.36, alpha: 1) : UIColor(white: 0.85, alpha: 1)
            case (.special, false): return dark ? UIColor(white: 0.13, alpha: 1) : UIColor(white: 0.68, alpha: 1)
            case (.special, true):  return dark ? UIColor(white: 0.30, alpha: 1) : UIColor(white: 0.85, alpha: 1)
            case (.accent, false):  return UIColor(red: 0.49, green: 0.84, blue: 0.78, alpha: 1)
            case (.accent, true):   return UIColor(red: 0.38, green: 0.72, blue: 0.67, alpha: 1)
            }
        }
    }

    static let text = UIColor { $0.userInterfaceStyle == .dark ? .white : .black }
    static let hint = UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(white: 1, alpha: 0.55) : UIColor(white: 0, alpha: 0.45) }
    static let accentGlyph = UIColor(red: 0.04, green: 0.2, blue: 0.18, alpha: 1)
    static let bar = UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(white: 0.16, alpha: 1) : UIColor(white: 0.74, alpha: 1) }
}

final class KeyView: UIView {
    var spec: KeySpec { didSet { refresh() } }
    var isPressed = false { didSet { updateFill() } }
    var isActive = false { didSet { updateFill() } }   // e.g. shift on / caps

    private let titleLabel = UILabel()
    private let hintLabel = UILabel()

    init(spec: KeySpec) {
        self.spec = spec
        super.init(frame: .zero)
        layer.cornerRadius = 6
        isUserInteractionEnabled = false   // KeyboardView handles all touches

        titleLabel.textAlignment = .center
        hintLabel.font = .systemFont(ofSize: 9)
        hintLabel.textColor = Theme.hint
        hintLabel.textAlignment = .right
        addSubview(titleLabel)
        addSubview(hintLabel)
        refresh()
    }

    required init?(coder: NSCoder) { fatalError() }

    func refresh() {
        titleLabel.text = spec.label
        hintLabel.text = spec.hint
        switch spec.kind {
        case .char:
            titleLabel.font = .systemFont(ofSize: 22)
        case .space:
            titleLabel.font = .systemFont(ofSize: 11)
        case .emoji, .globe:
            titleLabel.font = .systemFont(ofSize: 18)
        case .ret, .shift, .backspace:
            titleLabel.font = .systemFont(ofSize: 22)
        default:
            titleLabel.font = .systemFont(ofSize: 15)
        }
        titleLabel.textColor = spec.style == .accent ? Theme.accentGlyph : Theme.text
        updateFill()
        setNeedsLayout()
    }

    private func updateFill() {
        if spec.kind == .shift && isActive {
            backgroundColor = Theme.fill(.normal, pressed: isPressed)
        } else {
            backgroundColor = Theme.fill(spec.style, pressed: isPressed)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        titleLabel.frame = bounds
        hintLabel.frame = CGRect(x: 0, y: 2, width: bounds.width - 4, height: 11)
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        updateFill()
        titleLabel.textColor = spec.style == .accent ? Theme.accentGlyph : Theme.text
    }
}
