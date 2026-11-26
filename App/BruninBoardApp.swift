import SwiftUI

@main
struct BruninBoardApp: App {
    var body: some Scene {
        WindowGroup { SettingsView() }
    }
}

struct SettingsView: View {
    @State private var longPress = Settings.longPressMs
    @State private var haptics = Settings.hapticsEnabled
    @State private var intensity = Settings.hapticIntensity
    @State private var click = Settings.keyClickSound
    @State private var autoCap = Settings.autoCapitalize
    @State private var autoCorrect = Settings.autoCorrect
    @State private var topBar = Settings.showTopBarOnLaunch
    @State private var trFrom = Settings.translateSource
    @State private var trTo = Settings.translateTarget
    @State private var testText = ""

    private static let langs = ["en", "pt", "es", "fr", "de", "it", "ja", "ru"]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Setup"), footer: Text("Settings > General > Keyboard > Keyboards > Add New Keyboard > BruninBoard, then enable Allow Full Access.")) {
                    EmptyView()
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
                    Toggle("Show top bar by default", isOn: $topBar)
                        .onChange(of: topBar) { Settings.showTopBarOnLaunch = $0 }
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
