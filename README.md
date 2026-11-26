# BruninBoard

Gboard-style iOS keyboard extension + settings app. iOS 15+, built for iPhone 7 / 7 Plus, installed through TrollStore.

## Build (no Mac needed)
1. Push this folder to a GitHub repo (the folder contents are the repo root).
2. The `Build IPA` workflow (macOS runner) runs XcodeGen, builds unsigned, `ldid`-signs the app and the
   extension with their App Group entitlements and uploads `BruninBoard.ipa` as an artifact.
3. Download the IPA, open it with TrollStore.
4. Settings > General > Keyboard > Keyboards > Add New Keyboard > BruninBoard, then enable **Allow Full Access**
   (needed for haptics, clipboard and translation).

## Layout
- `Shared/` App Group settings and the theme palette, used by both targets
- `App/` SwiftUI settings + `Assets.xcassets` (placeholder app icon: replace `AppIcon-1024.png`)
- `Keyboard/` extension: layouts, key rendering, touch handling, top bar, cursor pad, suggestions,
  swipe decoder, cursor model, translator
- `Keyboard/Resources/words_en.txt`, `words_pt.txt` 25k-word frequency lists for swipe typing

## Gestures
- Hold a letter: its small top-right symbol is typed (delay set in the app)
- Comma key: tap = `,`, hold = next keyboard (emoji), swipe up or down = show/hide the top bar
- Swipe across the letters to type a word. After a swipe the 3 suggestion slots (top bar) hold alternatives;
  backspace right after a swipe removes the whole word
- Press firmly anywhere (3D Touch) or swipe sideways on the space bar: trackpad mode (keys dim, cursor follows
  the finger; the space bar fallback is horizontal only)
- Top bar grid button: switch between suggestions and tools (cursor pad, settings, translate)

## Punctuation
- `, . ! ?` get a trailing space (not after digits like 3.14, not in URL/email fields, not mid-text)
- Typing another `. , ! ?` or `) ] }` right after an auto-space replaces that space; space right after an
  auto-space is ignored; return removes it; backspace over it removes just the space
- Autocorrect is applied before space, newline and `. , ! ? ; :` and closers, never before `@ _ - + /`

## Tunables
- `SwipeDecoder.swift`: `lengthWeight`, `frequencyWeight` (how much word frequency beats path accuracy)
- `KeyboardView.swift`: trackpad step sizes (`stepX`, `stepY`), swipe start threshold

## Known limits
- Select / Select all are drawn but inactive: the public keyboard API cannot create a text selection
- Vertical cursor moves are estimated (about view-width/10.5 characters per visual line); hard line breaks are exact
- Swipe typing only knows en/pt word lists plus contact names from the system lexicon
- Word lists generated with the `wordfreq` Python package (data CC BY-SA 4.0)
