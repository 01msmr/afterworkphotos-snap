import Foundation

public enum SnapError: Error, Equatable, LocalizedError {
    case decodeFailed, encodeFailed, noDateTaken

    public var errorDescription: String? {
        switch self {
        case .decodeFailed: "Could not decode the captured image."
        case .encodeFailed: "Could not encode the cropped image."
        case .noDateTaken:  "The photo carries no date taken."
        }
    }
}
