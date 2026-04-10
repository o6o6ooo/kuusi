import AVFoundation
import SwiftUI
import UIKit

struct QRCodeScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onCode: (String) -> Void
    @State private var scanError: String?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                QRCodeCameraView(
                    onCode: { code in
                        onCode(code)
                        dismiss()
                    },
                    onError: { message in
                        scanError = message
                    }
                )
                .ignoresSafeArea()

                if let scanError {
                    Text(scanError)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.errorText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.bottom, 20)
                }
            }
            .navigationTitle("Scan QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .appOverlayTheme()
        }
    }
}

private struct QRCodeCameraView: UIViewRepresentable {
    let onCode: (String) -> Void
    let onError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCode, onError: onError)
    }

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        context.coordinator.configureSession(previewView: view)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {}

    static func dismantleUIView(_ uiView: CameraPreviewView, coordinator: Coordinator) {
        coordinator.stopSession()
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        private let onCode: (String) -> Void
        private let onError: (String) -> Void
        private var session: AVCaptureSession?
        private var didScan = false

        init(onCode: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
            self.onCode = onCode
            self.onError = onError
        }

        func configureSession(previewView: CameraPreviewView) {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                setupCaptureSession(previewView: previewView)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    DispatchQueue.main.async {
                        guard let self else { return }
                        if granted {
                            self.setupCaptureSession(previewView: previewView)
                        } else {
                            self.onError("Camera permission was denied")
                        }
                    }
                }
            case .denied, .restricted:
                onError("Enable camera access in Settings")
            @unknown default:
                onError("Camera is unavailable")
            }
        }

        func stopSession() {
            session?.stopRunning()
            session = nil
        }

        private func setupCaptureSession(previewView: CameraPreviewView) {
            let session = AVCaptureSession()
            guard let device = AVCaptureDevice.default(for: .video) else {
                onError("Camera is unavailable")
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: device)
                guard session.canAddInput(input) else {
                    onError("Failed to configure camera input")
                    return
                }
                session.addInput(input)
            } catch {
                onError(error.localizedDescription)
                return
            }

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else {
                onError("Failed to configure camera output")
                return
            }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]

            previewView.previewLayer.session = session
            previewView.previewLayer.videoGravity = .resizeAspectFill
            self.session = session
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard !didScan else { return }
            guard
                let qrObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                let stringValue = qrObject.stringValue
            else {
                return
            }
            didScan = true
            stopSession()
            onCode(stringValue)
        }
    }
}

private final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
