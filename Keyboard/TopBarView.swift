import UIKit

enum BarTool { case textEdit, settings, translate }

/// Gboard-style bar: [grid] [3 suggestions | tool icons] [undo]
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
    private var highlightIndex: Int?

    override init(frame: CGRect) {
        super.init(frame: frame)

        gridButton.setImage(UIImage(systemName: "square.grid.2x2.fill"), for: .normal)
        gridButton.layer.cornerRadius = 17
        gridButton.addTarget(self, action: #selector(gridTapped), for: .touchUpInside)
        addSubview(gridButton)

        undoButton.setImage(UIImage(systemName: "arrow.uturn.backward"), for: .normal)
        undoButton.layer.cornerRadius = 17
        undoButton.addTarget(self, action: #selector(undoTapped), for: .touchUpInside)
        addSubview(undoButton)

        for i in 0..<3 {
            let b = UIButton(type: .system)
            b.titleLabel?.font = .systemFont(ofSize: 17)
            b.titleLabel?.lineBreakMode = .byTruncatingTail
            b.tag = i
            b.layer.cornerRadius = 8
            b.addTarget(self, action: #selector(suggestionTapped(_:)), for: .touchUpInside)
            addSubview(b)
            suggestionButtons.append(b)
        }
        for _ in 0..<2 {
            let d = UIView()
            addSubview(d)
            dividers.append(d)
        }

        let tools: [(BarTool, String)] = [
            (.textEdit, "character.cursor.ibeam"),
            (.settings, "gearshape.fill"),
            (.translate, "character.bubble")
        ]
        for (tool, symbol) in tools {
            let b = UIButton(type: .system)
            b.setImage(UIImage(systemName: symbol), for: .normal)
            b.addAction(UIAction { [weak self] _ in self?.onTool?(tool) }, for: .touchUpInside)
            addSubview(b)
            toolButtons.append((tool, b))
        }
        applyTheme()
        setShowingTools(false)
    }
    required init?(coder: NSCoder) { fatalError() }

    func applyTheme() {
        backgroundColor = Theme.background
        gridButton.tintColor = Theme.onBackground
        undoButton.tintColor = Theme.palette.specialText
        undoButton.backgroundColor = Theme.fill(.special, pressed: false)
        suggestionButtons.forEach {
            $0.setTitleColor(Theme.onBackground, for: .normal)
            $0.setTitleColor(Theme.barHint, for: .disabled)
        }
        dividers.forEach { $0.backgroundColor = Theme.barHint }
        toolButtons.forEach { $0.1.tintColor = Theme.onBackground }
        refreshHighlight()
    }

    /// The highlighted slot (the autocorrect candidate) gets a key-coloured pill, like SwiftKey / Gboard.
    private func refreshHighlight() {
        for (i, b) in suggestionButtons.enumerated() {
            let on = i == highlightIndex && !titles[i].isEmpty
            b.backgroundColor = on ? Theme.fill(.normal, pressed: false) : .clear
            b.setTitleColor(on ? Theme.textColor(for: .normal) : Theme.onBackground, for: .normal)
        }
    }

    // MARK: API

    func setSuggestions(_ s: [String], highlight: Int? = nil) {
        titles = (0..<3).map { $0 < s.count ? s[$0] : "" }
        highlightIndex = highlight
        for (i, b) in suggestionButtons.enumerated() {
            b.setTitle(titles[i], for: .normal)
            b.isEnabled = !titles[i].isEmpty
        }
        refreshHighlight()
    }

    func setShowingTools(_ tools: Bool) {
        showingTools = tools
        suggestionButtons.forEach { $0.isHidden = tools }
        dividers.forEach { $0.isHidden = tools }
        toolButtons.forEach { $0.1.isHidden = !tools }
    }

    func setBusyMessage(_ text: String?) {
        guard let text = text else { setSuggestions(titles, highlight: highlightIndex); return }
        setShowingTools(false)
        for (i, b) in suggestionButtons.enumerated() {
            b.setTitle(i == 1 ? text : "", for: .normal)
            b.isEnabled = false
            b.backgroundColor = .clear
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
            b.frame = CGRect(x: midX + CGFloat(i) * sw + 3, y: 4, width: sw - 6, height: h - 8)
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
