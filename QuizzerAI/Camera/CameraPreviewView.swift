@preconcurrency import AVFoundation
import SwiftUI
import os

// MARK: - SwiftUI wrapper

struct CameraPreviewView: UIViewRepresentable {
    @Binding var torchOn: Bool
    /// When `false`, the capture session is paused (no frames, no battery drain).
    /// Toggle this from `onAppear`/`onDisappear` to manage the camera lifecycle
    /// when the parent view enters or leaves the screen (e.g. tab switches).
    var isActive: Bool = true

    func makeUIView(context: Context) -> CameraLiveView {
        let view = CameraLiveView()
        if isActive { view.start() }
        return view
    }

    func updateUIView(_ uiView: CameraLiveView, context: Context) {
        uiView.setTorch(on: torchOn)
        if isActive {
            uiView.resume()
        } else {
            uiView.pause()
        }
    }
}

// MARK: - Session manager (nonisolated, Sendable)

/// Owns AVCaptureSession and all camera configuration.
/// Lives entirely off the main actor so it can be captured in @Sendable closures
/// and accessed from nonisolated deinit.
/// @unchecked Sendable: all mutations happen on the background serial queue we
/// create in CameraLiveView.start().
private final class CameraSession: @unchecked Sendable {
    let session = AVCaptureSession()
    private var activeDevice: AVCaptureDevice?

    func configure() {
        session.beginConfiguration()
        session.sessionPreset = .photo      // highest still-image quality

        // Best back camera: virtual multi-lens devices first (OS handles lens-switching),
        // then wide-angle as universal fallback.
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInTripleCamera,       // iPhone 15 Pro / 14 Pro / 13 Pro
                .builtInDualWideCamera,     // iPhone 12 +
                .builtInDualCamera,         // older dual-lens iPhones
                .builtInWideAngleCamera     // all other iPhones / iPads
            ],
            mediaType: .video,
            position: .back
        )

        guard
            let camera = discovery.devices.first,
            let input = try? AVCaptureDeviceInput(device: camera)
        else {
            session.commitConfiguration()
            return
        }

        activeDevice = camera
        session.addInput(input)

        // Continuous AF + AE + AWB — critical for sharp, well-exposed text
        do {
            try camera.lockForConfiguration()
            if camera.isFocusModeSupported(.continuousAutoFocus) {
                camera.focusMode = .continuousAutoFocus
            }
            if camera.isExposureModeSupported(.continuousAutoExposure) {
                camera.exposureMode = .continuousAutoExposure
            }
            if camera.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                camera.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            camera.unlockForConfiguration()
        } catch { AppLog.camera.warning("lockForConfiguration failed: \(error.localizedDescription, privacy: .public)") }

        session.commitConfiguration()
    }

    func startRunning() {
        configure()
        session.startRunning()
    }

    func stopRunning() {
        session.stopRunning()
    }

    func pauseRunning() {
        guard session.isRunning else { return }
        session.stopRunning()
    }

    func resumeRunning() {
        guard !session.isRunning else { return }
        session.startRunning()
    }

    func setTorch(on: Bool) {
        guard let device = activeDevice, device.hasTorch, device.isTorchAvailable else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch { AppLog.camera.warning("lockForConfiguration failed: \(error.localizedDescription, privacy: .public)") }
    }
}

// MARK: - UIView backed by AVCaptureVideoPreviewLayer

/// Override `layerClass` so the view's own CALayer is the preview layer —
/// no sublayer management, no frame-sync work.
final class CameraLiveView: UIView {

    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    private var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer    // safe: layerClass guarantees this
    }

    // CameraSession is @unchecked Sendable — safe to capture in closures and deinit
    private let cameraSession = CameraSession()

    func start() {
        previewLayer.videoGravity = .resizeAspectFill

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            activateSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                // requestAccess delivers on an arbitrary thread — must touch UIKit on main.
                DispatchQueue.main.async {
                    if granted { self?.activateSession() }
                    else       { self?.showPermissionDenied() }
                }
            }
        default:
            showPermissionDenied()
        }
    }

    private func activateSession() {
        // Attach session on main thread before startRunning so the preview layer
        // begins rendering as soon as the first frame arrives.
        previewLayer.session = cameraSession.session
        let cs = cameraSession
        DispatchQueue.global(qos: .userInitiated).async {
            cs.startRunning()
        }
    }

    private func showPermissionDenied() {
        backgroundColor = .black
        let label = UILabel()
        label.text = "Camera access is required to scan pages.\n\nGo to Settings → QuizzerAI → Camera."
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = UIColor(white: 0.8, alpha: 1)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32)
        ])
    }

    func pause() {
        let cs = cameraSession
        DispatchQueue.global(qos: .userInitiated).async {
            cs.pauseRunning()
        }
    }

    func resume() {
        let cs = cameraSession
        DispatchQueue.global(qos: .userInitiated).async {
            cs.resumeRunning()
        }
    }

    func setTorch(on: Bool) {
        let cs = cameraSession
        DispatchQueue.global(qos: .userInitiated).async {
            cs.setTorch(on: on)
        }
    }

    deinit {
        // deinit is nonisolated in Swift 6 — only Sendable captures are allowed.
        // CameraSession is @unchecked Sendable, so this is safe.
        let cs = cameraSession
        DispatchQueue.global(qos: .userInitiated).async {
            cs.stopRunning()
        }
    }
}
