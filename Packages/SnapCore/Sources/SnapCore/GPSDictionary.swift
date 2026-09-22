import Foundation
import ImageIO

public enum GPSDictionary {
    /// The four keys the site's ingest reads. ImageIO turns the decimal
    /// degrees into EXIF rationals itself; the sign becomes the ref.
    /// Altitude and time stamp are deliberately absent.
    public static func make(latitude: Double, longitude: Double) -> [CFString: Any] {
        [
            kCGImagePropertyGPSLatitude: abs(latitude),
            kCGImagePropertyGPSLatitudeRef: latitude < 0 ? "S" : "N",
            kCGImagePropertyGPSLongitude: abs(longitude),
            kCGImagePropertyGPSLongitudeRef: longitude < 0 ? "W" : "E",
        ]
    }

    /// The reverse, for a picked library photo: signed decimal degrees
    /// (latitude, longitude) from the image's GPS dictionary; nil without one.
    public static func coordinate(in data: Data) -> (Double, Double)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any],
              let lat = gps[kCGImagePropertyGPSLatitude] as? Double,
              let lon = gps[kCGImagePropertyGPSLongitude] as? Double else { return nil }
        return (gps[kCGImagePropertyGPSLatitudeRef] as? String == "S" ? -lat : lat,
                gps[kCGImagePropertyGPSLongitudeRef] as? String == "W" ? -lon : lon)
    }
}
