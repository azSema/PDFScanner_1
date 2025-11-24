import SwiftUI
import Combine

@MainActor
final class ConversionViewModel: ObservableObject {
    
    @Published private(set) var conversionService: ConversionService
    @Published var showingDocumentSelection = false
    @Published var showingPreview = false
    @Published var showingError = false
    @Published var errorMessage = ""
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.conversionService = ConversionService()
        observeConversionState()
    }
    
    // MARK: - Public Methods
    
    func startConversion() {
        showingDocumentSelection = true
    }
    
    func documentSelected(_ document: DocumentDTO) {
        conversionService.selectDocument(document)
        showingDocumentSelection = false
    }
    
    func reset() {
        // Clean up temporary files
        if case .completed(let urls) = conversionService.state {
            cleanupTempFiles(urls)
        }
        
        conversionService.reset()
        showingDocumentSelection = false
        showingPreview = false
        showingError = false
    }
    
    private func cleanupTempFiles(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
        
        // Also clean up the directory if empty
        if let firstURL = urls.first {
            let parentDir = firstURL.deletingLastPathComponent()
            try? FileManager.default.removeItem(at: parentDir)
        }
    }
    
    // MARK: - Private Methods
    
    private func observeConversionState() {
        conversionService.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                switch state {
                case .completed(_):
                    self?.showingPreview = true
                case .failed(let error):
                    self?.errorMessage = error.localizedDescription
                    self?.showingError = true
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Computed Properties

extension ConversionViewModel {
    var isProcessing: Bool {
        conversionService.isProcessing
    }
    
    var canStartConversion: Bool {
        conversionService.canStartConversion
    }
    
    var selectedDocument: DocumentDTO? {
        conversionService.selectedDocument
    }
    
    var resultURLs: [URL] {
        if case .completed(let urls) = conversionService.state {
            return urls
        }
        return []
    }
}