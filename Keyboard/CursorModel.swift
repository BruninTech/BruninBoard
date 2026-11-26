import Foundation

/// A snapshot of the text around the cursor, used to move the cursor in 2D.
///
/// `adjustTextPosition(byCharacterOffset:)` is asynchronous and `documentContext*` can lag behind it, so
/// during a trackpad session we keep our own position inside this snapshot and only send the net offset.
/// The public API exposes no layout information, so a "visual line" is estimated as `charsPerLine`
/// characters; hard line breaks ("\n") are exact.
struct CursorModel {
    private let text: [Character]
    private(set) var pos: Int
    private let cpl: Int

    init(before: String, after: String, charsPerLine: Int) {
        text = Array(before + after)
        pos = before.count
        cpl = max(8, charsPerLine)
    }

    // MARK: Public moves (each returns the offset to send to adjustTextPosition, in UTF-16 units)

    mutating func move(chars: Int, lines: Int) -> Int {
        let old = pos
        if lines < 0 { for _ in 0..<(-lines) { moveUp() } }
        if lines > 0 { for _ in 0..<lines { moveDown() } }
        pos = min(max(pos + chars, 0), text.count)
        return offset(from: old, to: pos)
    }

    mutating func moveToLineStart() -> Int {
        let old = pos
        pos = lineStart(at: pos)
        return offset(from: old, to: pos)
    }

    mutating func moveToLineEnd() -> Int {
        let old = pos
        pos = lineEnd(at: pos)
        return offset(from: old, to: pos)
    }

    // MARK: Lines

    private func lineStart(at p: Int) -> Int {
        var i = min(p, text.count)
        while i > 0 && text[i - 1] != "\n" { i -= 1 }
        return i
    }

    private func lineEnd(at p: Int) -> Int {
        var j = min(p, text.count)
        while j < text.count && text[j] != "\n" { j += 1 }
        return j
    }

    private mutating func moveUp() {
        let start = lineStart(at: pos)
        let col = pos - start
        let seg = col / cpl, off = col % cpl
        if seg > 0 {                       // previous visual row of the same paragraph
            pos -= cpl
            return
        }
        guard start > 0 else { pos = 0; return }
        let prevEnd = start - 1            // the "\n" before this paragraph
        let prevStart = lineStart(at: prevEnd)
        let prevLen = prevEnd - prevStart
        let lastSeg = prevLen / cpl
        pos = prevStart + min(lastSeg * cpl + off, prevLen)
    }

    private mutating func moveDown() {
        let start = lineStart(at: pos)
        let end = lineEnd(at: pos)
        let len = end - start
        let col = pos - start
        let seg = col / cpl, off = col % cpl
        if (seg + 1) * cpl < len {         // next visual row of the same paragraph
            pos = start + min((seg + 1) * cpl + off, len)
            return
        }
        if end < text.count {              // next paragraph
            let nextStart = end + 1
            let nextLen = lineEnd(at: nextStart) - nextStart
            pos = nextStart + min(off, nextLen)
        } else {
            pos = text.count
        }
    }

    private func offset(from a: Int, to b: Int) -> Int {
        if a == b { return 0 }
        let lo = min(a, b), hi = max(a, b)
        let n = String(text[lo..<hi]).utf16.count
        return b > a ? n : -n
    }
}
