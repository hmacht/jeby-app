//
//  CameraCaptureView.swift
//  Jeby
//
//  The camera page: a live preview in the same rounded 3:4 frame the report will
//  be shown in, with the shutter and its two companions floating over the bottom
//  of it. What you frame is what gets posted.
//

import AVFoundation
import SwiftUI

/// How a report is shown once taken. The corner radius is shared so the compose
/// page and anywhere else a report appears can't drift apart.
enum PostImage {
    static let cornerRadius: CGFloat = 16
}

struct CameraCaptureView: View {
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void

    @State private var camera = CameraSession()
    @State private var isAuthorized = false
    @State private var didCheckAccess = false
    @State private var isCapturing = false
    /// A counter rather than a Bool, so consecutive shots each fire their own
    /// haptic instead of only the first.
    @State private var shutterCount = 0
    /// The preview's on-screen shape, used to crop the capture to match. What
    /// you framed edge-to-edge is what gets posted.
    @State private var previewAspect: CGFloat = 3.0 / 4.0
    /// Fires the confirmation haptic when a shot lands, since the sensor takes a
    /// beat after the press.
    @State private var captureCount = 0

    var body: some View {
        ZStack {
            // The sheet's own gray, so the unavailable states read as part of the
            // app rather than as a camera roll.
            CardStyle.sheetSurface.ignoresSafeArea()

            if !CameraSession.isAvailable {
                unavailable(
                    title: "No camera",
                    message: "Reports are live photos from the water, so posting needs a camera. Try this on your phone."
                )
            } else if didCheckAccess && !isAuthorized {
                unavailable(
                    title: "Camera access off",
                    message: "Jeby needs the camera to post a report. Turn it on in Settings › Jeby."
                )
            } else {
                preview
            }
        }
        .task {
            guard CameraSession.isAvailable else {
                didCheckAccess = true
                return
            }
            isAuthorized = await CameraSession.requestAccess()
            didCheckAccess = true
            if isAuthorized { camera.start() }
        }
        .onDisappear { camera.stop() }
    }

    /// Edge to edge — the camera is the whole page, with the controls floating
    /// over it rather than sitting beside it.
    private var preview: some View {
        GeometryReader { geometry in
            CameraPreview(session: camera.session)
                .onAppear { previewAspect = geometry.size.width / geometry.size.height }
                .onChange(of: geometry.size) { _, size in
                    previewAspect = size.width / size.height
                }
        }
        .ignoresSafeArea()
        .overlay {
            // The sensor takes a moment, especially in low light. Without this
            // the shutter looks like it did nothing.
            if isCapturing {
                ZStack {
                    Color.black.opacity(0.35)
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                }
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) { controls }
        .animation(.easeInOut(duration: 0.15), value: isCapturing)
    }

    private var controls: some View {
        HStack {
            circleButton(icon: "chevron.left", action: onCancel)
                .accessibilityLabel("Cancel")

            Spacer()

            shutter

            Spacer()

            circleButton(icon: "arrow.triangle.2.circlepath", action: camera.flip)
                .accessibilityLabel("Flip camera")
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private var shutter: some View {
        Button(action: capture) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.9), lineWidth: 3)
                    .frame(width: 76, height: 76)

                Circle()
                    .fill(.white)
                    .frame(width: 62, height: 62)
                    .scaleEffect(isCapturing ? 0.86 : 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isCapturing)
        .animation(.snappy(duration: 0.15), value: isCapturing)
        // Heavier than the button that opened the camera — this one is the
        // shutter, and it should feel like it.
        .sensoryFeedback(.impact(weight: .heavy), trigger: shutterCount)
        // And a lighter confirmation when the shot actually lands, since the
        // sensor takes a beat after the press.
        .sensoryFeedback(.success, trigger: captureCount)
        .accessibilityLabel("Take photo")
    }

    private func circleButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(.black.opacity(0.35), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func capture() {
        shutterCount += 1
        isCapturing = true
        let aspect = previewAspect

        camera.capturePhoto { data in
            Task { @MainActor in
                isCapturing = false
                // Built here rather than on the capture queue because UIImage
                // isn't worth passing across threads — Data is.
                guard let data, let image = UIImage(data: data) else { return }
                captureCount += 1
                // The sensor shoots 4:3; the preview showed a full-screen crop of
                // it. Without this the report would include a band the person
                // never saw, above and below what they framed.
                onCapture(image.cropped(toAspectRatio: aspect))
            }
        }
    }

    private func unavailable(title: String, message: String) -> some View {
        VStack(spacing: 20) {
            ContentUnavailableView {
                Label(title, systemImage: "camera.fill")
            } description: {
                Text(message)
            }

            Button("Cancel", action: onCancel)
                .font(.subheadline.weight(.semibold))
        }
    }
}

/// Hosts the live preview layer.
private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        // The app is portrait-locked, so the angle is fixed rather than tracked.
        view.previewLayer.connection?.videoRotationAngle = 90
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer {
            // Safe by construction: layerClass above guarantees the type.
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
