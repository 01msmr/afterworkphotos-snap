import Testing
import Foundation
import ImageIO
@testable import SnapCore

@Suite struct FilenameTests {
    @Test func dateTakenBecomesTheName() throws {
        let jpeg = TestJPEG.make(width: 40, height: 30,
                                 exif: [kCGImagePropertyExifDateTimeOriginal: "2026:08:29 18:42:33"])
        #expect(try Filename.from(jpeg: jpeg) == "20260829-184233.jpg")
    }

    @Test func noDateTakenThrows() {
        let jpeg = TestJPEG.make(width: 40, height: 30)
        #expect(throws: SnapError.noDateTaken) { try Filename.from(jpeg: jpeg) }
    }

    @Test func garbageThrowsDecodeFailed() {
        #expect(throws: SnapError.decodeFailed) { try Filename.from(jpeg: Data([1, 2, 3])) }
    }
}
