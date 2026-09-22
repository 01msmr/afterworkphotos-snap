import Testing
import ImageIO
import Foundation
@testable import SnapCore

@Suite struct GPSDictionaryTests {
    @Test func northEastArePositiveWithRefs() {
        let d = GPSDictionary.make(latitude: 47.66, longitude: 9.39)
        #expect(d[kCGImagePropertyGPSLatitude] as? Double == 47.66)
        #expect(d[kCGImagePropertyGPSLatitudeRef] as? String == "N")
        #expect(d[kCGImagePropertyGPSLongitude] as? Double == 9.39)
        #expect(d[kCGImagePropertyGPSLongitudeRef] as? String == "E")
    }

    @Test func southWestAreAbsoluteValuesWithRefs() {
        let d = GPSDictionary.make(latitude: -33.87, longitude: -70.65)
        #expect(d[kCGImagePropertyGPSLatitude] as? Double == 33.87)
        #expect(d[kCGImagePropertyGPSLatitudeRef] as? String == "S")
        #expect(d[kCGImagePropertyGPSLongitude] as? Double == 70.65)
        #expect(d[kCGImagePropertyGPSLongitudeRef] as? String == "W")
    }

    @Test func onlyTheFourKeys() {
        let d = GPSDictionary.make(latitude: 1, longitude: 2)
        #expect(d.count == 4)
    }

    @Test func coordinateReadsBackWhatMakeWrote() {
        let jpeg = TestJPEG.make(width: 40, height: 30, gps: GPSDictionary.make(latitude: -33.87, longitude: 9.39))
        let c = GPSDictionary.coordinate(in: jpeg)
        #expect(abs((c?.0 ?? 0) - -33.87) < 0.0001)
        #expect(abs((c?.1 ?? 0) - 9.39) < 0.0001)
    }

    @Test func coordinateReadsFromHEIC() {
        let heic = TestJPEG.make(width: 40, height: 30, gps: GPSDictionary.make(latitude: 47.66, longitude: -70.65), type: .heic)
        let c = GPSDictionary.coordinate(in: heic)
        #expect(abs((c?.0 ?? 0) - 47.66) < 0.0001)
        #expect(abs((c?.1 ?? 0) - -70.65) < 0.0001)
    }

    @Test func coordinateIsNilWithoutGPS() {
        #expect(GPSDictionary.coordinate(in: TestJPEG.make(width: 40, height: 30)) == nil)
        #expect(GPSDictionary.coordinate(in: Data([1, 2, 3])) == nil)
    }
}
