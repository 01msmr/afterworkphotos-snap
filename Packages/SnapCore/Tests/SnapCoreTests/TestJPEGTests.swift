import Testing
import ImageIO
@testable import SnapCore

@Suite struct TestJPEGTests {
    @Test func fixtureReadsBackWhatItWasGiven() throws {
        let data = TestJPEG.make(
            width: 40, height: 30, orientation: 6,
            exif: [kCGImagePropertyExifDateTimeOriginal: "2026:08:29 18:42:33"],
            tiff: [kCGImagePropertyTIFFMake: "Apple"],
            gps: [kCGImagePropertyGPSLatitude: 47.66, kCGImagePropertyGPSLatitudeRef: "N",
                  kCGImagePropertyGPSLongitude: 9.39, kCGImagePropertyGPSLongitudeRef: "E"])
        let p = TestJPEG.properties(of: data)
        #expect(p[kCGImagePropertyPixelWidth] as? Int == 40)
        #expect(p[kCGImagePropertyPixelHeight] as? Int == 30)
        #expect(p[kCGImagePropertyOrientation] as? Int == 6)
        let exif = p[kCGImagePropertyExifDictionary] as? [CFString: Any]
        #expect(exif?[kCGImagePropertyExifDateTimeOriginal] as? String == "2026:08:29 18:42:33")
        let tiff = p[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        #expect(tiff?[kCGImagePropertyTIFFMake] as? String == "Apple")
        let gps = p[kCGImagePropertyGPSDictionary] as? [CFString: Any]
        #expect(gps?[kCGImagePropertyGPSLatitudeRef] as? String == "N")
        let lat = try #require(gps?[kCGImagePropertyGPSLatitude] as? Double)
        #expect(abs(lat - 47.66) < 0.0001)
    }
}
