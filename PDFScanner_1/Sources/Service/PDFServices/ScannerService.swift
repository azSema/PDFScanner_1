import SwiftUI
import Combine
import VisionKit
import PDFKit

@MainActor
final class ScannerService: ObservableObject {
    @Published var state: ScannerState = .idle
    @Published var isShowingScanner: Bool = false
    @Published var scannedImages: [UIImage] = []
    @Published var isProcessing: Bool = false
    @Published var isSupported: Bool = false
    
    private let pdfStorage: PDFStorage
    private var cancellables = Set<AnyCancellable>()
    
    init(pdfStorage: PDFStorage) {
        self.pdfStorage = pdfStorage
        checkDeviceSupport()
        setupStateBindings()
    }
    
    // MARK: - Public Methods
    
    func startScanning() {
        guard isSupported else {
            DELogger.log(text: "Document scanning is not supported on this device")
            state = .error(ScannerError.deviceNotSupported)
            return
        }
        
        state = .scanning
        isShowingScanner = true
        DELogger.log(text: "Started document scanning")
    }
    
    func handleScanCompleted(images: [UIImage]) {
        DELogger.log(text: "Scan completed with \(images.count) images")
        
        scannedImages = images
        isShowingScanner = false
        state = .processing
        isProcessing = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.completeScanProcessing(images: images)
        }
    }
    
    func handleScanCancelled() {
        DELogger.log(text: "Scanning cancelled by user")
        
        isShowingScanner = false
        isProcessing = false
        state = .idle
        clearScannedImages()
    }
    
    func handleScanError(_ error: Error) {
        DELogger.log(text: "Scanning error: \(error.localizedDescription)")
        
        isShowingScanner = false
        isProcessing = false
        state = .error(error)
        clearScannedImages()
    }
    
    func clearScannedImages() {
        scannedImages.removeAll()
        isProcessing = false
        state = .idle
    }
    
    func resetToIdle() {
        state = .idle
        isProcessing = false
        isShowingScanner = false
    }
}

private extension ScannerService {
    func checkDeviceSupport() {
        isSupported = VNDocumentCameraViewController.isSupported
        DELogger.log(text: "Scanner device support: \(isSupported)")
    }
    
    func setupStateBindings() {
        $state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.handleStateChange(newState)
            }
            .store(in: &cancellables)
    }
    
    func handleStateChange(_ newState: ScannerState) {
        switch newState {
        case .idle:
            isProcessing = false
        case .scanning:
            isProcessing = false
        case .processing:
            isProcessing = true
        case .completed(let document):
            isProcessing = false
            DELogger.log(text: "Scan processing completed for \(document.name)")
        case .error(let error):
            isProcessing = false
            DELogger.log(text: "Scanner error: \(error.localizedDescription)")
        }
    }
    
    func completeScanProcessing(images: [UIImage]) {
        guard let pdf = makePDF(from: images) else {
            state = .error(ScannerError.processingFailed)
            return
        }
        
        let document = DocumentDTO(
            id: UUID().uuidString,
            pdf: pdf,
            name: makeDocumentName(),
            type: .pdf,
            date: .now,
            url: nil,
            isFavorite: false
        )
        
        Task {
            do {
                try await pdfStorage.saveDocument(document)
                state = .completed(document)
                DELogger.log(text: "Scan processing completed and saved")
            } catch {
                state = .error(error)
            }
        }
    }
    
    func makePDF(from images: [UIImage]) -> PDFDocument? {
        let document = PDFDocument()
        for (index, image) in images.enumerated() {
            guard let page = PDFPage(image: image) else { return nil }
            document.insert(page, at: index)
        }
        return document
    }
    
    func makeDocumentName() -> String {
        "Scan \(DateFormatter.localizedString(from: .now, dateStyle: .short, timeStyle: .short))"
    }
}
