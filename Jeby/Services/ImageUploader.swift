//
//  ImageUploader.swift
//  Jeby
//
//  Photos go to Firebase Storage from the app; jeby-go only ever stores the
//  resulting URL. Keeps image bytes off the API and lets Storage handle the
//  retrying and resumption.
//

import FirebaseStorage
import Foundation
import UIKit

enum ImageUploadError: LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Couldn't prepare that photo. Try a different one."
        }
    }
}

/// Where an upload lands. Each case owns its path so callers can't invent one.
enum ImageKind {
    case profile
    case boat
    case pet

    /// Storage path for a given user. The profile photo has a fixed name so a
    /// re-upload replaces it instead of orphaning the old file; boats and pets
    /// are per-record and get a fresh name each time.
    func path(userID: String) -> String {
        switch self {
        case .profile: return "users/\(userID)/profile.jpg"
        case .boat: return "users/\(userID)/boats/\(UUID().uuidString).jpg"
        case .pet: return "users/\(userID)/pets/\(UUID().uuidString).jpg"
        }
    }
}

struct ImageUploader: Sendable {
    /// Longest edge we keep. Photos are shown at avatar and card sizes, so a
    /// full 12-megapixel capture is wasted bytes on a boat's LTE connection.
    private let maxDimension: CGFloat = 1024
    private let compressionQuality: CGFloat = 0.8

    /// Uploads an image and returns its public download URL.
    func upload(_ image: UIImage, kind: ImageKind, userID: String) async throws -> URL {
        guard let data = jpegData(from: image) else {
            throw ImageUploadError.encodingFailed
        }

        let reference = Storage.storage().reference(withPath: kind.path(userID: userID))
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await reference.putDataAsync(data, metadata: metadata)
        return try await reference.downloadURL()
    }

    /// Downscales to `maxDimension` on the longest edge and JPEG-encodes.
    private func jpegData(from image: UIImage) -> Data? {
        let longestEdge = max(image.size.width, image.size.height)
        guard longestEdge > maxDimension else {
            return image.jpegData(compressionQuality: compressionQuality)
        }

        let scale = maxDimension / longestEdge
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: compressionQuality)
    }
}
