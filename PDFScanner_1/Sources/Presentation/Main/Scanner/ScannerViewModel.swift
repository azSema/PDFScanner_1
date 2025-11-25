import SwiftUI
import Combine
import UniformTypeIdentifiers

@MainActor
final class ScannerViewModel: ObservableObject {
    
    @Published var isShowingScanner: Bool = false
    @Published var scannedImages: [UIImage] = []
    @Published var isProcessing: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Actions
    
    func startScanning() {
        isShowingScanner = true
    }
    
    func handleScanCompleted(images: [UIImage]) {
        isProcessing = true
        scannedImages = images
        
        // TODO: Process scanned images (convert to PDF, save, etc.)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isProcessing = false
            print("Scanned \(images.count) pages successfully")
        }
    }
    
    func handleScanCancelled() {
        isShowingScanner = false
        print("Scanning cancelled")
    }
    
    func handleScanError(_ error: Error) {
        isShowingScanner = false
        isProcessing = false
        print("Scanning error: \(error.localizedDescription)")
    }
    
    func clearScannedImages() {
        scannedImages.removeAll()
    }
}
