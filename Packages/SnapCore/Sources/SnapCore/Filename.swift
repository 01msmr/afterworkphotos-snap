import Foundation
import ImageIO

public enum Filename {
    /// yyyyMMdd-HHmmss.jpg from EXIF DateTimeOriginal ("yyyy:MM:dd HH:mm:ss").
    /// Never the clock: a retry must produce the same name.
    public static func from(jpeg: Data) throws -> String {
        guard let source = CGImageSourceCreateWithData(jpeg as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            throw SnapError.decodeFailed
        }
        let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
        guard let taken = exif?[kCGImagePropertyExifDateTimeOriginal] as? String else {
            throw SnapError.noDateTaken
        }
        let digits = taken.filter(\.isNumber)
        guard digits.count == 14 else { throw SnapError.noDateTaken }
        return "\(digits.prefix(8))-\(digits.suffix(6)).jpg"
    }
}
