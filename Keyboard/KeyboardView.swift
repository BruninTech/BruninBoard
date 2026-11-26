import UIKit

enum ShiftState { case off, once, caps }

protocol KeyboardViewDelegate: AnyObject {
    func keyboardTouchDown(_ kb: KeyboardView, key: KeySpec)
    func keyboard(_ kb: KeyboardView, didTap key: KeySpec)
    /// Return true if the long press produced output (then the tap on release is suppressed).
    func keyboard(_ kb: KeyboardView, didLongPress key: KeySpec) -> Bool
    func keyboard(_ kb: KeyboardView, didSwipeUp key: KeySpec)
}

/// Draws the key grid and owns all touch handling, so hit-testing can be forgiving
/// (nearest key wins, even in the gaps) and a future touch model has a single place to live.
final class KeyboardView: UIView {
    weak var delegate: KeyboardViewDelegate?

    private(set) var page: Page = .letters
    private var keyViews: [[KeyView]] = []

    var shiftState: ShiftState = .off { didSet { applyCase() } }

    private final class TouchState {
        var keyView: KeyView
        let start: CGPoint
        var longPressTimer: Timer?
        var repeatTimer: Timer?
        var didLongPress = false
        var didSwipe = false
        init(keyView: KeyView, start: CGPoint) { self.keyView = keyView; self.start = start }
        func cancelTimers() {
            longPressTimer?.invalidate(); longPressTimer = nil
            repeatTimer?.invalidate(); repeatTimer = nil
        }
    }
    private var states: [UITouch: TouchState] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = Theme.background
        setPage(.letters)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: Pages

    func setPage(_ newPage: Page) {
        states.values.forEach { $0.cancelTimers() }
        states.removeAll()
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
        case .char where kv.spec.hint != nil, .emoji:
            let delay = Settings.longPressMs / 1000.0
            st.longPressTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self, weak st] _ in
                guard let self = self, let st = st, !st.didSwipe else { return }
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
            let kind = st.keyView.spec.kind

            if kind == .emoji {
                if !st.didSwipe, !st.didLongPress, st.start.y - p.y > 22 {
                    st.didSwipe = true
                    st.cancelTimers()
                    delegate?.keyboard(self, didSwipeUp: st.keyView.spec)
                }
                continue
            }
            // Finger slid onto another key before a long press fired: retarget like iOS does.
            if kind != .backspace, !st.didLongPress, let kv = nearestKey(to: p), kv !== st.keyView {
                st.cancelTimers()
                st.keyView.isPressed = false
                st.keyView = kv
                press(st)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            guard let st = states.removeValue(forKey: t) else { continue }
            st.cancelTimers()
            st.keyView.isPressed = false
            let spec = st.keyView.spec
            if spec.kind == .backspace { continue }
            if st.didLongPress || st.didSwipe { continue }
            delegate?.keyboard(self, didTap: spec)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            guard let st = states.removeValue(forKey: t) else { continue }
            st.cancelTimers()
            st.keyView.isPressed = false
        }
    }
}
