# BruninBoard

Gboard-style iOS keyboard extension + settings app. iOS 15+, built for iPhone 7 / 7 Plus, installed through TrollStore.

## Build (no Mac needed)
1. Push this folder to a GitHub repo.
2. The `Build IPA` workflow (macOS runner) runs XcodeGen, builds unsigned, then `ldid`-signs the app and the
   extension with their App Group entitlements and uploads `BruninBoard.ipa` as an artifact.
3. Download the IPA, open it with TrollStore.
4. Settings > General > Keyboard > Keyboards > Add New Keyboard > BruninBoard, then enable **Allow Full Access**
   (needed for haptics, clipboard and translation).

## Layout
- `Shared/Settings.swift` App Group UserDefaults shared by app and keyboard
- `App/` SwiftUI settings (long-press delay, haptics, translate languages, test field)
- `Keyboard/` extension: layouts, key rendering, touch handling, top bar, cursor pad, suggestions, translator

## Gestures
- Hold a letter: its small top-right symbol is typed (delay set in the app)
- Swipe up on the smiley key: show/hide the top bar. Tap: next keyboard (emoji). Hold: comma
- Top bar grid button: switch between suggestions and tools (cursor pad, clipboard, settings, translate)

## Known limits
- Select / Select all are drawn but inactive: the public keyboard API cannot create a text selection
- Cursor up/down move by about one line of characters (no API for visual lines)
- No key-preview popup yet; pressed keys just highlight
