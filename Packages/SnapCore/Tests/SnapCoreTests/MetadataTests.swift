import Testing
import ImageIO
@testable import SnapCore

@Suite struct MetadataTests {
    @Test func nameGoesToTiffImageDescription() {
        var p: [CFString: Any] = [:]
        Metadata.stamp(&p, name: "white keyboard", place: nil)
        let tiff = p[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        #expect(tiff?[kCGImagePropertyTIFFImageDescription] as? String == "white keyboard")
        #expect(p[kCGImagePropertyIPTCDictionary] == nil)
    }
    @Test func placeGoesToIptcCity() {
        var p: [CFString: Any] = [:]
        Metadata.stamp(&p, name: nil, place: "Markdorf")
        let iptc = p[kCGImagePropertyIPTCDictionary] as? [CFString: Any]
        #expect(iptc?[kCGImagePropertyIPTCCity] as? String == "Markdorf")
        #expect(p[kCGImagePropertyTIFFDictionary] == nil)
    }
    @Test func emptyWritesNothingAndKeepsExisting() {
        var p: [CFString: Any] = [kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFMake: "Apple"]]
        Metadata.stamp(&p, name: "", place: "  ")
        let tiff = p[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        #expect(tiff?[kCGImagePropertyTIFFMake] as? String == "Apple")
        #expect(tiff?[kCGImagePropertyTIFFImageDescription] == nil)
        #expect(p[kCGImagePropertyIPTCDictionary] == nil)
    }
}
