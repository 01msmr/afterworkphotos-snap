import Testing
import ImageIO
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
}
