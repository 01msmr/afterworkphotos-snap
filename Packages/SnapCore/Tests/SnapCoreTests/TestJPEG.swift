import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// A JPEG (or PNG) made in memory: flat grey pixels of the given size, with
/// the given orientation tag and EXIF / TIFF / GPS dictionaries. No asset
/// files are bundled with the tests.
enum TestJPEG {
    static func make(width: Int, height: Int, orientation: Int = 1,
                     exif: [CFString: Any] = [:], tiff: [CFString: Any] = [:],
                     gps: [CFString: Any] = [:], type: UTType = .jpeg) -> Data {
        let space = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                            bytesPerRow: 0, space: space,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = ctx.makeImage()!

        var props: [CFString: Any] = [kCGImagePropertyOrientation: orientation]
        if !exif.isEmpty { props[kCGImagePropertyExifDictionary] = exif }
        if !tiff.isEmpty { props[kCGImagePropertyTIFFDictionary] = tiff }
        if !gps.isEmpty { props[kCGImagePropertyGPSDictionary] = gps }

        let out = NSMutableData()
        let dest = CGImageDestinationCreateWithData(out, type.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, image, props as CFDictionary)
        precondition(CGImageDestinationFinalize(dest))
        return out as Data
    }

    static func properties(of data: Data) -> [CFString: Any] {
        let source = CGImageSourceCreateWithData(data as CFData, nil)!
        return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
    }
}
