import SwiftUI
import Combine
import UniformTypeIdentifiers

@MainActor
final class DashboardViewModel: ObservableObject {
    
    @Published var recentDocuments: [DocumentDTO] = []
    @Published var isFloatingMenuOpen: Bool = false
    @Published var isLoading: Bool = false
    @Published var isShowingFileImporter: Bool = false
    
    // Scanner-related published properties
    @Published var isShowingScanner: Bool = false
    @Published var isProcessingScanner: Bool = false
    @Published var isScannerSupported: Bool = false
    
    // Scanner service integration
    let scannerService = ScannerService()
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadRecentDocuments()
        setupScannerBindings()
    }
    
    // MARK: - Actions
    
    var allowedContentTypes: [UTType] {
        return [.pdf]
    }
    
    func loadRecentDocuments() {
        isLoading = true
        
        // TODO: Load actual documents from storage
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.recentDocuments = []
            self.isLoading = false
        }
    }
    
    func refreshData() {
        loadRecentDocuments()
    }
    
    func showFileImporter() {
        isShowingFileImporter = true
    }
    
    func handleImportedFiles(_ urls: [URL]) {
        // TODO: Process imported files
        for url in urls {
            print("Imported file: \(url.lastPathComponent)")
        }
        isShowingFileImporter = false
    }
    
    // MARK: - Scanner Integration
    
    func startScanning() {
        scannerService.startScanning()
    }
    
    func handleScanCompleted(images: [UIImage]) {
        scannerService.handleScanCompleted(images: images)
    }
    
    func handleScanCancelled() {
        scannerService.handleScanCancelled()
    }
    
    func handleScanError(_ error: Error) {
        scannerService.handleScanError(error)
    }
    
    // MARK: - Quick Actions
    
    func openScanner() {
        isFloatingMenuOpen = false
        startScanning()
    }
    
    func openConverter() {
        isFloatingMenuOpen = false
    }
    
    func openEditor() {
        isFloatingMenuOpen = false
    }
    
    func openMerge() {
        isFloatingMenuOpen = false
    }
    
    func openHistory() {
        isFloatingMenuOpen = false
    }
    
    // MARK: - Private Setup
    
    private func setupScannerBindings() {
        // Bind scanner state to handle completed scans
        scannerService.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleScannerStateChange(state)
            }
            .store(in: &cancellables)
        
        // Sync scanner properties with ViewModel published properties
        scannerService.$isShowingScanner
            .receive(on: DispatchQueue.main)
            .assign(to: &$isShowingScanner)
        
        scannerService.$isProcessing
            .receive(on: DispatchQueue.main)
            .assign(to: &$isProcessingScanner)
        
        scannerService.$isSupported
            .receive(on: DispatchQueue.main)
            .assign(to: &$isScannerSupported)
    }
    
    private func handleScannerStateChange(_ state: ScannerState) {
        switch state {
        case .completed(let images):
            // Handle successful scan completion
            // TODO: Add to recent documents, navigate to result screen, etc.
            DELogger.log(text: "Successfully scanned \(images.count) pages")
            
        case .error(let error):
            // Handle scan error
            DELogger.log(text: "Scanner error: \(error.localizedDescription)")
            // TODO: Show error alert to user
            
        default:
            break
        }
    }
}