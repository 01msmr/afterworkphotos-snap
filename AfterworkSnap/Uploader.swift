import Foundation
import SnapCore

enum UploadError: LocalizedError {
    case noSecret, refused(String)
    var errorDescription: String? {
        switch self {
        case .noSecret:         "No upload secret on this phone."
        case .refused(let why): why
        }
    }
}

enum Uploader {
    static let endpoint = URL(string: "https://snap.afterworkphotos.com/upload.php")!

    /// 200 and 201 are success; any other answer's text is the error.
    static func send(_ jpeg: Data) async throws {
        guard let secret = Secret.read() else { throw UploadError.noSecret }
        let name = try Filename.from(jpeg: jpeg)
        let request = UploadRequest.build(jpeg: jpeg, secret: secret, filename: name, endpoint: endpoint)
        let (body, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 || code == 201 else {
            let text = String(decoding: body, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            throw UploadError.refused(text.isEmpty ? "Server answered \(code)." : text)
        }
    }
}
