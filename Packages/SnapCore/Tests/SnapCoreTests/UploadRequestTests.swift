import Testing
import Foundation
@testable import SnapCore

@Suite struct UploadRequestTests {
    let endpoint = URL(string: "https://snap.afterworkphotos.com/upload.php")!
    let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE1])

    @Test func postsTheJpegWithSecretAndName() {
        let r = UploadRequest.build(jpeg: jpeg, secret: "s3cret", filename: "20260829-184233.jpg", endpoint: endpoint)
        #expect(r.httpMethod == "POST")
        #expect(r.url == endpoint)
        #expect(r.value(forHTTPHeaderField: "Authorization") == "Bearer s3cret")
        #expect(r.value(forHTTPHeaderField: "Content-Type") == "image/jpeg")
        #expect(r.value(forHTTPHeaderField: "X-Filename") == "20260829-184233.jpg")
        #expect(r.httpBody == jpeg)
    }
}
