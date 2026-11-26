import UIKit

/// Suggestions + autocorrect built on UITextChecker and the supplementary lexicon (UILexicon).
final class SuggestionEngine {
    private let checker = UITextChecker()
    private var shortcuts: [String: String] = [:]     // lowercased shortcut -> expansion
    private var lexiconWords: Set<String> = []         // contact names etc.

    private var languages: [String] {
        let available = UITextChecker.availableLanguages
        let wanted = Settings.languages.filter { available.contains($0) }
        if !wanted.isEmpty { return wanted }
        // availableLanguages sometimes uses dashes (pt-BR) instead of underscores.
        let dashed = Settings.languages
            .map { $0.replacingOccurrences(of: "_", with: "-") }
            .filter { available.contains($0) }
        return dashed.isEmpty ? [available.first ?? "en_US"] : dashed
    }

    // MARK: Lexicon

    func load(_ lexicon: UILexicon) {
        for e in lexicon.entries {
            let key = e.userInput.lowercased()
            if key != e.documentText.lowercased() {
                shortcuts[key] = e.documentText
            } else {
                lexiconWords.insert(e.documentText)
            }
        }
    }

    func shortcut(for word: String) -> String? { shortcuts[word.lowercased()] }

    // MARK: Words

    /// The partial word immediately before the cursor.
    static func currentWord(in before: String) -> String {
        var chars: [Character] = []
        for c in before.reversed() {
            if c.isLetter || c == "'" || c == "’" { chars.append(c) } else { break }
        }
        return String(chars.reversed())
    }

    private func isMisspelled(_ word: String, language: String) -> Bool {
        let ns = word as NSString
        let r = checker.rangeOfMisspelledWord(in: word, range: NSRange(location: 0, length: ns.length),
                                              startingAt: 0, wrap: false, language: language)
        return r.location != NSNotFound
    }

    private func matchCase(_ s: String, to word: String) -> String {
        guard let first = word.first else { return s }
        if word.count > 1 && word == word.uppercased() { return s.uppercased() }
        if first.isUppercase { return s.prefix(1).uppercased() + s.dropFirst() }
        return s
    }

    /// Up to `limit` alternatives for the word being typed (not including the word itself).
    func suggestions(for word: String, limit: Int = 2) -> [String] {
        guard !word.isEmpty else { return [] }
        let ns = word as NSString
        let range = NSRange(location: 0, length: ns.length)
        let langs = languages

        let misspelledEverywhere = langs.allSatisfy { isMisspelled(word, language: $0) }
        var guesses: [String] = []
        var completions: [String] = []
        for l in langs {
            guesses += checker.guesses(forWordRange: range, in: word, language: l) ?? []
            completions += checker.completions(forPartialWordRange: range, in: word, language: l) ?? []
        }
        let names = lexiconWords.filter { $0.lowercased().hasPrefix(word.lowercased()) }.sorted()

        let ordered = misspelledEverywhere ? (guesses + completions + names) : (completions + names + guesses)
        var seen: Set<String> = [word.lowercased()]
        var out: [String] = []
        for s in ordered {
            let key = s.lowercased()
            if seen.contains(key) { continue }
            seen.insert(key)
            out.append(matchCase(s, to: word))
            if out.count == limit { break }
        }
        return out
    }

    /// A confident correction for a finished word, or nil to leave it alone.
    func autocorrection(for word: String) -> String? {
        guard word.count >= 2, word.rangeOfCharacter(from: .decimalDigits) == nil else { return nil }
        if word.count > 1 && word == word.uppercased() { return nil }          // acronyms
        if lexiconWords.contains(word) { return nil }
        let langs = languages
        guard langs.allSatisfy({ isMisspelled(word, language: $0) }) else { return nil }

        let range = NSRange(location: 0, length: (word as NSString).length)
        for l in langs {
            guard let guess = checker.guesses(forWordRange: range, in: word, language: l)?.first else { continue }
            let sameStart = guess.lowercased().first == word.lowercased().first
            let closeLength = abs(guess.count - word.count) <= 2
            if sameStart && closeLength && !guess.contains(" ") {
                return matchCase(guess, to: word)
            }
        }
        return nil
    }

    func learn(_ word: String) { UITextChecker.learnWord(word) }
}
