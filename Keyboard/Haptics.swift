import UIKit

/// Taptic feedback driven by the shared settings. Needs Full Access (RequestsOpenAccess).
final class Haptics {
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)

    func prepare() {
        guard Settings.hapticsEnabled else { return }
        light.prepare()
    }

    func tap() {
        guard Settings.hapticsEnabled else { return }
        light.impactOccurred(intensity: CGFloat(Settings.hapticIntensity))
        light.prepare()
    }

    func longPress() {
        guard Settings.hapticsEnabled else { return }
        medium.impactOccurred(intensity: CGFloat(min(1.0, Settings.hapticIntensity + 0.2)))
        medium.prepare()
    }

    func click() {
        if Settings.keyClickSound { UIDevice.current.playInputClick() }
    }
}

/// Root input view. Conforming to UIInputViewAudioFeedback lets playInputClick() work.
final class ClickInputView: UIInputView, UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}
