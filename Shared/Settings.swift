import Foundation

/// Settings shared between the host app and the keyboard extension via an App Group.
enum Settings {
    static let groupID = "group.io.brunintech.bruninboard"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: groupID) ?? .standard
    }

    /// Hold duration (ms) before a letter key emits its secondary symbol.
    static var longPressMs: Double {
        get { defaults.object(forKey: "longPressMs") as? Double ?? 300 }
        set { defaults.set(newValue, forKey: "longPressMs") }
    }

    static var hapticsEnabled: Bool {
        get { defaults.object(forKey: "hapticsEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "hapticsEnabled") }
    }

    /// 0.0 ... 1.0
    static var hapticIntensity: Double {
        get { defaults.object(forKey: "hapticIntensity") as? Double ?? 0.6 }
        set { defaults.set(newValue, forKey: "hapticIntensity") }
    }

    static var keyClickSound: Bool {
        get { defaults.object(forKey: "keyClickSound") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "keyClickSound") }
    }

    static var autoCapitalize: Bool {
        get { defaults.object(forKey: "autoCapitalize") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "autoCapitalize") }
    }

    static var autoCorrect: Bool {
        get { defaults.object(forKey: "autoCorrect") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "autoCorrect") }
    }

    /// Language codes for UITextChecker, e.g. "en_US", "pt_BR".
    static var languages: [String] {
        get { defaults.stringArray(forKey: "languages") ?? ["en_US", "pt_BR"] }
        set { defaults.set(newValue, forKey: "languages") }
    }

    /// MyMemory language codes: en, pt, es, fr, de, it ...
    static var translateSource: String {
        get { defaults.string(forKey: "translateSource") ?? "en" }
        set { defaults.set(newValue, forKey: "translateSource") }
    }

    static var translateTarget: String {
        get { defaults.string(forKey: "translateTarget") ?? "pt" }
        set { defaults.set(newValue, forKey: "translateTarget") }
    }

    /// Multiplier for the key area height (the top bar is added on top of it).
    static var keyboardHeightScale: Double {
        get { defaults.object(forKey: "keyboardHeightScale") as? Double ?? 1.0 }
        set { defaults.set(newValue, forKey: "keyboardHeightScale") }
    }

    /// Adds a trailing space after , . ! ? when typing normally.
    static var autoSpacePunctuation: Bool {
        get { defaults.object(forKey: "autoSpacePunctuation") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "autoSpacePunctuation") }
    }

    static var swipeTyping: Bool {
        get { defaults.object(forKey: "swipeTyping") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "swipeTyping") }
    }

    /// 3D Touch trackpad on iPhone 7 / 7 Plus.
    static var forceTrackpad: Bool {
        get { defaults.object(forKey: "forceTrackpad") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "forceTrackpad") }
    }

    /// Fraction of maximumPossibleForce that counts as a firm press (0.2 ... 0.8).
    static var forceThreshold: Double {
        get { defaults.object(forKey: "forceThreshold") as? Double ?? 0.45 }
        set { defaults.set(newValue, forKey: "forceThreshold") }
    }

    /// ThemePreset raw value: auto, gboardDark, oled, light, custom.
    static var themePreset: String {
        get { defaults.string(forKey: "themePreset") ?? "auto" }
        set { defaults.set(newValue, forKey: "themePreset") }
    }

    static var customBackground: String {
        get { defaults.string(forKey: "customBackground") ?? "#0A0A0A" }
        set { defaults.set(newValue, forKey: "customBackground") }
    }

    static var customKey: String {
        get { defaults.string(forKey: "customKey") ?? "#3D3D3D" }
        set { defaults.set(newValue, forKey: "customKey") }
    }

    static var customAccent: String {
        get { defaults.string(forKey: "customAccent") ?? "#7DD6C7" }
        set { defaults.set(newValue, forKey: "customAccent") }
    }

    static var showTopBarOnLaunch: Bool {
        get { defaults.object(forKey: "showTopBarOnLaunch") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "showTopBarOnLaunch") }
    }
}
