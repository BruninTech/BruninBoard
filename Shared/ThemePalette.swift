import UIKit

enum ThemePreset: String, CaseIterable, Identifiable {
    case auto, gboardDark, oled, light, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "Automatic (follows system)"
        case .gboardDark: return "Gboard Dark"
        case .oled: return "Pitch Black OLED"
        case .light: return "Light"
        case .custom: return "Custom"
        }
    }
}

/// Every colour the keyboard draws with. Shared so the settings app can preview it.
struct ThemePalette {
    var background: UIColor
    var key: UIColor
    var keyPressed: UIColor
    var special: UIColor
    var specialPressed: UIColor
    var accent: UIColor
    var accentPressed: UIColor
    var text: UIColor            // on normal keys
    var specialText: UIColor     // on special keys
    var onBackground: UIColor    // top bar, titles
    var accentGlyph: UIColor     // on the return key
}

extension ThemePalette {
    static let defaultAccent = UIColor(red: 0.49, green: 0.84, blue: 0.78, alpha: 1)

    /// Derives a full palette from three base colours.
    static func make(background: UIColor, key: UIColor, accent: UIColor) -> ThemePalette {
        let dark = background.luminance < 0.5
        let special = dark ? UIColor.mix(background, key, 0.5) : background.shifted(-0.14)
        let keyPressed = dark ? key.shifted(0.13) : key.shifted(-0.15)
        func ink(on c: UIColor) -> UIColor { c.luminance < 0.5 ? .white : .black }
        return ThemePalette(
            background: background,
            key: key,
            keyPressed: keyPressed,
            special: special,
            specialPressed: special.shifted(0.17),
            accent: accent,
            accentPressed: accent.shifted(-0.11),
            text: ink(on: key),
            specialText: ink(on: special),
            onBackground: ink(on: background),
            accentGlyph: accent.luminance < 0.5
                ? .white : UIColor(red: 0.04, green: 0.2, blue: 0.18, alpha: 1))
    }

    static let gboardDark = make(background: UIColor(white: 0.04, alpha: 1),
                                 key: UIColor(white: 0.24, alpha: 1),
                                 accent: defaultAccent)
    static let oled = make(background: .black,
                           key: UIColor(white: 0.12, alpha: 1),
                           accent: defaultAccent)
    static let light = make(background: UIColor(red: 0.82, green: 0.84, blue: 0.86, alpha: 1),
                            key: .white,
                            accent: defaultAccent)

    private static func dyn(_ dark: UIColor, _ light: UIColor) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? dark : light }
    }

    static func dynamic(dark d: ThemePalette, light l: ThemePalette) -> ThemePalette {
        ThemePalette(
            background: dyn(d.background, l.background),
            key: dyn(d.key, l.key),
            keyPressed: dyn(d.keyPressed, l.keyPressed),
            special: dyn(d.special, l.special),
            specialPressed: dyn(d.specialPressed, l.specialPressed),
            accent: dyn(d.accent, l.accent),
            accentPressed: dyn(d.accentPressed, l.accentPressed),
            text: dyn(d.text, l.text),
            specialText: dyn(d.specialText, l.specialText),
            onBackground: dyn(d.onBackground, l.onBackground),
            accentGlyph: dyn(d.accentGlyph, l.accentGlyph))
    }

    static func resolve(preset: ThemePreset, customBackground: UIColor,
                        customKey: UIColor, customAccent: UIColor) -> ThemePalette {
        switch preset {
        case .gboardDark: return gboardDark
        case .oled: return oled
        case .light: return light
        case .custom: return make(background: customBackground, key: customKey, accent: customAccent)
        case .auto: return dynamic(dark: gboardDark, light: light)
        }
    }

    /// The palette selected in the settings app.
    static func current() -> ThemePalette {
        resolve(preset: ThemePreset(rawValue: Settings.themePreset) ?? .auto,
                customBackground: UIColor(hex: Settings.customBackground),
                customKey: UIColor(hex: Settings.customKey),
                customAccent: UIColor(hex: Settings.customAccent))
    }
}

extension UIColor {
    convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        if s.count != 6 { s = "000000" }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(red: CGFloat((v >> 16) & 0xFF) / 255,
                  green: CGFloat((v >> 8) & 0xFF) / 255,
                  blue: CGFloat(v & 0xFF) / 255,
                  alpha: 1)
    }

    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X",
                      Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }

    /// Perceived brightness 0...1 (only meaningful for non-dynamic colours).
    var luminance: CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.299 * r + 0.587 * g + 0.114 * b
    }

    /// Adds `delta` to every channel, clamped to 0...1.
    func shifted(_ delta: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        func c(_ v: CGFloat) -> CGFloat { min(max(v + delta, 0), 1) }
        return UIColor(red: c(r), green: c(g), blue: c(b), alpha: a)
    }

    static func mix(_ x: UIColor, _ y: UIColor, _ t: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        x.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        y.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t,
                       blue: b1 + (b2 - b1) * t, alpha: 1)
    }
}
