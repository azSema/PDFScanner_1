import SwiftUI
import VisionKit

struct DocumentCameraScannerView: UIViewControllerRepresentable {
    
    let onScanCompleted: @MainActor ([UIImage]) -> Void
    let onScanCancelled: @MainActor () -> Void
    let onScanError: @MainActor (Error) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentCameraScannerView
        
        init(_ parent: DocumentCameraScannerView) {
            self.parent = parent
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            controller.dismiss(animated: true)
            
            Task {
                let images = await extractImages(from: scan)
                await MainActor.run {
                    self.parent.onScanCompleted(images)
                }
            }
        }
        
        private func extractImages(from scan: VNDocumentCameraScan) async -> [UIImage] {
            var images: [UIImage] = []
            for i in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: i))
            }
            return images
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
            Task { @MainActor in
                self.parent.onScanCancelled()
            }
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true)
            Task { @MainActor in
                self.parent.onScanError(error)
            }
        }
    }
}