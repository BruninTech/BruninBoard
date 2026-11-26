import SwiftUI

@main
struct BruninBoardApp: App {
    var body: some Scene {
        WindowGroup { SettingsView() }
    }
}

struct SettingsView: View {
    @State private var heightScale = Settings.keyboardHeightScale
    @State private var longPress = Settings.longPressMs
    @State private var haptics = Settings.hapticsEnabled
    @State private var intensity = Settings.hapticIntensity
    @State private var click = Settings.keyClickSound
    @State private var autoCap = Settings.autoCapitalize
    @State private var autoCorrect = Settings.autoCorrect
    @State private var autoSpace = Settings.autoSpacePunctuation
    @State private var topBar = Settings.showTopBarOnLaunch
    @State private var swipeTyping = Settings.swipeTyping
    @State private var forceTrackpad = Settings.forceTrackpad
    @State private var forceThreshold = Settings.forceThreshold
    @State private var preset = ThemePreset(rawValue: Settings.themePreset) ?? .auto
    @State private var customBg = Color(UIColor(hex: Settings.customBackground))
    @State private var customKey = Color(UIColor(hex: Settings.customKey))
    @State private var customAccent = Color(UIColor(hex: Settings.customAccent))
    @State private var trFrom = Settings.translateSource
    @State private var trTo = Settings.translateTarget
    @State private var testText = ""

    private static let langs = ["en", "pt", "es", "fr", "de", "it", "ja", "ru"]

    private var previewPalette: ThemePalette {
        ThemePalette.resolve(preset: preset,
                             customBackground: UIColor(customBg),
                             customKey: UIColor(customKey),
                             customAccent: UIColor(customAccent))
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Setup"), footer: Text("Settings > General > Keyboard > Keyboards > Add New Keyboard > BruninBoard, then enable Allow Full Access.")) {
                    EmptyView()
                }

                Section(header: Text("Size"), footer: Text("Scales the key area. The top bar adds 40 pt on top when shown.")) {
                    VStack(alignment: .leading) {
                        Text("Keyboard height: \(Int((heightScale * 100).rounded()))%")
                        Slider(value: $heightScale, in: 0.8...1.3, step: 0.05)
                            .onChange(of: heightScale) { Settings.keyboardHeightScale = $0 }
                    }
                }

                Section(header: Text("Long-press")) {
                    VStack(alignment: .leading) {
                        Text("Delay: \(Int(longPress)) ms")
                        Slider(value: $longPress, in: 150...800, step: 10)
                            .onChange(of: longPress) { Settings.longPressMs = $0 }
                    }
                }

                Section(header: Text("Haptics")) {
                    Toggle("Vibration on keypress", isOn: $haptics)
                        .onChange(of: haptics) { Settings.hapticsEnabled = $0 }
                    VStack(alignment: .leading) {
                        Text("Intensity: \(Int(intensity * 100))%")
                        Slider(value: $intensity, in: 0.1...1.0, step: 0.05)
                            .onChange(of: intensity) { Settings.hapticIntensity = $0 }
                    }
                    .disabled(!haptics)
                    Toggle("Key click sound", isOn: $click)
                        .onChange(of: click) { Settings.keyClickSound = $0 }
                }

                Section(header: Text("Typing")) {
                    Toggle("Auto-capitalize", isOn: $autoCap)
                        .onChange(of: autoCap) { Settings.autoCapitalize = $0 }
                    Toggle("Auto-correct", isOn: $autoCorrect)
                        .onChange(of: autoCorrect) { Settings.autoCorrect = $0 }
                    Toggle("Space after , . ! ?", isOn: $autoSpace)
                        .onChange(of: autoSpace) { Settings.autoSpacePunctuation = $0 }
                    Toggle("Show top bar by default", isOn: $topBar)
                        .onChange(of: topBar) { Settings.showTopBarOnLaunch = $0 }
                }

                Section(header: Text("Gestures"),
                        footer: Text("Press firmly anywhere on the keys (3D Touch) to move the cursor like a trackpad. Swiping sideways on the space bar does the same on any device. Lower the pressure value if it is hard to trigger, raise it if it triggers while typing.")) {
                    Toggle("Swipe typing", isOn: $swipeTyping)
                        .onChange(of: swipeTyping) { Settings.swipeTyping = $0 }
                    Toggle("3D Touch trackpad", isOn: $forceTrackpad)
                        .onChange(of: forceTrackpad) { Settings.forceTrackpad = $0 }
                    VStack(alignment: .leading) {
                        Text("Press pressure: \(Int(forceThreshold * 100))%")
                        Slider(value: $forceThreshold, in: 0.2...0.8, step: 0.05)
                            .onChange(of: forceThreshold) { Settings.forceThreshold = $0 }
                    }
                    .disabled(!forceTrackpad)
                }

                Section(header: Text("Theme")) {
                    Picker("Preset", selection: $preset) {
                        ForEach(ThemePreset.allCases) { p in
                            Text(p.title).tag(p)
                        }
                    }
                    .onChange(of: preset) { Settings.themePreset = $0.rawValue }

                    if preset == .custom {
                        ColorPicker("Keyboard background", selection: $customBg, supportsOpacity: false)
                            .onChange(of: customBg) { Settings.customBackground = UIColor($0).hexString }
                        ColorPicker("Key color", selection: $customKey, supportsOpacity: false)
                            .onChange(of: customKey) { Settings.customKey = UIColor($0).hexString }
                        ColorPicker("Enter key color", selection: $customAccent, supportsOpacity: false)
                            .onChange(of: customAccent) { Settings.customAccent = UIColor($0).hexString }
                    }

                    ThemePreview(palette: previewPalette)
                        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                }

                Section(header: Text("Quick translate"), footer: Text("Translates the current line using the free MyMemory API. Needs Allow Full Access.")) {
                    Picker("From", selection: $trFrom) {
                        ForEach(Self.langs, id: \.self) { Text($0.uppercased()).tag($0) }
                    }
                    .onChange(of: trFrom) { Settings.translateSource = $0 }
                    Picker("To", selection: $trTo) {
                        ForEach(Self.langs, id: \.self) { Text($0.uppercased()).tag($0) }
                    }
                    .onChange(of: trTo) { Settings.translateTarget = $0 }
                }

                Section(header: Text("Test field")) {
                    TextField("Switch to BruninBoard and type here", text: $testText)
                }
            }
            .navigationTitle("BruninBoard")
        }
        .navigationViewStyle(.stack)
    }
}

/// A tiny keyboard drawn with the selected palette.
struct ThemePreview: View {
    let palette: ThemePalette

    private let rows = [["q", "w", "e", "r", "t", "y", "u"], ["a", "s", "d", "f", "g", "h"]]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 5) {
                    ForEach(row, id: \.self) { k in
                        Text(k)
                            .font(.system(size: 17))
                            .foregroundColor(Color(palette.text))
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .background(Color(palette.key))
                            .cornerRadius(6)
                    }
                }
            }
            HStack(spacing: 5) {
                Text("?123")
                    .font(.system(size: 13))
                    .foregroundColor(Color(palette.specialText))
                    .frame(width: 52, height: 34)
                    .background(Color(palette.special))
                    .cornerRadius(6)
                Text("EN · PT")
                    .font(.system(size: 11))
                    .foregroundColor(Color(palette.text))
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .background(Color(palette.key))
                    .cornerRadius(6)
                Image(systemName: "return")
                    .foregroundColor(Color(palette.accentGlyph))
                    .frame(width: 52, height: 34)
                    .background(Color(palette.accent))
                    .cornerRadius(6)
            }
        }
        .padding(8)
        .background(Color(palette.background))
        .cornerRadius(10)
    }
}
