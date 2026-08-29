import Foundation

public enum LocationFreshness {
    public static let maxAge: TimeInterval = 60
    public static let maxAccuracy: Double = 100

    /// Whether a fix is good enough to stamp a photo with. CoreLocation
    /// reports a negative horizontalAccuracy for an invalid fix.
    public static func isUsable(age: TimeInterval, accuracy: Double) -> Bool {
        age <= maxAge && accuracy > 0 && accuracy <= maxAccuracy
    }
}
