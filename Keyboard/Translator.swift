import Foundation

/// Free translation through the MyMemory public API (no key, ~5k chars/day anonymous).
/// Needs Full Access so the keyboard extension is allowed to use the network.
enum Translator {
    static func translate(_ text: String, from: String, to: String,
                          completion: @escaping (String?) -> Void) {
        var comps = URLComponents(string: "https://api.mymemory.translated.net/get")!
        comps.queryItems = [
            URLQueryItem(name: "q", value: text),
            URLQueryItem(name: "langpair", value: "\(from)|\(to)")
        ]
        guard let url = comps.url else { completion(nil); return }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        URLSession.shared.dataTask(with: request) { data, _, _ in
            var result: String?
            if let data = data,
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let rd = obj["responseData"] as? [String: Any],
               let t = rd["translatedText"] as? String {
                result = decodeEntities(t)
            }
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }

    private static func decodeEntities(_ s: String) -> String {
        s.replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}
