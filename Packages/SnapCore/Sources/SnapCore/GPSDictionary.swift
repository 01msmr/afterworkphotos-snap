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
}
