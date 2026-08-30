import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public enum Thumbnail {
    /// A small JPEG for the model to look at — the size the ingest sends.
    public static func make(from jpeg: Data, side: Int = 200) throws -> Data {
        guard let source = CGImageSourceCreateWithData(jpeg as CFData, nil) else { throw SnapError.decodeFailed }
        let opts: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                     kCGImageSourceThumbnailMaxPixelSize: side,
                                     kCGImageSourceCreateThumbnailWithTransform: true]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, opts as CFDictionary) else { throw SnapError.decodeFailed }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else { throw SnapError.encodeFailed }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw SnapError.encodeFailed }
        return out as Data
    }
}
