//
//  CameraSession.swift
//  Jeby
//
//  The capture session behind the custom camera. AVFoundation rather than
//  UIImagePickerController so the shutter and the preview are ours to style —
//  and so there's no route to the photo library, which would let someone post a
//  shot from any day in any conditions.
//
//  Everything that touches the session runs on `queue`; the only things crossing
//  back are Sendable (Data and Bool), which is what makes the unchecked
//  conformance honest.
//

import AVFoundation
import UIKit

final class CameraSession: @unchecked Sendable {

    /// Handed to the preview layer on the main thread. AVCaptureSession is safe
    /// to reference from multiple threads; it's *configuring* it that Apple says
    /// to keep off the main queue.
    let session = AVCaptureSession()

    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "org.jeby.camera.session")
    private var position: AVCaptureDevice.Position = .back
    private var input: AVCaptureDeviceInput?
    private var isConfigured = false
    /// Held for the duration of a capture — AVFoundation keeps only a weak
    /// reference to the delegate, so without this it deallocates mid-shot.
    private var captureDelegate: PhotoCaptureDelegate?

    /// False in the simulator and on the rare device without one.
    static var isAvailable: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    /// Asks for camera permission. Returns false if the user has ever said no —
    /// the view then points them at Settings.
    static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    /// Configures on first call, then starts running. Safe to call again.
    func start() {
        queue.async { [self] in
            if !isConfigured {
                configure()
                isConfigured = true
            }
            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    /// Swaps between the front and back cameras.
    func flip() {
        queue.async { [self] in
            position = position == .back ? .front : .back
            session.beginConfiguration()
            if let input {
                session.removeInput(input)
            }
            addInput()
            session.commitConfiguration()
        }
    }

    /// Takes a photo. The handler gets JPEG data, or nil if the shot failed.
    func capturePhoto(completion: @escaping @Sendable (Data?) -> Void) {
        queue.async { [self] in
            let settings = AVCapturePhotoSettings()
            // The front camera previews mirrored, so the capture should match
            // what the person was looking at.
            if let connection = output.connection(with: .video) {
                connection.videoRotationAngle = 90
                if connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = position == .front
                }
            }

            let delegate = PhotoCaptureDelegate { [weak self] data in
                completion(data)
                self?.queue.async { self?.captureDelegate = nil }
            }
            captureDelegate = delegate
            output.capturePhoto(with: settings, delegate: delegate)
        }
    }

    // MARK: - Configuration

    private func configure() {
        session.beginConfiguration()
        // .photo gives the sensor's native 4:3, which is exactly the 3:4 the
        // preview shows in portrait — so what you frame is what you get, with
        // nothing cropped away afterwards.
        session.sessionPreset = .photo

        addInput()
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        session.commitConfiguration()
    }

    private func addInput() {
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
            let deviceInput = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(deviceInput)
        else {
            input = nil
            return
        }
        session.addInput(deviceInput)
        input = deviceInput
    }
}

/// Bridges AVFoundation's delegate callback to a closure.
private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: @Sendable (Data?) -> Void

    init(completion: @escaping @Sendable (Data?) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        completion(error == nil ? photo.fileDataRepresentation() : nil)
    }
}
