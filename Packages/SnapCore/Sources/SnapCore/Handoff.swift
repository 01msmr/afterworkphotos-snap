import Foundation
import UniformTypeIdentifiers

/// "Share with Snap": the share extension puts the photo's original file on
/// a named pasteboard (shared by the team's apps, no App Group needed — the
/// team is a free one) and opens the app by URL; the app takes it from there.
public enum Handoff {
    public static let pasteboard = "co.msmr.afterworksnap.picked"
    public static let pasteboardType = "co.msmr.afterworksnap.photo"
    public static let url = URL(string: "afterworksnap://picked")!

    /// The first image type among a shared item's representations — the
    /// original (HEIC or JPEG), not a later rendition; nil without an image.
    public static func imageType(in identifiers: [String]) -> String? {
        identifiers.first { UTType($0)?.conforms(to: .image) == true }
    }
}
