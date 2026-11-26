import UIKit

enum ShiftState { case off, once, caps }

protocol KeyboardViewDelegate: AnyObject {
    func keyboardTouchDown(_ kb: KeyboardView, key: KeySpec)
    func keyboard(_ kb: KeyboardView, didTap key: KeySpec)
    /// Return true if the long press produced output (then the tap on release is suppressed).
    func keyboard(_ kb: KeyboardView, didLongPress key: KeySpec) -> Bool
    /// Vertical swipe on the comma key.
    func keyboard(_ kb: KeyboardView, didSwipe key: KeySpec)
    func keyboard(_ kb: KeyboardView, didSwipeType input: SwipeInput)
    func keyboardTrackpadBegan(_ kb: KeyboardView)
    func keyboard(_ kb: KeyboardView, moveCursorByCharacters chars: Int, lines: Int)
    func keyboardTrackpadEnded(_ kb: KeyboardView)
}

/// Draws the key grid and owns all touch handling: forgiving hit-testing (nearest key wins),
/// hold-for-symbol, swipe typing, and the trackpad (3D Touch press or horizontal swipe on the space bar).
final class KeyboardView: UIView {
    weak var delegate: KeyboardViewDelegate?

    private(set) var page: Page = .letters
    private var keyViews: [[KeyView]] = []

    var shiftState: ShiftState = .off { didSet { applyCase() } }

    // Cached settings (refreshed by reloadSettings()).
    private var swipeEnabled = true
    private var forceEnabled = true
    private var forceThreshold: CGFloat = 0.45

    private let trailLayer = CAShapeLayer()

    private final class TouchState {
        var keyView: KeyView
        let start: CGPoint
        var anchor: CGPoint
        var longPressTimer: Timer?
        var repeatTimer: Timer?
        var didLongPress = false
        var didSwipe = false
        var isTrackpad = false
        var horizontalOnly = false
        var isSwiping = false
        var points: [CGPoint] = []
        init(keyView: KeyView, start: CGPoint) {
            self.keyView = keyView
            self.start = start
            self.anchor = start
        }
        func cancelTimers() {
            longPressTimer?.invalidate(); longPressTimer = nil
            repeatTimer?.invalidate(); repeatTimer = nil
        }
    }
    private var states: [UITouch: TouchState] = [:]
    private var trackpadTouch: UITouch?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true

        trailLayer.fillColor = nil
        trailLayer.lineWidth = 7
        trailLayer.lineCap = .round
        trailLayer.lineJoin = .round
        trailLayer.zPosition = 100
        trailLayer.opacity = 0
        layer.addSublayer(trailLayer)

        setPage(.letters)
        reloadSettings()
        applyTheme()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: Settings / theme

    func reloadSettings() {
        swipeEnabled = Settings.swipeTyping
        forceEnabled = Settings.forceTrackpad
        forceThreshold = CGFloat(min(max(Settings.forceThreshold, 0.2), 0.8))
    }

    func applyTheme() {
        backgroundColor = Theme.background
        trailLayer.strokeColor = Theme.accent.withAlphaComponent(0.8).cgColor
        keyViews.flatMap { $0 }.forEach { $0.refresh() }
    }

    // MARK: Pages

    func setPage(_ newPage: Page) {
        states.values.forEach { $0.cancelTimers() }
        states.removeAll()
        if trackpadTouch != nil { endTrackpadAppearance() }
        keyViews.flatMap { $0 }.forEach { $0.removeFromSuperview() }
        page = newPage
        keyViews = Layouts.rows(for: newPage).map { row in
            row.map { spec in
                let v = KeyView(spec: spec)
                v.isHidden = spec.kind == .spacer
                addSubview(v)
                return v
            }
        }
        applyCase()
        setNeedsLayout()
    }

    func refreshSpaceLabel() {
        for kv in keyViews.flatMap({ $0 }) where kv.spec.kind == .space {
            kv.spec.label = Layouts.spaceLabel()
        }
    }

    private func applyCase() {
        let upper = shiftState != .off
        for kv in keyViews.flatMap({ $0 }) {
            if kv.spec.kind == .char, page == .letters {
                let base = kv.spec.output.lowercased()
                let cased = upper ? base.uppercased() : base
                if cased.count == 1 {
                    kv.spec.label = cased
                    kv.spec.output = cased
                }
            } else if kv.spec.kind == .shift {
                kv.spec.label = shiftState == .caps ? "⇪" : "⇧"
                kv.isActive = shiftState != .off
            }
        }
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        trailLayer.frame = bounds
        let sideMargin: CGFloat = 1.5, gap: CGFloat = 6
        let top: CGFloat = 6, bottom: CGFloat = 6, rowGap: CGFloat = 8
        let rowCount = CGFloat(keyViews.count)
        guard rowCount > 0 else { return }
        let rowH = (bounds.height - top - bottom - rowGap * (rowCount - 1)) / rowCount

        for (r, row) in keyViews.enumerated() {
            let totalWeight = row.reduce(0) { $0 + $1.spec.weight }
            let unit = (bounds.width - 2 * sideMargin) / totalWeight
            var x = sideMargin
            let y = top + CGFloat(r) * (rowH + rowGap)
            for kv in row {
                let w = unit * kv.spec.weight
                kv.frame = CGRect(x: x + gap / 2, y: y, width: w - gap, height: rowH)
                x += w
            }
        }
    }

    // MARK: Hit testing

    private func nearestKey(to p: CGPoint) -> KeyView? {
        var best: KeyView?
        var bestDist = CGFloat.greatestFiniteMagnitude
        for kv in keyViews.flatMap({ $0 }) where kv.spec.kind != .spacer {
            let f = kv.frame
            let dx = max(f.minX - p.x, 0, p.x - f.maxX)
            let dy = max(f.minY - p.y, 0, p.y - f.maxY)
            let d = hypot(dx, dy)
            if d < bestDist { bestDist = d; best = kv }
        }
        return best
    }

    private func letterCenters() -> [Character: CGPoint] {
        var out: [Character: CGPoint] = [:]
        for kv in keyViews.flatMap({ $0 }) where kv.spec.kind == .char && kv.spec.output.count == 1 {
            if let c = kv.spec.output.lowercased().first, c.isLetter {
                out[c] = CGPoint(x: kv.frame.midX, y: kv.frame.midY)
            }
        }
        return out
    }

    private func isSwipeStartKey(_ kv: KeyView) -> Bool {
        guard swipeEnabled, page == .letters, kv.spec.kind == .char, kv.spec.output.count == 1,
              let c = kv.spec.output.first else { return false }
        return c.isLetter
    }

    // MARK: Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            let p = t.location(in: self)
            guard let kv = nearestKey(to: p) else { continue }
            let st = TouchState(keyView: kv, start: p)
            states[t] = st
            press(st)
        }
    }

    private func press(_ st: TouchState) {
        let kv = st.keyView
        kv.isPressed = true
        delegate?.keyboardTouchDown(self, key: kv.spec)

        switch kv.spec.kind {
        case .backspace:
            delegate?.keyboard(self, didTap: kv.spec)
            st.longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self, weak st] _ in
                guard let self = self, let st = st else { return }
                st.repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.07, repeats: true) { [weak self] _ in
                    guard let self = self else { return }
                    self.delegate?.keyboard(self, didTap: kv.spec)
                }
            }
        case .char where kv.spec.hint != nil, .comma:
            let delay = Settings.longPressMs / 1000.0
            st.longPressTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self, weak st] _ in
                guard let self = self, let st = st, !st.didSwipe, !st.isSwiping, !st.isTrackpad else { return }
                if self.delegate?.keyboard(self, didLongPress: kv.spec) == true {
                    st.didLongPress = true
                }
            }
        default:
            break
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            guard let st = states[t] else { continue }
            let p = t.location(in: self)

            if st.isTrackpad { updateTrackpad(st, to: p); continue }
            if st.isSwiping { extendSwipe(st, to: p); continue }

            // Firm 3D Touch press anywhere on the keyboard -> trackpad.
            if forceTrackpadTriggered(by: t, state: st) {
                beginTrackpad(touch: t, state: st, horizontalOnly: false)
                continue
            }

            switch st.keyView.spec.kind {
            case .comma:
                if !st.didSwipe, !st.didLongPress, abs(p.y - st.start.y) > 22 {
                    st.didSwipe = true
                    st.cancelTimers()
                    st.keyView.isPressed = false
                    delegate?.keyboard(self, didSwipe: st.keyView.spec)
                }
            case .space:
                if abs(p.x - st.start.x) > 14 {
                    beginTrackpad(touch: t, state: st, horizontalOnly: true)
                }
            case .backspace:
                break
            default:
                guard !st.didLongPress, isSwipeStartKey(st.keyView) else { continue }
                let threshold = max(18, st.keyView.frame.width * 0.7)
                if hypot(p.x - st.start.x, p.y - st.start.y) > threshold {
                    beginSwipe(st, at: p)
                }
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            guard let st = states.removeValue(forKey: t) else { continue }
            st.cancelTimers()
            st.keyView.isPressed = false
            let p = t.location(in: self)

            if st.isTrackpad { endTrackpad(); continue }
            if st.isSwiping { finishSwipe(st, end: p); continue }

            let spec = st.keyView.spec
            if spec.kind == .backspace { continue }
            if st.didLongPress || st.didSwipe { continue }

            // Like iOS: a letter is decided where the finger lifts.
            var target = spec
            if spec.kind == .char, let kv = nearestKey(to: p), kv.spec.kind == .char { target = kv.spec }
            delegate?.keyboard(self, didTap: target)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            guard let st = states.removeValue(forKey: t) else { continue }
            st.cancelTimers()
            st.keyView.isPressed = false
            if st.isTrackpad { endTrackpad() }
            if st.isSwiping { fadeTrail() }
        }
    }

    // MARK: Trackpad

    private func forceTrackpadTriggered(by t: UITouch, state st: TouchState) -> Bool {
        guard forceEnabled, trackpadTouch == nil, !st.didLongPress, !st.didSwipe,
              traitCollection.forceTouchCapability == .available,
              t.maximumPossibleForce > 0 else { return false }
        return t.force / t.maximumPossibleForce >= forceThreshold
    }

    private func beginTrackpad(touch t: UITouch, state st: TouchState, horizontalOnly: Bool) {
        guard trackpadTouch == nil else { return }
        st.cancelTimers()
        st.keyView.isPressed = false
        st.isTrackpad = true
        st.horizontalOnly = horizontalOnly
        st.anchor = t.location(in: self)
        trackpadTouch = t
        UIView.animate(withDuration: 0.12) {
            self.keyViews.flatMap { $0 }.forEach { $0.alpha = 0.3 }
        }
        delegate?.keyboardTrackpadBegan(self)
    }

    private func updateTrackpad(_ st: TouchState, to p: CGPoint) {
        let stepX: CGFloat = 9, stepY: CGFloat = 26
        let nx = Int((p.x - st.anchor.x) / stepX)
        let ny = st.horizontalOnly ? 0 : Int((p.y - st.anchor.y) / stepY)
        guard nx != 0 || ny != 0 else { return }
        st.anchor.x += CGFloat(nx) * stepX
        st.anchor.y += CGFloat(ny) * stepY
        delegate?.keyboard(self, moveCursorByCharacters: nx, lines: ny)
    }

    private func endTrackpad() {
        endTrackpadAppearance()
        delegate?.keyboardTrackpadEnded(self)
    }

    private func endTrackpadAppearance() {
        trackpadTouch = nil
        UIView.animate(withDuration: 0.12) {
            self.keyViews.flatMap { $0 }.forEach { $0.alpha = 1 }
        }
    }

    // MARK: Swipe typing

    private func beginSwipe(_ st: TouchState, at p: CGPoint) {
        st.cancelTimers()
        st.keyView.isPressed = false
        st.isSwiping = true
        st.points = [st.start, p]
        trailLayer.removeAllAnimations()
        trailLayer.opacity = 1
        updateTrail(st.points)
    }

    private func extendSwipe(_ st: TouchState, to p: CGPoint) {
        if let last = st.points.last, hypot(p.x - last.x, p.y - last.y) < 2 { return }
        st.points.append(p)
        updateTrail(st.points)
    }

    private func finishSwipe(_ st: TouchState, end p: CGPoint) {
        fadeTrail()
        var pts = st.points
        if let last = pts.last, hypot(p.x - last.x, p.y - last.y) >= 2 { pts.append(p) }
        let kw = st.keyView.frame.width
        if pts.count >= 4 && SwipeDecoder.length(pts) > kw * 1.2 {
            delegate?.keyboard(self, didSwipeType: SwipeInput(points: pts, centers: letterCenters(), keyWidth: kw))
        } else if let kv = nearestKey(to: p), kv.spec.kind == .char {
            // Just a slide onto a neighbouring key.
            delegate?.keyboard(self, didTap: kv.spec)
        }
    }

    private func updateTrail(_ pts: [CGPoint]) {
        let path = UIBezierPath()
        if let first = pts.first {
            path.move(to: first)
            for p in pts.dropFirst() { path.addLine(to: p) }
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        trailLayer.path = path.cgPath
        CATransaction.commit()
    }

    private func fadeTrail() {
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = trailLayer.opacity
        fade.toValue = 0
        fade.duration = 0.3
        trailLayer.opacity = 0
        trailLayer.add(fade, forKey: "fade")
    }
}
