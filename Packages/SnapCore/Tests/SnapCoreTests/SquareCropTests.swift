import Testing
import Foundation
import ImageIO
@testable import SnapCore

@Suite struct SquareCropTests {
    private func size(_ data: Data) -> (Int, Int) {
        let p = TestJPEG.properties(of: data)
        return (p[kCGImagePropertyPixelWidth] as! Int, p[kCGImagePropertyPixelHeight] as! Int)
    }

    @Test func landscapeBecomesSquareOfShorterSide() throws {
        let out = try SquareCrop.centered(in: TestJPEG.make(width: 4032, height: 3024))
        #expect(size(out) == (3024, 3024))
    }

    @Test func portraitBecomesSquareOfShorterSide() throws {
        let out = try SquareCrop.centered(in: TestJPEG.make(width: 3024, height: 4032))
        #expect(size(out) == (3024, 3024))
    }

    @Test func squareStaysItsSize() throws {
        let out = try SquareCrop.centered(in: TestJPEG.make(width: 3000, height: 3000))
        #expect(size(out) == (3000, 3000))
    }

    @Test func garbageThrowsDecodeFailed() {
        #expect(throws: SnapError.decodeFailed) {
            try SquareCrop.centered(in: Data([0, 1, 2, 3, 4, 5, 6, 7]))
        }
    }

    private nonisolated(unsafe) static let exif: [CFString: Any] = [
        kCGImagePropertyExifDateTimeOriginal: "2026:08:29 18:42:33",
        kCGImagePropertyExifPixelXDimension: 4032,
        kCGImagePropertyExifPixelYDimension: 3024,
    ]
    private nonisolated(unsafe) static let tiff: [CFString: Any] = [kCGImagePropertyTIFFMake: "Apple"]
    private nonisolated(unsafe) static let gps: [CFString: Any] = [
        kCGImagePropertyGPSLatitude: 47.66, kCGImagePropertyGPSLatitudeRef: "N",
        kCGImagePropertyGPSLongitude: 9.39, kCGImagePropertyGPSLongitudeRef: "E",
    ]

    @Test func exifTiffGpsCarryAcross() throws {
        let input = TestJPEG.make(width: 4032, height: 3024, orientation: 6,
                                  exif: Self.exif, tiff: Self.tiff, gps: Self.gps)
        let p = TestJPEG.properties(of: try SquareCrop.centered(in: input))
        let exif = p[kCGImagePropertyExifDictionary] as? [CFString: Any]
        #expect(exif?[kCGImagePropertyExifDateTimeOriginal] as? String == "2026:08:29 18:42:33")
        let tiff = p[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        #expect(tiff?[kCGImagePropertyTIFFMake] as? String == "Apple")
        let gps = p[kCGImagePropertyGPSDictionary] as? [CFString: Any]
        #expect(gps?[kCGImagePropertyGPSLongitudeRef] as? String == "E")
        let lon = try #require(gps?[kCGImagePropertyGPSLongitude] as? Double)
        #expect(abs(lon - 9.39) < 0.0001)
    }

    @Test func orientationTagIsCopiedUnchanged() throws {
        for tag in [1, 3, 6, 8] {
            let input = TestJPEG.make(width: 40, height: 30, orientation: tag)
            let p = TestJPEG.properties(of: try SquareCrop.centered(in: input))
            #expect(p[kCGImagePropertyOrientation] as? Int == tag)
        }
    }

    @Test func pixelDimensionsAreUpdatedEverywhere() throws {
        let input = TestJPEG.make(width: 4032, height: 3024, exif: Self.exif)
        let p = TestJPEG.properties(of: try SquareCrop.centered(in: input))
        #expect(p[kCGImagePropertyPixelWidth] as? Int == 3024)
        #expect(p[kCGImagePropertyPixelHeight] as? Int == 3024)
        let exif = p[kCGImagePropertyExifDictionary] as? [CFString: Any]
        #expect(exif?[kCGImagePropertyExifPixelXDimension] as? Int == 3024)
        #expect(exif?[kCGImagePropertyExifPixelYDimension] as? Int == 3024)
    }

    @Test func pngInComesOutAsJpeg() throws {
        let png = TestJPEG.make(width: 40, height: 30, type: .png)
        let out = try SquareCrop.centered(in: png)
        #expect(out.prefix(3) == Data([0xFF, 0xD8, 0xFF]))
    }
}
