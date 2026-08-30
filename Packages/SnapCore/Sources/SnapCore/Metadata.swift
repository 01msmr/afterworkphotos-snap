import Foundation
import ImageIO

public enum Metadata {
    /// The LCD's name and place, into the fields the site's ingest reads:
    /// TIFF ImageDescription and IPTC City. Empty writes nothing.
    public static func stamp(_ props: inout [CFString: Any], name: String?, place: String?) {
        if let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            var tiff = (props[kCGImagePropertyTIFFDictionary] as? [CFString: Any]) ?? [:]
            tiff[kCGImagePropertyTIFFImageDescription] = name
            props[kCGImagePropertyTIFFDictionary] = tiff
        }
        if let place = place?.trimmingCharacters(in: .whitespacesAndNewlines), !place.isEmpty {
            var iptc = (props[kCGImagePropertyIPTCDictionary] as? [CFString: Any]) ?? [:]
            iptc[kCGImagePropertyIPTCCity] = place
            props[kCGImagePropertyIPTCDictionary] = iptc
        }
    }
}
