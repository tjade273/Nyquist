import SwiftUI
import AVFoundation

struct QRCodeScannerView: NSViewRepresentable {

    @Binding var peerQR: URL?;
    @Binding var transferReady: Bool
    
    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        var parent: QRCodeScannerView
        
        init(parent: QRCodeScannerView) {
            self.parent = parent
        }
    
        
        let qrDetector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: nil)!

        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            let ciImage = CIImage(cvImageBuffer: imageBuffer)
            let features = qrDetector.features(in: ciImage)

            for feature in features {
                let qrCodeFeature = feature as! CIQRCodeFeature
                print("messageString \(qrCodeFeature.messageString!)")
                parent.peerQR = URL(string: qrCodeFeature.messageString!)
                parent.session.stopRunning()
                parent.transferReady = true
            }
        }

        
    }
    
    let session = AVCaptureSession()
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let captureDevice = AVCaptureDevice.default(for: .video)
        
        if let videoInput = try? AVCaptureDeviceInput(device: captureDevice!), session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            print("Failed to create video input")
        }
        logger.log("Capture device: \(captureDevice?.description)")

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds // Adjust this line
        previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable] // Ensure the layer resizes
        view.layer = previewLayer
        view.wantsLayer = true // Important for macOS
        
        let qrOutput = AVCaptureVideoDataOutput()
        if session.canAddOutput(qrOutput) {
            session.addOutput(qrOutput)
            
            qrOutput.setSampleBufferDelegate(context.coordinator, queue: DispatchQueue.main)
        } else {
            logger.log("Failed to add QR decoder output")
        }
        
        session.startRunning()
        
        return view
    }
    

    func updateNSView(_ nsView: NSView, context: Context) {
        // Update your NSView if needed
    }}

