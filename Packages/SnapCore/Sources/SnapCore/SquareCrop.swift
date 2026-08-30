import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public enum SquareCrop {
    /// Centre-crops to a square in raw pixel space, leaving the orientation
    /// tag alone: a centred square is invariant under 90° rotation.
    public static func centered(in data: Data, gps: [CFString: Any]? = nil, extra: [CFString: Any]? = nil) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw SnapError.decodeFailed
        }
        let side = min(image.width, image.height)
        let rect = CGRect(x: (image.width - side) / 2, y: (image.height - side) / 2,
                          width: side, height: side)
        guard let cropped = image.cropping(to: rect) else { throw SnapError.decodeFailed }

        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw SnapError.encodeFailed
        }
        var props = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]) ?? [:]
        props[kCGImagePropertyPixelWidth] = side
        props[kCGImagePropertyPixelHeight] = side
        var exif = (props[kCGImagePropertyExifDictionary] as? [CFString: Any]) ?? [:]
        exif[kCGImagePropertyExifPixelXDimension] = side
        exif[kCGImagePropertyExifPixelYDimension] = side
        props[kCGImagePropertyExifDictionary] = exif
        if let gps { props[kCGImagePropertyGPSDictionary] = gps }
        if let extra {
            for (key, value) in extra {
                if let sub = value as? [CFString: Any], var existing = props[key] as? [CFString: Any] {
                    for (k, v) in sub { existing[k] = v }
                    props[key] = existing
                } else {
                    props[key] = value
                }
            }
        }
        props[kCGImageDestinationLossyCompressionQuality] = 0.95

        CGImageDestinationAddImage(dest, cropped, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw SnapError.encodeFailed }
        return out as Data
    }
}
