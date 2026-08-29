import Photos

enum SaveError: LocalizedError {
    case notAuthorized, failed
    var errorDescription: String? {
        switch self {
        case .notAuthorized: "Photo library access was denied."
        case .failed:        "Saving to the photo library failed."
        }
    }
}

enum PhotoSaver {
    /// .readWrite: add-only does not reliably permit setting isFavorite.
    static func saveAsFavorite(_ data: Data) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else { throw SaveError.notAuthorized }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                // The file data, never a UIImage — keeps EXIF and GPS intact.
                request.addResource(with: .photo, data: data, options: nil)
                request.isFavorite = true
            }
        } catch { throw SaveError.failed }
    }
}
