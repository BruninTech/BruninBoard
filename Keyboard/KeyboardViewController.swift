import UIKit

private struct UndoRecord {
    var deleteCount: Int
    var restore: String
    var learn: String?
}

final class KeyboardViewController: UIInputViewController, KeyboardViewDelegate {
    private let haptics = Haptics()
    private let engine = SuggestionEngine()

    private let root = ClickInputView(frame: .zero, inputViewStyle: .keyboard)
    private let keyboardView = KeyboardView()
    private let topBar = TopBarView()
    private let editView = TextEditView()
    private var heightConstraint: NSLayoutConstraint!

    private var topBarVisible = false
    private var isEditMode = false

    private var currentSuggestions: [String] = []
    private var undoStack: [UndoRecord] = []
    private var lastSpaceTime = Date.distantPast
    private var lastShiftTap = Date.distantPast
    private var lastInputTime = Date.distantPast

    private let barHeight: CGFloat = 40
    private var proxy: UITextDocumentProxy { textDocumentProxy }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background

        heightConstraint = view.heightAnchor.constraint(equalToConstant: 218)
        heightConstraint.priority = UILayoutPriority(999)
        heightConstraint.isActive = true

        view.addSubview(root)
        root.addSubview(keyboardView)
        root.addSubview(topBar)
        root.addSubview(editView)
        editView.isHidden = true

        keyboardView.delegate = self
        wireTopBar()
        wireEditView()

        topBarVisible = Settings.showTopBarOnLaunch
        topBar.isHidden = !topBarVisible

        requestSupplementaryLexicon { [weak self] lexicon in
            self?.engine.load(lexicon)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        keyboardView.refreshSpaceLabel()
        haptics.prepare()
        updateHeight()
        updateAutoShift()
        updateSuggestions()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let b = view.bounds
        root.frame = b
        if isEditMode {
            editView.frame = b
        } else {
            let barH = topBarVisible ? barHeight : 0
            topBar.frame = CGRect(x: 0, y: 0, width: b.width, height: barH)
            keyboardView.frame = CGRect(x: 0, y: barH, width: b.width, height: b.height - barH)
        }
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        // Ignore echoes of our own edits so we don't clobber a manual shift press.
        if Date().timeIntervalSince(lastInputTime) > 0.3 { updateAutoShift() }
        updateSuggestions()
    }

    private func updateHeight() {
        let screen = UIScreen.main.bounds
        let landscape = screen.width > screen.height
        let keysHeight: CGFloat = landscape ? 160 : 218
        let extra: CGFloat = (topBarVisible || isEditMode) ? barHeight : 0
        heightConstraint.constant = keysHeight + extra
        view.setNeedsLayout()
    }

    // MARK: Wiring

    private func wireTopBar() {
        topBar.onGrid = { [weak self] in
            guard let self = self else { return }
            self.haptics.tap()
            self.topBar.setShowingTools(!self.topBar.showingTools)
            if !self.topBar.showingTools { self.updateSuggestions() }
        }
        topBar.onSuggestion = { [weak self] i in self?.pickSuggestion(i) }
        topBar.onUndo = { [weak self] in self?.undo() }
        topBar.onTool = { [weak self] tool in
            guard let self = self else { return }
            self.haptics.tap()
            switch tool {
            case .textEdit: self.setEditMode(true)
            case .clipboard: self.pasteClipboard()
            case .settings: self.openHostApp()
            case .translate: self.translateCurrentLine()
            }
        }
    }

    private func wireEditView() {
        editView.onAction = { [weak self] action in self?.handleEdit(action) }
    }

    // MARK: Top bar / editing mode

    private func toggleTopBar() {
        topBarVisible.toggle()
        topBar.isHidden = !topBarVisible
        topBar.setShowingTools(false)
        updateHeight()
        view.layoutIfNeeded()
        updateSuggestions()
    }

    private func setEditMode(_ on: Bool) {
        isEditMode = on
        editView.isHidden = !on
        keyboardView.isHidden = on
        topBar.isHidden = on || !topBarVisible
        updateHeight()
        view.setNeedsLayout()
        view.layoutIfNeeded()
        if !on { updateSuggestions() }
    }

    private func flash(_ message: String) {
        topBar.setBusyMessage(message)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            self?.topBar.setBusyMessage(nil)
        }
    }

    // MARK: KeyboardViewDelegate

    func keyboardTouchDown(_ kb: KeyboardView, key: KeySpec) {
        haptics.tap()
        haptics.click()
    }

    func keyboard(_ kb: KeyboardView, didLongPress key: KeySpec) -> Bool {
        switch key.kind {
        case .char:
            guard let hint = key.hint else { return false }
            haptics.longPress()
            lastInputTime = Date()
            insertPlain(hint)
            return true
        case .emoji:
            haptics.longPress()
            lastInputTime = Date()
            insertSeparator(",")
            return true
        default:
            return false
        }
    }

    func keyboard(_ kb: KeyboardView, didSwipeUp key: KeySpec) {
        guard key.kind == .emoji else { return }
        haptics.longPress()
        toggleTopBar()
    }

    func keyboard(_ kb: KeyboardView, didTap key: KeySpec) {
        lastInputTime = Date()
        switch key.kind {
        case .char:
            if isWordCharacter(key.output) { insertPlain(key.output) } else { insertSeparator(key.output) }
            if keyboardView.shiftState == .once { keyboardView.shiftState = .off }
            updateAutoShift()
            updateSuggestions()

        case .space:
            handleSpace()

        case .ret:
            insertSeparator("\n")
            updateAutoShift()
            updateSuggestions()

        case .backspace:
            undoStack.removeAll()
            proxy.deleteBackward()
            updateAutoShift()
            updateSuggestions()

        case .shift:
            let now = Date()
            if now.timeIntervalSince(lastShiftTap) < 0.35 {
                keyboardView.shiftState = .caps
            } else {
                keyboardView.shiftState = keyboardView.shiftState == .off ? .once : .off
            }
            lastShiftTap = now

        case .page(let p):
            keyboardView.setPage(p)
            if p == .letters { updateAutoShift() }

        case .emoji, .globe:
            advanceToNextInputMode()

        case .spacer:
            break
        }
    }

    // MARK: Text insertion

    private func isWordCharacter(_ s: String) -> Bool {
        guard let c = s.first, s.count == 1 else { return false }
        return c.isLetter || c == "'" || c == "’"
    }

    private func insertPlain(_ text: String) {
        undoStack.removeAll()
        proxy.insertText(text)
    }

    /// Insert a word-ending character, applying shortcuts / autocorrect to the word before it.
    private func insertSeparator(_ sep: String) {
        let corrected = applyCorrection()
        proxy.insertText(sep)
        if let c = corrected {
            undoStack = [UndoRecord(deleteCount: c.replacement.count + sep.count,
                                    restore: c.original + sep,
                                    learn: c.learnable ? c.original : nil)]
        } else {
            undoStack.removeAll()
        }
    }

    private func applyCorrection() -> (original: String, replacement: String, learnable: Bool)? {
        guard let before = proxy.documentContextBeforeInput else { return nil }
        let word = SuggestionEngine.currentWord(in: before)
        guard !word.isEmpty else { return nil }

        var replacement = engine.shortcut(for: word)
        var learnable = false
        if replacement == nil, Settings.autoCorrect {
            replacement = engine.autocorrection(for: word)
            learnable = true
        }
        guard let r = replacement, r != word else { return nil }
        for _ in 0..<word.count { proxy.deleteBackward() }
        proxy.insertText(r)
        return (word, r, learnable)
    }

    private func handleSpace() {
        let now = Date()
        let before = proxy.documentContextBeforeInput ?? ""
        // Double space -> ". "
        if now.timeIntervalSince(lastSpaceTime) < 0.4,
           before.hasSuffix(" "),
           let prev = before.dropLast().last, prev.isLetter || prev.isNumber {
            proxy.deleteBackward()
            proxy.insertText(". ")
            undoStack.removeAll()
            lastSpaceTime = .distantPast
        } else {
            insertSeparator(" ")
            lastSpaceTime = now
        }
        updateAutoShift()
        updateSuggestions()
    }

    // MARK: Suggestions

    private func updateSuggestions() {
        guard topBarVisible, !isEditMode, !topBar.showingTools else { return }
        let before = proxy.documentContextBeforeInput ?? ""
        let word = SuggestionEngine.currentWord(in: before)
        guard !word.isEmpty else {
            currentSuggestions = []
            topBar.setSuggestions([])
            return
        }
        currentSuggestions = [word] + engine.suggestions(for: word)
        topBar.setSuggestions(currentSuggestions)
    }

    private func pickSuggestion(_ index: Int) {
        guard index < currentSuggestions.count else { return }
        haptics.tap()
        let before = proxy.documentContextBeforeInput ?? ""
        let word = SuggestionEngine.currentWord(in: before)
        guard !word.isEmpty else { return }
        let chosen = currentSuggestions[index]
        for _ in 0..<word.count { proxy.deleteBackward() }
        proxy.insertText(chosen + " ")
        if index == 0 { engine.learn(word) }        // keeping your own word teaches the dictionary
        undoStack = [UndoRecord(deleteCount: chosen.count + 1, restore: word + " ", learn: nil)]
        lastInputTime = Date()
        updateAutoShift()
        updateSuggestions()
    }

    // MARK: Auto-capitalisation

    private func updateAutoShift() {
        guard Settings.autoCapitalize, keyboardView.page == .letters,
              keyboardView.shiftState != .caps else { return }
        let type = proxy.autocapitalizationType ?? UITextAutocapitalizationType.none
        let before = proxy.documentContextBeforeInput ?? ""
        var shouldCap = false
        switch type {
        case .allCharacters:
            shouldCap = true
        case .words:
            shouldCap = before.isEmpty || (before.last?.isWhitespace ?? false)
        case .sentences:
            if before.isEmpty || before.hasSuffix("\n") {
                shouldCap = true
            } else if before.hasSuffix(" ") {
                let trimmed = before.trimmingCharacters(in: .whitespaces)
                if let last = trimmed.last { shouldCap = ".!?".contains(last) }
            }
        default:
            shouldCap = false
        }
        keyboardView.shiftState = shouldCap ? .once : .off
    }

    // MARK: Undo

    private func undo() {
        haptics.tap()
        guard let r = undoStack.popLast() else { return }
        for _ in 0..<r.deleteCount { proxy.deleteBackward() }
        proxy.insertText(r.restore)
        if let w = r.learn { engine.learn(w) }
        lastInputTime = Date()
        updateAutoShift()
        updateSuggestions()
    }

    // MARK: Tools

    private func pasteClipboard() {
        guard let s = UIPasteboard.general.string, !s.isEmpty else {
            flash("Clipboard empty (Full Access on?)")
            return
        }
        proxy.insertText(s)
        undoStack = [UndoRecord(deleteCount: s.count, restore: "", learn: nil)]
        lastInputTime = Date()
    }

    private func translateCurrentLine() {
        let before = proxy.documentContextBeforeInput ?? ""
        let line = before.components(separatedBy: "\n").last ?? before
        guard !line.trimmingCharacters(in: .whitespaces).isEmpty else {
            flash("Nothing to translate")
            return
        }
        let original = String(line.suffix(450))
        topBar.setBusyMessage("Translating…")
        Translator.translate(original, from: Settings.translateSource, to: Settings.translateTarget) { [weak self] result in
            guard let self = self else { return }
            guard let t = result, !t.isEmpty else {
                self.flash("Translation failed (Full Access on?)")
                return
            }
            guard (self.proxy.documentContextBeforeInput ?? "").hasSuffix(original) else {
                self.flash("Text changed, try again")
                return
            }
            for _ in 0..<original.count { self.proxy.deleteBackward() }
            self.proxy.insertText(t)
            self.undoStack = [UndoRecord(deleteCount: t.count, restore: original, learn: nil)]
            self.lastInputTime = Date()
            self.topBar.setBusyMessage(nil)
        }
    }

    /// Keyboard extensions can't call UIApplication.shared; walk the responder chain instead.
    private func openHostApp() {
        guard let url = URL(string: "bruninboard://settings") else { return }
        var responder: UIResponder? = self
        while let current = responder {
            if String(describing: type(of: current)) == "UIApplication" {
                _ = current.perform(NSSelectorFromString("openURL:"), with: url)
                return
            }
            responder = current.next
        }
    }

    // MARK: Text editing pad

    private func handleEdit(_ action: EditAction) {
        haptics.tap()
        let before = proxy.documentContextBeforeInput ?? ""
        let after = proxy.documentContextAfterInput ?? ""
        let approxLine = 34      // no public API for visual lines, so up/down move by ~one line of characters
        lastInputTime = Date()

        switch action {
        case .left:  if !before.isEmpty { proxy.adjustTextPosition(byCharacterOffset: -1) }
        case .right: if !after.isEmpty { proxy.adjustTextPosition(byCharacterOffset: 1) }
        case .up:    proxy.adjustTextPosition(byCharacterOffset: -min(approxLine, before.count))
        case .down:  proxy.adjustTextPosition(byCharacterOffset: min(approxLine, after.count))
        case .home:
            let line = before.components(separatedBy: "\n").last ?? ""
            proxy.adjustTextPosition(byCharacterOffset: -line.count)
        case .end:
            let line = after.components(separatedBy: "\n").first ?? ""
            proxy.adjustTextPosition(byCharacterOffset: line.count)
        case .backspace:
            proxy.deleteBackward()
        case .copy:
            UIPasteboard.general.string = proxy.selectedText ?? (before + after)
        case .paste:
            if let s = UIPasteboard.general.string { proxy.insertText(s) }
        case .select, .selectAll:
            break   // the public keyboard API cannot create a text selection
        case .close:
            setEditMode(false)
        }
    }
}
