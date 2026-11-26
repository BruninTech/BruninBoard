import UIKit

enum BarTool { case textEdit, clipboard, settings, translate }

/// Gboard-style bar: [grid] [3 suggestions | 4 tool icons] [undo]
final class TopBarView: UIView {
    var onGrid: (() -> Void)?
    var onSuggestion: ((Int) -> Void)?
    var onTool: ((BarTool) -> Void)?
    var onUndo: (() -> Void)?

    private let gridButton = UIButton(type: .system)
    private let undoButton = UIButton(type: .system)
    private var suggestionButtons: [UIButton] = []
    private var dividers: [UIView] = []
    private var toolButtons: [(BarTool, UIButton)] = []

    private(set) var showingTools = false
    private var titles: [String] = ["", "", ""]

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.background

        style(circle: gridButton, symbol: "square.grid.2x2.fill", square: true)
        gridButton.addTarget(self, action: #selector(gridTapped), for: .touchUpInside)
        addSubview(gridButton)

        style(circle: undoButton, symbol: "arrow.uturn.backward", square: false)
        undoButton.addTarget(self, action: #selector(undoTapped), for: .touchUpInside)
        addSubview(undoButton)

        for i in 0..<3 {
            let b = UIButton(type: .system)
            b.titleLabel?.font = .systemFont(ofSize: 17)
            b.titleLabel?.lineBreakMode = .byTruncatingTail
            b.setTitleColor(Theme.text, for: .normal)
            b.tag = i
            b.addTarget(self, action: #selector(suggestionTapped(_:)), for: .touchUpInside)
            addSubview(b)
            suggestionButtons.append(b)
        }
        for _ in 0..<2 {
            let d = UIView()
            d.backgroundColor = Theme.hint
            addSubview(d)
            dividers.append(d)
        }

        let tools: [(BarTool, String)] = [
            (.textEdit, "character.cursor.ibeam"),
            (.clipboard, "doc.on.clipboard"),
            (.settings, "gearshape.fill"),
            (.translate, "character.bubble")
        ]
        for (tool, symbol) in tools {
            let b = UIButton(type: .system)
            b.setImage(UIImage(systemName: symbol), for: .normal)
            b.tintColor = Theme.text
            b.addAction(UIAction { [weak self] _ in self?.onTool?(tool) }, for: .touchUpInside)
            addSubview(b)
            toolButtons.append((tool, b))
        }
        setShowingTools(false)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func style(circle b: UIButton, symbol: String, square: Bool) {
        b.setImage(UIImage(systemName: symbol), for: .normal)
        b.tintColor = Theme.text
        b.backgroundColor = square ? .clear : Theme.fill(.special, pressed: false)
        b.layer.cornerRadius = 17
    }

    // MARK: API

    func setSuggestions(_ s: [String]) {
        titles = (0..<3).map { $0 < s.count ? s[$0] : "" }
        for (i, b) in suggestionButtons.enumerated() {
            b.setTitle(titles[i], for: .normal)
            b.isEnabled = !titles[i].isEmpty
        }
    }

    func setShowingTools(_ tools: Bool) {
        showingTools = tools
        suggestionButtons.forEach { $0.isHidden = tools }
        dividers.forEach { $0.isHidden = tools }
        toolButtons.forEach { $0.1.isHidden = !tools }
    }

    func setBusyMessage(_ text: String?) {
        guard let text = text else { setSuggestions(titles); return }
        setShowingTools(false)
        for (i, b) in suggestionButtons.enumerated() {
            b.setTitle(i == 1 ? text : "", for: .normal)
            b.isEnabled = false
        }
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        let h = bounds.height, w = bounds.width
        let side: CGFloat = 34
        let y = (h - side) / 2
        gridButton.frame = CGRect(x: 8, y: y, width: side, height: side)
        undoButton.frame = CGRect(x: w - 8 - side, y: y, width: side, height: side)

        let midX = 8 + side + 6
        let midW = w - 2 * midX
        let sw = midW / 3
        for (i, b) in suggestionButtons.enumerated() {
            b.frame = CGRect(x: midX + CGFloat(i) * sw, y: 0, width: sw, height: h)
        }
        for (i, d) in dividers.enumerated() {
            d.frame = CGRect(x: midX + CGFloat(i + 1) * sw, y: h * 0.25, width: 0.5, height: h * 0.5)
        }
        let tw = midW / CGFloat(max(toolButtons.count, 1))
        for (i, t) in toolButtons.enumerated() {
            t.1.frame = CGRect(x: midX + CGFloat(i) * tw, y: 0, width: tw, height: h)
        }
    }

    @objc private func gridTapped() { onGrid?() }
    @objc private func undoTapped() { onUndo?() }
    @objc private func suggestionTapped(_ b: UIButton) { onSuggestion?(b.tag) }
}
