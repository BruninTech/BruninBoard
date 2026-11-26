import UIKit

enum EditAction {
    case left, right, up, down
    case home, end
    case backspace
    case copy, paste
    case select, selectAll
    case close
}

/// Cursor pad that replaces the key grid (Gboard "Text editing").
final class TextEditView: UIView {
    var onAction: ((EditAction) -> Void)?

    private struct PadButton {
        let action: EditAction
        let button: UIButton
        let enabled: Bool
    }

    private var buttons: [PadButton] = []
    private let titleLabel = UILabel()
    private let backButton = UIButton(type: .system)
    private var repeatTimer: Timer?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backButton.setImage(UIImage(systemName: "arrow.left"), for: .normal)
        backButton.layer.cornerRadius = 17
        backButton.addAction(UIAction { [weak self] _ in self?.onAction?(.close) }, for: .touchUpInside)
        addSubview(backButton)

        titleLabel.text = "Text editing"
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        addSubview(titleLabel)

        let defs: [(EditAction, String, Bool)] = [
            (.left, "chevron.left", true), (.up, "chevron.up", true), (.select, "Select", false),
            (.down, "chevron.down", true), (.right, "chevron.right", true),
            (.selectAll, "Select all", false), (.copy, "Copy", true), (.paste, "Paste", true),
            (.home, "arrow.left.to.line", true), (.end, "arrow.right.to.line", true),
            (.backspace, "delete.left", true)
        ]
        for (action, label, enabled) in defs {
            let b = UIButton(type: .system)
            if let image = UIImage(systemName: label) {
                b.setImage(image, for: .normal)
            } else {
                b.setTitle(label, for: .normal)
                b.titleLabel?.font = .systemFont(ofSize: 14)
            }
            b.layer.cornerRadius = 8
            if [.left, .right, .up, .down, .backspace].contains(action) {
                b.addTarget(self, action: #selector(repeatDown(_:)), for: .touchDown)
                b.addTarget(self, action: #selector(repeatUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
            } else {
                b.addAction(UIAction { [weak self] _ in self?.onAction?(action) }, for: .touchUpInside)
            }
            addSubview(b)
            buttons.append(PadButton(action: action, button: b, enabled: enabled))
        }
        applyTheme()
    }
    required init?(coder: NSCoder) { fatalError() }

    func applyTheme() {
        backgroundColor = Theme.background
        backButton.tintColor = Theme.palette.specialText
        backButton.backgroundColor = Theme.fill(.special, pressed: false)
        titleLabel.textColor = Theme.onBackground
        for pb in buttons {
            let color = pb.enabled ? Theme.textColor(for: .normal) : Theme.hint
            pb.button.tintColor = color
            pb.button.setTitleColor(color, for: .normal)
            pb.button.backgroundColor = Theme.fill(pb.enabled ? .normal : .special, pressed: false)
            pb.button.alpha = pb.enabled ? 1 : 0.55
        }
    }

    @objc private func repeatDown(_ b: UIButton) {
        guard let a = buttons.first(where: { $0.button === b })?.action else { return }
        onAction?(a)
        repeatTimer?.invalidate()
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
            self?.repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
                self?.onAction?(a)
            }
        }
    }

    @objc private func repeatUp() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width, pad: CGFloat = 6
        backButton.frame = CGRect(x: 8, y: 6, width: 34, height: 34)
        titleLabel.frame = CGRect(x: 52, y: 6, width: w - 60, height: 34)

        let top: CGFloat = 50
        let bottom: CGFloat = 6
        let area = CGRect(x: pad, y: top, width: w - 2 * pad, height: bounds.height - top - bottom)
        let colW = (area.width - 3 * pad) / 4           // 4 columns

        // 4 rows of equal height: Up / Select / Down stack in the middle column,
        // Left and Right are tall buttons beside them (like the Gboard reference).
        let rows: CGFloat = 4
        let h = (area.height - (rows - 1) * pad) / rows
        func rect(_ c: CGFloat, _ r: CGFloat, cols: CGFloat = 1, rows rs: CGFloat = 1) -> CGRect {
            CGRect(x: area.minX + c * (colW + pad), y: area.minY + r * (h + pad),
                   width: colW * cols + pad * (cols - 1), height: h * rs + pad * (rs - 1))
        }
        let place: [EditAction: CGRect] = [
            .left: rect(0, 0, rows: 3),
            .up: rect(1, 0),
            .select: rect(1, 1),
            .down: rect(1, 2),
            .right: rect(2, 0, rows: 3),
            .selectAll: rect(3, 0),
            .copy: rect(3, 1),
            .paste: rect(3, 2),
            .home: rect(0, 3, cols: 2),
            .end: rect(2, 3),
            .backspace: rect(3, 3)
        ]
        for pb in buttons { if let r = place[pb.action] { pb.button.frame = r } }
    }
}
