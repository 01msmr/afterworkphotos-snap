import Foundation
import SnapCore

/// Six names for a photo, from Claude, with the key built into the app.
/// Any failure is an empty list — the LCD then shows "-".
enum Namer {
    static func suggest(for jpeg: Data, language: Language) async -> [String] {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "ANTHROPIC_API_KEY") as? String, !key.isEmpty else { return [] }
        // The resize + JPEG re-encode is real CPU work — off the caller's actor.
        guard let thumb = await Task.detached(priority: .userInitiated, operation: {
            try? Thumbnail.make(from: jpeg)
        }).value else { return [] }
        let request = NameSuggestions.request(thumbnail: thumb, language: language, key: key)
        guard let (body, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        return NameSuggestions.parse(body)
    }
}
