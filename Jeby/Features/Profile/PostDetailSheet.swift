//
//  PostDetailSheet.swift
//  Jeby
//
//  One of your own reports, opened from the grid on your profile: the photo,
//  when you filed it, how bumpy you said it was, and what you wrote.
//
//  Deleting lives behind the overflow menu rather than sitting on the sheet —
//  it's the destructive thing here, and it shouldn't be the easiest to hit.
//

import Photos
import SwiftUI

struct PostDetailSheet: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    let post: UserPost
    /// Called after a successful delete, so the profile can re-read itself.
    /// Nil means this is someone else's report: readable, with no overflow menu
    /// and no way to delete it.
    var onDeleted: (() -> Void)?

    @State private var confirmingDelete = false
    @State private var isDeleting = false
    @State private var isSavingImage = false
    @State private var errorMessage: String?
    @State private var noticeMessage: String?
    /// Bumped on a successful save, to fire the haptic.
    @State private var savedCount = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    AsyncImage(url: post.imageURL) { image in
                        image.resizable().aspectRatio(contentMode: .fit)
                    } placeholder: {
                        CardStyle.surface.aspectRatio(3.0 / 4.0, contentMode: .fit)
                    }
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: PostImage.cornerRadius))

                    VStack(alignment: .leading, spacing: 14) {
                        detail("Filed", value: post.filedAt)

                        detail("Bumpy Rating", value: "\(post.bumpyScore)")
                            .foregroundStyle(BumpyScoreColor.color(at: Double(post.bumpyScore)))

                        if !post.caption.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CAPTION")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(post.caption)
                                    .font(.body)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let noticeMessage {
                        Label(noticeMessage, systemImage: "checkmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .background(CardStyle.sheetSurface)
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .disabled(isDeleting)
                    .accessibilityLabel("Close")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isDeleting || isSavingImage {
                        ProgressView()
                    } else {
                        Menu {
                            Button("Save photo", systemImage: "square.and.arrow.down") {
                                Task { await saveImage() }
                            }

                            // Only your own report can be removed; someone
                            // else's menu is just the download.
                            if onDeleted != nil {
                                Button("Delete report", systemImage: "trash", role: .destructive) {
                                    confirmingDelete = true
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .accessibilityLabel("More")
                    }
                }
            }
        }
        .interactiveDismissDisabled(isDeleting || isSavingImage)
        .sensoryFeedback(.success, trigger: savedCount)
        .confirmationDialog(
            "This can't be undone.",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete report", role: .destructive) {
                Task { await delete() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    /// A labeled line: small-caps label over its value.
    private func detail(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.weight(.semibold))
                .monospacedDigit()
        }
    }

    /// Downloads the photo into the user's library. Add-only authorization, so
    /// this never gains the ability to read what's already there.
    private func saveImage() async {
        guard let url = post.imageURL else { return }

        isSavingImage = true
        errorMessage = nil
        noticeMessage = nil
        defer { isSavingImage = false }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            errorMessage = "Jeby needs permission to save photos. Turn it on in Settings › Jeby."
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                PHPhotoLibrary.shared().performChanges {
                    // From data rather than a UIImage, so the original JPEG goes
                    // in untouched rather than being re-encoded.
                    PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
                } completionHandler: { success, error in
                    if success {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: error ?? JebyClientError.invalidResponse)
                    }
                }
            }
            noticeMessage = "Saved to Photos"
            savedCount += 1
        } catch {
            errorMessage = "Couldn't save that photo. Check your connection and try again."
        }
    }

    private func delete() async {
        guard let userID = auth.user?.id else { return }

        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }

        do {
            let client = JebyClient(idToken: { [auth] in try await auth.idToken() })
            try await client.deletePost(userID: userID, postID: post.id)
            onDeleted?()
            dismiss()
        } catch {
            errorMessage = "Couldn't delete that. Check your connection and try again."
        }
    }
}
