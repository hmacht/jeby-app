//
//  PostDetailsView.swift
//  Jeby
//
//  The page after the shutter: the shot you just took, how bumpy it actually
//  was, and a caption.
//
//  Who posted it and when are the backend's business — the UID comes off the
//  verified token and the row is timestamped on insert, so neither can be
//  spoofed by the client or thrown off by a phone with a wrong clock.
//

import SwiftUI

struct PostDetailsView: View {
    @Environment(AuthService.self) private var auth
    /// Pops back to the viewfinder — which is what retaking is, now that the
    /// camera is the page underneath this one.
    @Environment(\.dismiss) private var dismiss

    let image: UIImage
    /// Called once the report is filed, so the whole flow can close.
    var onPosted: () -> Void

    @State private var caption = ""
    /// 0-100, the same scale as the AI BumpyScore, so the model's guess and what
    /// the person out there actually felt can be compared.
    @State private var bumpyScore = 50.0
    @State private var isPosting = false
    @State private var errorMessage: String?
    @FocusState private var isCaptionFocused: Bool

    var body: some View {
        ScrollView {
            // Avatar in its own column, everything else in the one beside it —
            // the same two-column shape a report has on the feed, so filing one
            // looks like the thing it becomes.
            HStack(alignment: .top, spacing: 12) {
                if let user = auth.user {
                    Avatar(user: user, size: 44)
                }

                VStack(alignment: .leading, spacing: 20) {
                    TextField("What's it like out there?", text: $caption, axis: .vertical)
                        .font(.title3)
                        .lineLimit(1...4)
                        .textInputAutocapitalization(.sentences)
                        .focused($isCaptionFocused)
                        // The avatar is 44 tall and the field one line; nudged
                        // down so the first line sits against the circle's top.
                        .padding(.top, 8)

                    bumpy

                    photo

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        // Straight into the caption with the keyboard up — the photo is already
        // taken and the score has a sensible default, so writing something is
        // the only thing actually waiting on you.
        .task {
            guard caption.isEmpty else { return }
            // Focus set during the push transition gets dropped, so this waits
            // for the page to land before asking for the keyboard.
            try? await Task.sleep(for: .milliseconds(400))
            isCaptionFocused = true
        }
        .background(CardStyle.sheetSurface)
        .navigationBarTitleDisplayMode(.inline)
        // Replaced by the Retake button below, which is the same move under a
        // name that says what going back actually costs you.
        .navigationBarBackButtonHidden(true)
        .toolbar {
            // Gone while posting: there's nothing to go back to mid-upload.
            if !isPosting {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                            Text("Retake")
                        }
                        .foregroundStyle(.white)
                    }
                }
            }

            PrimaryToolbarButton("Post", isBusy: isPosting) {
                Task { await post() }
            }

            // The caption is multi-line, so Return makes a new line rather than
            // dismissing — this is the way out.
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isCaptionFocused = false }
                    .font(.body.weight(.semibold))
            }
        }
    }

    /// The shot, cropped at capture to exactly what the viewfinder showed — so
    /// this is the photo, not a version of it. Kept short because the sheet is,
    /// and the score and caption above it have to stay reachable.
    private var photo: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            // A definite height, not a maximum. `maxHeight` passes the parent's
            // open-ended height proposal straight through, so the photo sizes
            // itself to the column's *width* and overflows — the rounded rect
            // then clips a band out of the middle of it and the corners you see
            // are the crop, not the shape. A definite height is what makes the
            // frame match the photo, which is what makes the corners round.
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: PostImage.cornerRadius))
    }

    /// How bumpy it actually was, 0-100. The AI BumpyScore is a prediction; this
    /// is the person who was out there saying what it was really like.
    private var bumpy: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(Int(bumpyScore))")
                .contentTransition(.numericText())
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(scoreColor)

            // Tracks the number's color as it moves, so the control reads as the
            // same thing the score does.
            Slider(value: $bumpyScore, in: 0...100, step: 1)
                .tint(scoreColor)

            Text("How bumpy was it?")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        // A Slider is a standard control, so VoiceOver already reads and adjusts
        // it — only the label and the plain-words value need supplying.
        .accessibilityElement(children: .contain)
        .accessibilityLabel("How bumpy was it")
        .accessibilityValue("\(Int(bumpyScore)) out of 100, \(scoreDescription)")
    }

    /// Plain words for the number, so it isn't a bare score with no anchor.
    private var scoreDescription: String {
        switch bumpyScore {
        case ..<15: return "Glassy"
        case ..<35: return "Light chop"
        case ..<55: return "Choppy"
        case ..<75: return "Lumpy"
        case ..<90: return "Rough"
        default: return "Nasty"
        }
    }

    /// Matches the BumpyScore bar: 0 is glassy green, 100 is purple.
    private var scoreColor: Color {
        BumpyScoreColor.color(at: bumpyScore)
    }

    private func post() async {
        guard let userID = auth.user?.id else { return }

        isPosting = true
        errorMessage = nil
        defer { isPosting = false }

        do {
            let imageURL = try await ImageUploader().upload(image, kind: .post, userID: userID)
            let client = JebyClient(idToken: { [auth] in try await auth.idToken() })
            try await client.createPost(
                userID: userID,
                imageURL: imageURL.absoluteString,
                caption: caption.trimmingCharacters(in: .whitespacesAndNewlines),
                bumpyScore: Int(bumpyScore)
            )
            onPosted()
        } catch {
            errorMessage = "Couldn't post that. Check your connection and try again."
        }
    }
}
