import Foundation

public enum UploadRequest {
    public static func build(jpeg: Data, secret: String, filename: String, endpoint: URL) -> URLRequest {
        var r = URLRequest(url: endpoint)
        r.httpMethod = "POST"
        r.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        r.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        r.setValue(filename, forHTTPHeaderField: "X-Filename")
        r.httpBody = jpeg
        r.timeoutInterval = 60
        return r
    }
}
