import Foundation

public enum NameSuggestions {
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    /// The ingest's caption prompt, asked for six candidates in the language in use.
    static func systemPrompt(_ language: Language) -> String {
        let lang = language == .de ? "German" : "English"
        return "You caption photos for an art archive. Give six different candidate captions for the main subject, most literal first, as a JSON array of strings and nothing else. Each is a 1-3 word literal description in lowercase \(lang) (capitals only for letters shown as shapes or stencils: L-shaped, a T, VA), concrete nouns, no article, no punctuation — like: snow on street, forest, clouds in sky, foot, garage door. Be precise about what the object actually is. Name its color only when the color is striking (bright orange, vivid green) — leave ordinary colors like gray or brown out. White may stay when it marks the object itself (white fruit) and the caption is two words, never as a third word. If the subject is geometric (grid, circle, spiral, zigzag, diamond), or the composition has stark geometric elements (a strong diagonal, repetition, symmetry), name that geometry even when it takes an extra word. Mind that snow under warm evening light can look like sand — check texture and season before calling it sandy."
    }

    public static func request(thumbnail: Data, language: Language, key: String) -> URLRequest {
        let body: [String: Any] = [
            "model": "claude-haiku-4-5", "max_tokens": 200,
            "system": systemPrompt(language),
            "messages": [["role": "user", "content": [
                ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg",
                                             "data": thumbnail.base64EncodedString()]],
                ["type": "text", "text": "Caption this photo."]]]],
        ]
        var r = URLRequest(url: endpoint)
        r.httpMethod = "POST"
        r.setValue(key, forHTTPHeaderField: "x-api-key")
        r.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        r.setValue("application/json", forHTTPHeaderField: "content-type")
        r.httpBody = try? JSONSerialization.data(withJSONObject: body)
        r.timeoutInterval = 30
        return r
    }

    /// The model's answer → at most six cleaned names, order kept.
    public static func parse(_ body: Data) -> [String] {
        guard let obj = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let content = obj["content"] as? [[String: Any]],
              let text = content.first(where: { $0["type"] as? String == "text" })?["text"] as? String,
              let open = text.firstIndex(of: "["), let close = text[open...].firstIndex(of: "]"),
              let raw = try? JSONSerialization.jsonObject(with: Data(text[open...close].utf8)) as? [String] else {
            return []
        }
        var seen = Set<String>(), out: [String] = []
        for s in raw {
            let clean = String(s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().prefix(40))
            guard !clean.isEmpty, seen.insert(clean).inserted else { continue }
            out.append(clean)
            if out.count == 6 { break }
        }
        return out
    }
}
