# BruninBoard

A Gboard-style custom keyboard for iOS, built for small, older iPhones. Hold-for-symbol, swipe typing, a
cursor trackpad, a utility bar and themes, all in a keyboard extension you can sideload.

Targets **iOS 15+**, tuned for the **iPhone 7 (4.7")** and **iPhone 7 Plus (5.5")**.

## What it is

BruninBoard is an iOS keyboard extension (Swift / UIKit) plus a small SwiftUI companion app that holds its
settings. The two share settings through an App Group.

**Typing**
- Gboard-like QWERTY with two symbol pages, laid out to match Android
- **Hold-for-symbol**: hold any letter to type the small symbol in its corner (delay is adjustable)
- **Swipe typing** with a trail and a **live preview** of the best match while your finger is still down
- Suggestion strip: the literal word you typed, the best correction (highlighted), and the next prediction.
  Tap the left slot to keep your spelling and stop autocorrect
- Autocorrect and predictions on `UITextChecker` and `UILexicon`; auto-capitalize, double-space period
- Smart punctuation: a space is added after `, . ! ?`, with sensible exceptions (`3.14`, URLs, mid-text)

**Gestures and tools**
- **Comma key**: tap for `,`, hold to switch to the next keyboard (emoji), swipe up or down to show or hide the top bar
- **Trackpad**: press firmly anywhere (3D Touch) or swipe sideways on the space bar to move the cursor
- **Text editing pad**: arrows, line start/end, copy, paste, backspace
- **Quick translate** of the current line through the free MyMemory API (no key)
- Undo for the last autocorrect, suggestion or swiped word

**Settings (companion app)**
- Keyboard height, long-press delay, haptic intensity, key click sound
- Typing languages (English by default; Portuguese, Spanish, French, German, Italian available)
- Themes: Automatic, Gboard Dark, Pitch Black OLED, Light, or fully custom colours
- Toggles for autocorrect, auto-space, swipe typing and the 3D Touch trackpad

## Why

I wanted Android Gboard's best features (hold-for-symbol, swipe typing, the cursor tools) on a compact iPhone,
and the stock iOS keyboard on a 4.7" screen wastes space and lacks them. I can't afford a better phone, so I made
this one better. The iPhone 7 Plus is used with Re:Scale 2 for extra screen real estate, which is why the layout
is built to work on both sizes.

It is distributed through sideloading (TrollStore), not the App Store, so it doesn't have to follow App Store
review rules.

## How to build and install

### Option A: GitHub Actions + TrollStore (no Mac needed)
1. Fork or push this repo to your GitHub account.
2. Open the **Actions** tab and run **Build IPA** (it also runs on every push). It uses XcodeGen to generate the
   project, builds unsigned, and `ldid`-signs the app and the extension with their App Group entitlements.
3. Download the `BruninBoard-ipa` artifact and unzip it to get `BruninBoard.ipa`.
4. Open the IPA with **TrollStore** to install it (reinstall over the old version when updating).
5. Enable the keyboard, see [Enable the keyboard](#enable-the-keyboard).

### Option B: Xcode
Requirements: a Mac with Xcode 15 or newer, [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`), and an Apple ID for signing.

1. `git clone` the repo and run `xcodegen generate` in its root, then open `BruninBoard.xcodeproj`.
2. **Bundle IDs**: change `io.brunintech.bruninboard` (app) and `io.brunintech.bruninboard.keyboard` (extension)
   to ones you own, in `project.yml`, and regenerate.
3. **App Group**: in *Signing & Capabilities*, add the **App Groups** capability to **both** targets with the
   same group ID. If you use your own ID, also change it in:
   - `Shared/Settings.swift` (`Settings.groupID`)
   - the `com.apple.security.application-groups` entries in `project.yml`
4. Pick your **Team** for both targets and run the `BruninBoard` scheme on your device.
   (A free Apple ID can't use App Groups on every account type; if signing refuses, use Option A.)

### Enable the keyboard
1. **Settings > General > Keyboard > Keyboards > Add New Keyboard... > BruninBoard**
2. Tap **BruninBoard** in that list and turn on **Allow Full Access**.
3. Switch to it with the globe key (or the keyboard's comma key if it's your only other keyboard).

Full Access is needed for haptics, reading the clipboard (Paste in the editing pad) and Quick translate. The
keyboard does not log what you type. The only network request is Quick translate, which sends the current line to
the MyMemory API when you tap it.

## Project layout
```
project.yml                XcodeGen config (app + keyboard extension, entitlements)
.github/workflows/         CI that builds the TrollStore IPA
Shared/                    App Group settings, theme palette (both targets)
App/                       SwiftUI settings app + Assets.xcassets (app icon)
Keyboard/                  extension: layouts, touch handling, top bar, suggestions,
                           swipe decoder, cursor model, translator
Keyboard/Resources/        word-frequency lists used by swipe typing
```

## Known limits
- Select / Select all in the editing pad are drawn but inactive: the public keyboard API cannot create a selection
- Vertical cursor moves are estimated (iOS exposes no line layout); hard line breaks are exact
- iOS keeps password fields on the system keyboard, and extensions have a small memory budget
- Autocorrect uses iOS's `UITextChecker`, so its quality depends on the dictionaries installed on the device

## Tuning
- `Keyboard/SwipeDecoder.swift`: `lengthWeight`, `frequencyWeight` (path accuracy vs word frequency)
- `Keyboard/KeyboardView.swift`: trackpad step sizes, swipe start threshold

## Credits
- Word lists generated with the [`wordfreq`](https://github.com/rspeer/wordfreq) Python package (data licensed CC BY-SA 4.0)
- Translation by the [MyMemory](https://mymemory.translated.net) API
- Inspired by Google's Gboard and Microsoft SwiftKey; not affiliated with either
