import UIKit

enum Page { case letters, symbols1, symbols2 }

enum KeyKind: Equatable {
    case char
    case shift
    case backspace
    case page(Page)
    case space
    case ret
    /// Multi-function key left of the space bar:
    /// tap = ",", long-press = next keyboard, swipe up/down = toggle the top bar.
    case comma
    case spacer
}

enum KeyStyle { case normal, special, accent }

struct KeySpec {
    var kind: KeyKind
    var label: String = ""
    var output: String = ""
    var hint: String? = nil
    var weight: CGFloat = 1

    var style: KeyStyle {
        switch kind {
        case .char, .space, .comma: return .normal
        case .ret: return .accent
        default: return .special
        }
    }

    static func char(_ c: String, hint: String? = nil, weight: CGFloat = 1) -> KeySpec {
        KeySpec(kind: .char, label: c, output: c, hint: hint, weight: weight)
    }
    static func spacer(_ w: CGFloat) -> KeySpec { KeySpec(kind: .spacer, weight: w) }
    static func comma() -> KeySpec { KeySpec(kind: .comma, label: ",", output: ",") }
}

enum Layouts {
    private static func chars(_ s: String, hints: [String?] = []) -> [KeySpec] {
        s.enumerated().map { i, ch in
            .char(String(ch), hint: i < hints.count ? hints[i] : nil)
        }
    }

    /// "EN · PT" style label for the space bar.
    static func spaceLabel() -> String {
        Settings.languages
            .map { String($0.prefix(2)).uppercased() }
            .joined(separator: " · ")
    }

    private static func space() -> KeySpec {
        KeySpec(kind: .space, label: spaceLabel(), output: " ", weight: 5)
    }

    private static func ret() -> KeySpec {
        KeySpec(kind: .ret, label: "↵", output: "\n", weight: 1.5)
    }

    static func rows(for page: Page) -> [[KeySpec]] {
        let backspace = KeySpec(kind: .backspace, label: "⌫", weight: 1.5)
        switch page {
        case .letters:
            let nums = (1...9).map { String($0) } + ["0"]
            let r1 = chars("qwertyuiop", hints: nums)
            let r2 = [KeySpec.spacer(0.5)]
                + chars("asdfghjkl", hints: ["@", "#", "$", "-", "&", "_", "+", "(", ")"])
                + [KeySpec.spacer(0.5)]
            let r3 = [KeySpec(kind: .shift, label: "⇧", weight: 1.5)]
                + chars("zxcvbnm", hints: ["*", "\"", "'", ":", ";", "!", "?"])
                + [backspace]
            let r4: [KeySpec] = [
                KeySpec(kind: .page(.symbols1), label: "?123", weight: 1.5),
                .comma(),
                space(),
                .char("."),
                ret()
            ]
            return [r1, r2, r3, r4]

        case .symbols1:
            let r1 = chars("1234567890")
            let r2 = chars("@#$_&-+()/")
            let r3 = [KeySpec(kind: .page(.symbols2), label: "=\\<", weight: 1.5)]
                + chars("*\"':;!?") + [backspace]
            let r4: [KeySpec] = [
                KeySpec(kind: .page(.letters), label: "ABC", weight: 1.5),
                .comma(),
                space(),
                .char("."),
                ret()
            ]
            return [r1, r2, r3, r4]

        case .symbols2:
            let r1 = chars("~`|•√π÷×§Δ")
            let r2 = chars("£¢€¥^°={}\\")
            let r3 = [KeySpec(kind: .page(.symbols1), label: "?123", weight: 1.5)]
                + chars("%©®™✓[]") + [backspace]
            let r4: [KeySpec] = [
                KeySpec(kind: .page(.letters), label: "ABC", weight: 1.5),
                .char("<"),
                space(),
                .char(">"),
                ret()
            ]
            return [r1, r2, r3, r4]
        }
    }
}
