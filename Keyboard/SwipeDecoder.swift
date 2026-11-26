import UIKit

/// A finished swipe: the finger path plus the key geometry it was drawn on (all in KeyboardView coordinates).
struct SwipeInput {
    var points: [CGPoint]
    var centers: [Character: CGPoint]
    var keyWidth: CGFloat
}

/// Gesture-typing decoder.
///
/// Every word is indexed by its first and last letter. A swipe is compared, after resampling both to the
/// same number of points, with the "ideal" path through the key centres of each candidate word. The score
/// combines average distance (in key widths), a path-length mismatch term and a word-frequency prior.
final class SwipeDecoder {
    // Tunables.
    private let sampleCount = 32
    private let lengthWeight = 0.4
    private let frequencyWeight = 0.05
    private let extraWordRank = 200

    private struct Entry {
        let word: String
        let letters: [UInt8]     // a=0 ... z=25, consecutive duplicates removed
        let rank: Int
    }

    private let queue = DispatchQueue(label: "io.brunintech.bruninboard.swipe", qos: .userInitiated)

    // Everything below is only touched on `queue`.
    private var buckets: [Int: [Entry]] = [:]
    private var loadedLanguages: Set<String> = []
    private var extraWords: [String] = []

    // MARK: Loading

    func preload(languages: [String]) {
        queue.async { [weak self] in self?.ensureLoaded(languages) }
    }

    /// Contact names and other UILexicon words.
    func addExtraWords(_ words: [String]) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.extraWords = words
            for w in words { self.index(w, rank: self.extraWordRank) }
        }
    }

    private func ensureLoaded(_ languages: [String]) {
        var wanted = Set(languages.map { String($0.prefix(2)).lowercased() })
        if wanted.isEmpty { wanted = ["en"] }
        guard wanted != loadedLanguages else { return }

        buckets.removeAll()
        let bundle = Bundle(for: SwipeDecoder.self)
        for lang in wanted {
            guard let url = bundle.url(forResource: "words_\(lang)", withExtension: "txt"),
                  let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            var rank = 0
            text.enumerateLines { line, _ in
                if !line.isEmpty { self.index(line, rank: rank) }
                rank += 1
            }
        }
        if buckets.isEmpty,
           let url = bundle.url(forResource: "words_en", withExtension: "txt"),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            var rank = 0
            text.enumerateLines { line, _ in
                if !line.isEmpty { self.index(line, rank: rank) }
                rank += 1
            }
        }
        for w in extraWords { index(w, rank: extraWordRank) }
        loadedLanguages = wanted
    }

    private func index(_ word: String, rank: Int) {
        let letters = SwipeDecoder.fold(word)
        guard letters.count >= 2, let f = letters.first, let l = letters.last else { return }
        buckets[Int(f) * 26 + Int(l), default: []].append(Entry(word: word, letters: letters, rank: rank))
    }

    /// Lower-cases, strips accents and apostrophes, drops repeated letters: "Você" -> [v,o,c,e].
    private static func fold(_ word: String) -> [UInt8] {
        let folded = word.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        var out: [UInt8] = []
        for u in folded.unicodeScalars where u.value >= 97 && u.value <= 122 {
            let i = UInt8(u.value - 97)
            if out.last != i { out.append(i) }
        }
        return out
    }

    // MARK: Decoding

    /// `hasDictionary` is false when no word list could be loaded.
    func decode(_ input: SwipeInput, languages: [String],
                completion: @escaping (_ words: [String], _ hasDictionary: Bool) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.ensureLoaded(languages)
            let has = !self.buckets.isEmpty
            let words = has ? self.run(input) : []
            DispatchQueue.main.async { completion(words, has) }
        }
    }

    private func run(_ input: SwipeInput) -> [String] {
        let pts = input.points
        guard pts.count >= 3, let first = pts.first, let last = pts.last else { return [] }
        let kw = max(input.keyWidth, 1)

        var centers = [CGPoint?](repeating: nil, count: 26)
        for (ch, p) in input.centers {
            if let a = ch.asciiValue, a >= 97, a <= 122 { centers[Int(a - 97)] = p }
        }

        let pathLen = SwipeDecoder.length(pts)
        guard pathLen > kw * 0.8 else { return [] }
        let sampled = SwipeDecoder.resample(pts, count: sampleCount)

        let starts = nearestKeys(to: first, centers: centers, within: kw * 0.95)
        let ends = nearestKeys(to: last, centers: centers, within: kw * 0.95)

        var scored: [(word: String, score: Double)] = []
        for s in starts {
            for e in ends {
                guard let list = buckets[s * 26 + e] else { continue }
                for entry in list {
                    var tpts: [CGPoint] = []
                    tpts.reserveCapacity(entry.letters.count)
                    var ok = true
                    for l in entry.letters {
                        guard let c = centers[Int(l)] else { ok = false; break }
                        tpts.append(c)
                    }
                    guard ok, tpts.count >= 2 else { continue }

                    let tlen = SwipeDecoder.length(tpts)
                    guard tlen > 0 else { continue }
                    let ratio = Double(pathLen / tlen)
                    guard ratio > 0.45 && ratio < 2.6 else { continue }

                    let tsamp = SwipeDecoder.resample(tpts, count: sampleCount)
                    var sum: CGFloat = 0
                    for i in 0..<sampleCount {
                        sum += hypot(sampled[i].x - tsamp[i].x, sampled[i].y - tsamp[i].y)
                    }
                    let avg = Double(sum / CGFloat(sampleCount) / kw)
                    let score = avg
                        + lengthWeight * abs(log(ratio))
                        + frequencyWeight * log2(Double(entry.rank) + 2)
                    scored.append((entry.word, score))
                }
            }
        }

        scored.sort { $0.score < $1.score }
        var out: [String] = []
        var seen = Set<String>()
        for item in scored {
            let key = item.word.lowercased()
            if seen.insert(key).inserted {
                out.append(item.word)
                if out.count == 3 { break }
            }
        }
        return out
    }

    private func nearestKeys(to p: CGPoint, centers: [CGPoint?], within radius: CGFloat) -> [Int] {
        var ds: [(Int, CGFloat)] = []
        for i in 0..<26 {
            if let c = centers[i] { ds.append((i, hypot(c.x - p.x, c.y - p.y))) }
        }
        ds.sort { $0.1 < $1.1 }
        guard let best = ds.first else { return [] }
        var out = [best.0]
        for d in ds.dropFirst() where d.1 <= radius && out.count < 3 { out.append(d.0) }
        return out
    }

    // MARK: Geometry

    static func length(_ pts: [CGPoint]) -> CGFloat {
        var total: CGFloat = 0
        for i in 1..<max(pts.count, 1) {
            total += hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y)
        }
        return total
    }

    /// Resamples a polyline to `n` equally spaced points.
    static func resample(_ pts: [CGPoint], count n: Int) -> [CGPoint] {
        guard let firstPoint = pts.first, let lastPoint = pts.last else { return [] }
        let total = length(pts)
        guard pts.count > 1, total > 0 else { return Array(repeating: firstPoint, count: n) }

        let step = total / CGFloat(n - 1)
        var points = pts
        var out: [CGPoint] = [firstPoint]
        var acc: CGFloat = 0
        var i = 1
        while i < points.count {
            let a = points[i - 1], b = points[i]
            let d = hypot(b.x - a.x, b.y - a.y)
            if d > 0 && acc + d >= step {
                let t = (step - acc) / d
                let q = CGPoint(x: a.x + t * (b.x - a.x), y: a.y + t * (b.y - a.y))
                out.append(q)
                points.insert(q, at: i)   // q becomes the start of the next segment
                acc = 0
            } else {
                acc += d
            }
            i += 1
        }
        while out.count < n { out.append(lastPoint) }
        if out.count > n { out.removeLast(out.count - n) }
        return out
    }
}
