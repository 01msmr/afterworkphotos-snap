import Testing
import Foundation
import ImageIO
@testable import SnapCore

@Suite struct ThumbnailTests {
    @Test func twoHundredPixelJpeg() throws {
        let out = try Thumbnail.make(from: TestJPEG.make(width: 3000, height: 3000))
        let p = TestJPEG.properties(of: out)
        #expect(p[kCGImagePropertyPixelWidth] as? Int == 200)
        #expect(out.prefix(3) == Data([0xFF, 0xD8, 0xFF]))
    }
    @Test func garbageThrows() {
        #expect(throws: SnapError.decodeFailed) { try Thumbnail.make(from: Data([1, 2])) }
    }
}
