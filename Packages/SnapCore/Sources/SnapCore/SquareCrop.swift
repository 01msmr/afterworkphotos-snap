import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public enum SquareCrop {
    /// Centre-crops to a square in raw pixel space, leaving the orientation
    /// tag alone: a centred square is invariant under 90° rotation.
    public static func centered(in data: Data) throws -> Data {
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
        CGImageDestinationAddImage(dest, cropped, nil)
        guard CGImageDestinationFinalize(dest) else { throw SnapError.encodeFailed }
        return out as Data
    }
}
