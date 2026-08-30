import Foundation
import ImageIO

public enum TakenDate {
    /// "yyyy-MM-dd" from EXIF DateTimeOriginal ("yyyy:MM:dd HH:mm:ss"); nil without one.
    public static func from(jpeg: Data) -> String? {
        guard let source = CGImageSourceCreateWithData(jpeg as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any],
              let taken = exif[kCGImagePropertyExifDateTimeOriginal] as? String else { return nil }
        let d = taken.filter(\.isNumber)
        guard d.count == 14 else { return nil }
        return "\(d.prefix(4))-\(d.dropFirst(4).prefix(2))-\(d.dropFirst(6).prefix(2))"
    }
}
