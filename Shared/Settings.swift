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

    static var showTopBarOnLaunch: Bool {
        get { defaults.object(forKey: "showTopBarOnLaunch") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "showTopBarOnLaunch") }
    }
}
