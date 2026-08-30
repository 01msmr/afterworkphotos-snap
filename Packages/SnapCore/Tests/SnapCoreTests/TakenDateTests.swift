import Testing
import Foundation
import ImageIO
@testable import SnapCore

@Suite struct TakenDateTests {
    @Test func dateFromExif() {
        let jpeg = TestJPEG.make(width: 40, height: 30, exif: [kCGImagePropertyExifDateTimeOriginal: "2026:08:30 15:39:12"])
        #expect(TakenDate.from(jpeg: jpeg) == "2026-08-30")
    }
    @Test func nilWithoutDate() {
        #expect(TakenDate.from(jpeg: TestJPEG.make(width: 40, height: 30)) == nil)
        #expect(TakenDate.from(jpeg: Data([1, 2, 3])) == nil)
    }
    @Test func placeholderDateIsNil() {
        let jpeg = TestJPEG.make(width: 40, height: 30, exif: [kCGImagePropertyExifDateTimeOriginal: "0000:00:00 00:00:00"])
        #expect(TakenDate.from(jpeg: jpeg) == nil)
    }
}
