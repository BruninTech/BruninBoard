import UIKit

private struct UndoRecord {
    var deleteCount: Int
    var restore: String
    var learn: String?
}

final class KeyboardViewController: UIInputViewController, KeyboardViewDelegate {
    private let haptics = Haptics()
    private let engine = SuggestionEngine()
    private let decoder = SwipeDecoder()

    private let root = ClickInputView(frame: .zero, inputViewStyle: .keyboard)
    private let keyboardView = KeyboardView()
    private let topBar = TopBarView()
    private let editView = TextEditView()
    private var heightConstraint: NSLayoutConstraint!
    private var desiredHeight: CGFloat = 218

    private var topBarVisible = false
    private var isEditMode = false

    private var currentSuggestions: [String] = []
    private var undoStack: [UndoRecord] = []
    private var lastSpaceTime = Date.distantPast
    private var lastShiftTap = Date.distantPast
    private var lastInputTime = Date.distantPast

    // Punctuation / auto-space
    private var autoSpacePunct: String?
    private let autoSpaceSet: Set<Character> = [",", ".", "!", "?"]
    private let closers: Set<Character> = [")", "]", "}"]
    private let wordEnders: Set<Character> = [" ", "\n", ".", ",", "!", "?", ";", ":", ")", "]", "}"]

    // Swipe typing
    private var swipeInserted: String?
    private var swipeAlternatives: [String] = []
    private var lastSwipeTime = Date.distantPast

    // Trackpad / cursor pad
    private var cursorModel: CursorModel?
    private var trackpadActive = false

    private let barHeight: CGFloat = 40
    private var proxy: UITextDocumentProxy { textDocumentProxy }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        inputView?.allowsSelfSizing = true

        heightConstraint = view.heightAnchor.constraint(equalToConstant: desiredHeight)
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
        applyTheme()

        decoder.preload(languages: Settings.languages)
        requestSupplementaryLexicon { [weak self] lexicon in
            guard let self = self else { return }
            self.engine.load(lexicon)
            self.decoder.addExtraWords(self.engine.lexiconWordList)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Theme.reload()
        applyTheme()
        keyboardView.reloadSettings()
        keyboardView.refreshSpaceLabel()
        haptics.prepare()
        updateHeight()
        updateAutoShift()
        updateSuggestions()
    }

    override func updateViewConstraints() {
        super.updateViewConstraints()
        heightConstraint?.constant = desiredHeight
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
        // The cursor moved without us (the user tapped in the text): drop the cached snapshot.
        if !trackpadActive, Date().timeIntervalSince(lastInputTime) > 0.5 { cursorModel = nil }
        updateSuggestions()
    }

    private func applyTheme() {
        view.backgroundColor = Theme.background
        root.backgroundColor = Theme.background
        keyboardView.applyTheme()
        topBar.applyTheme()
        editView.applyTheme()
    }

    /// The key area keeps its height; the bar (or the edit pad's title row) adds 40pt on top.
    /// Hiding the bar therefore shrinks the whole keyboard instead of stretching the keys.
    private func updateHeight() {
        let screen = UIScreen.main.bounds
        let landscape = screen.width > screen.height
        let base: CGFloat = landscape ? 160 : 218
        let scale = CGFloat(min(max(Settings.keyboardHeightScale, 0.7), 1.4))
        let extra: CGFloat = (topBarVisible || isEditMode) ? barHeight : 0
        desiredHeight = (base * scale).rounded() + extra
        heightConstraint.constant = desiredHeight
        view.setNeedsUpdateConstraints()
        view.setNeedsLayout()
        view.superview?.setNeedsLayout()
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
        view.superview?.layoutIfNeeded()
        view.layoutIfNeeded()
        updateSuggestions()
    }

    private func setEditMode(_ on: Bool) {
        isEditMode = on
        cursorModel = nil
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
            insertCharacter(hint)
            return true
        case .comma:
            haptics.longPress()
            advanceToNextInputMode()
            return true
        default:
            return false
        }
    }

    func keyboard(_ kb: KeyboardView, didSwipe key: KeySpec) {
        guard key.kind == .comma else { return }
        haptics.longPress()
        toggleTopBar()
    }

    func keyboard(_ kb: KeyboardView, didTap key: KeySpec) {
        lastInputTime = Date()
        switch key.kind {
        case .char, .comma:
            insertCharacter(key.output)
            if keyboardView.shiftState == .once { keyboardView.shiftState = .off }
            updateAutoShift()
            updateSuggestions()

        case .space:
            handleSpace()

        case .ret:
            if autoSpaceIsPending { proxy.deleteBackward() }
            autoSpacePunct = nil
            insertSeparator("\n")
            updateAutoShift()
            updateSuggestions()

        case .backspace:
            handleBackspace()

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

        case .spacer:
            break
        }
    }

    // MARK: Trackpad delegate

    func keyboardTrackpadBegan(_ kb: KeyboardView) {
        trackpadActive = true
        cursorModel = nil
        haptics.longPress()
    }

    func keyboard(_ kb: KeyboardView, moveCursorByCharacters chars: Int, lines: Int) {
        moveCursor(chars: chars, lines: lines)
    }

    func keyboardTrackpadEnded(_ kb: KeyboardView) {
        trackpadActive = false
        cursorModel = nil
    }

    /// Moves the cursor using a snapshot of the surrounding text, so fast repeated moves don't depend on
    /// the (laggy) document context.
    private func moveCursor(chars: Int, lines: Int, toLineEdge edge: Int = 0) {
        if cursorModel == nil {
            let cpl = Int(view.bounds.width / 10.5)
            cursorModel = CursorModel(before: proxy.documentContextBeforeInput ?? "",
                                      after: proxy.documentContextAfterInput ?? "",
                                      charsPerLine: cpl)
        }
        guard var model = cursorModel else { return }
        let delta: Int
        if edge < 0 {
            delta = model.moveToLineStart()
        } else if edge > 0 {
            delta = model.moveToLineEnd()
        } else {
            delta = model.move(chars: chars, lines: lines)
        }
        cursorModel = model
        lastInputTime = Date()
        if delta != 0 { proxy.adjustTextPosition(byCharacterOffset: delta) }
    }

    // MARK: Text insertion

    private func isWordCharacter(_ s: String) -> Bool {
        guard let c = s.first, s.count == 1 else { return false }
        return c.isLetter || c == "'" || c == "’"
    }

    /// Letters and digits just extend the current word; everything else ends it.
    private func insertCharacter(_ s: String) {
        if isWordCharacter(s) || (!s.isEmpty && s.allSatisfy { $0.isNumber }) {
            insertPlain(s)
        } else {
            insertSeparator(s)
        }
    }

    private func insertPlain(_ text: String) {
        undoStack.removeAll()
        autoSpacePunct = nil
        proxy.insertText(text)
    }

    private var autoSpaceIsPending: Bool {
        guard let p = autoSpacePunct else { return false }
        return (proxy.documentContextBeforeInput ?? "").hasSuffix(p + " ")
    }

    /// Ends the current word: applies shortcuts / autocorrect to it, inserts `sep`, and adds a trailing
    /// space after , . ! ? when that makes sense.
    private func insertSeparator(_ sep: String) {
        var before = proxy.documentContextBeforeInput ?? ""
        let after = proxy.documentContextAfterInput ?? ""

        // Punctuation typed straight after an auto-inserted space takes that space's place:
        // "word, " + "." -> "word."   and   "(word. " + ")" -> "(word.)"
        if let p = autoSpacePunct, before.hasSuffix(p + " "), sep.count == 1, let c = sep.first,
           autoSpaceSet.contains(c) || closers.contains(c) {
            proxy.deleteBackward()
            before.removeLast()
        }
        autoSpacePunct = nil

        // Symbols like @ _ - + / don't commit a word (so handles and emails aren't "corrected").
        var correction: (original: String, replacement: String, learnable: Bool)?
        if sep.count == 1, let c = sep.first, wordEnders.contains(c) {
            correction = applyCorrection(in: before)
        }
        proxy.insertText(sep)
        let addSpace = shouldAutoSpace(after: sep, before: before, textAfter: after)
        if addSpace {
            proxy.insertText(" ")
            autoSpacePunct = sep
        }

        if let c = correction {
            undoStack = [UndoRecord(deleteCount: c.replacement.count + sep.count + (addSpace ? 1 : 0),
                                    restore: c.original + sep + (addSpace ? " " : ""),
                                    learn: c.learnable ? c.original : nil)]
        } else {
            undoStack.removeAll()
        }
    }

    private func shouldAutoSpace(after sep: String, before: String, textAfter: String) -> Bool {
        guard Settings.autoSpacePunctuation, sep.count == 1, let ch = sep.first,
              autoSpaceSet.contains(ch) else { return false }
        switch proxy.keyboardType ?? .default {
        case .URL, .emailAddress: return false
        default: break
        }
        // Only at the end of a line: never in the middle of existing text.
        if let f = textAfter.first, f != "\n" { return false }
        guard let prev = before.last else { return false }      // punctuation at the very start
        if prev.isWhitespace { return false }                   // "hello ." -> no space after the dot
        if prev.isNumber, ch == "." || ch == "," { return false }   // 3.14  1,000
        return true
    }

    private func applyCorrection(in before: String) -> (original: String, replacement: String, learnable: Bool)? {
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
        // A space right after an auto-inserted one is swallowed ("word, " + space stays "word, ").
        if autoSpaceIsPending {
            autoSpacePunct = nil
            return
        }
        let now = Date()
        let before = proxy.documentContextBeforeInput ?? ""
        // Double space -> ". "
        if now.timeIntervalSince(lastSpaceTime) < 0.4,
           before.hasSuffix(" "),
           let prev = before.dropLast().last, prev.isLetter || prev.isNumber {
            proxy.deleteBackward()
            proxy.insertText(". ")
            autoSpacePunct = nil
            undoStack.removeAll()
            lastSpaceTime = .distantPast
        } else {
            insertSeparator(" ")
            lastSpaceTime = now
        }
        updateAutoShift()
        updateSuggestions()
    }

    private func handleBackspace() {
        undoStack.removeAll()
        autoSpacePunct = nil     // backspace over an auto-space removes just the space; nothing is re-added
        // Right after a swiped word, backspace removes the whole word (and its trailing space).
        if let w = swipeInserted, (proxy.documentContextBeforeInput ?? "").hasSuffix(w + " ") {
            for _ in 0..<(w.count + 1) { proxy.deleteBackward() }
            swipeInserted = nil
        } else {
            proxy.deleteBackward()
        }
        updateAutoShift()
        updateSuggestions()
    }

    // MARK: Swipe typing

    func keyboard(_ kb: KeyboardView, didSwipeType input: SwipeInput) {
        lastInputTime = Date()
        let shift = keyboardView.shiftState
        decoder.decode(input, languages: Settings.languages) { [weak self] words, hasDictionary in
            guard let self = self else { return }
            guard hasDictionary else { self.flash("Swipe dictionary missing"); return }
            guard !words.isEmpty else { return }
            self.commitSwipe(words.map { self.cased($0, shift) })
            if shift == .once { self.keyboardView.shiftState = .off }
        }
    }

    private func cased(_ w: String, _ shift: ShiftState) -> String {
        switch shift {
        case .off: return w
        case .once: return w.prefix(1).uppercased() + w.dropFirst()
        case .caps: return w.uppercased()
        }
    }

    private func commitSwipe(_ words: [String]) {
        guard let primary = words.first else { return }
        let before = proxy.documentContextBeforeInput ?? ""
        let justSwiped = swipeInserted != nil && Date().timeIntervalSince(lastSwipeTime) < 0.6
        var prefix = ""
        if !justSwiped, let last = before.last,
           last.isLetter || last.isNumber || ",.!?;:".contains(last) {
            prefix = " "
        }
        autoSpacePunct = nil
        proxy.insertText(prefix + primary + " ")
        undoStack = [UndoRecord(deleteCount: prefix.count + primary.count + 1, restore: "", learn: nil)]
        swipeInserted = primary
        swipeAlternatives = words
        lastSwipeTime = Date()
        lastInputTime = Date()
        updateAutoShift()
        updateSuggestions()
    }

    // MARK: Suggestions

    private func updateSuggestions() {
        guard topBarVisible, !isEditMode, !topBar.showingTools else { return }
        let before = proxy.documentContextBeforeInput ?? ""

        // Right after a swipe the strip offers the other candidates for that word.
        if let inserted = swipeInserted {
            if before.hasSuffix(inserted + " ") {
                currentSuggestions = swipeAlternatives
                topBar.setSuggestions(currentSuggestions)
                return
            }
            swipeInserted = nil
        }

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
        let chosen = currentSuggestions[index]

        // Replacing a swiped word with one of its alternatives.
        if let inserted = swipeInserted, before.hasSuffix(inserted + " ") {
            for _ in 0..<(inserted.count + 1) { proxy.deleteBackward() }
            proxy.insertText(chosen + " ")
            swipeInserted = chosen
            undoStack = [UndoRecord(deleteCount: chosen.count + 1, restore: "", learn: nil)]
            lastInputTime = Date()
            updateAutoShift()
            updateSuggestions()
            return
        }

        let word = SuggestionEngine.currentWord(in: before)
        guard !word.isEmpty else { return }
        for _ in 0..<word.count { proxy.deleteBackward() }
        proxy.insertText(chosen + " ")
        autoSpacePunct = nil
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
        swipeInserted = nil
        autoSpacePunct = nil
        lastInputTime = Date()
        updateAutoShift()
        updateSuggestions()
    }

    // MARK: Tools

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
        lastInputTime = Date()

        switch action {
        case .left:  moveCursor(chars: -1, lines: 0)
        case .right: moveCursor(chars: 1, lines: 0)
        case .up:    moveCursor(chars: 0, lines: -1)
        case .down:  moveCursor(chars: 0, lines: 1)
        case .home:  moveCursor(chars: 0, lines: 0, toLineEdge: -1)
        case .end:   moveCursor(chars: 0, lines: 0, toLineEdge: 1)
        case .backspace:
            cursorModel = nil
            proxy.deleteBackward()
        case .copy:
            UIPasteboard.general.string = proxy.selectedText ?? (before + after)
        case .paste:
            cursorModel = nil
            if let s = UIPasteboard.general.string { proxy.insertText(s) }
        case .select, .selectAll:
            break   // the public keyboard API cannot create a text selection
        case .close:
            setEditMode(false)
        }
    }
}
