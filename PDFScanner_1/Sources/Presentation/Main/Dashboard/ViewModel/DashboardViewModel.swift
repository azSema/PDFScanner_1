import SwiftUI
import Combine
import UniformTypeIdentifiers
import PDFKit

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var recentDocuments: [DocumentDTO] = []
    @Published var isFloatingMenuOpen: Bool = false
    @Published var isLoading: Bool = false
    @Published var isShowingFileImporter: Bool = false
    
    @Published var isShowingScanner: Bool = false
    @Published var isProcessingScanner: Bool = false
    @Published var isScannerSupported: Bool = false
    
    private var scannerService: ScannerService?
    private weak var pdfStorage: PDFStorage?
    
    private var cancellables = Set<AnyCancellable>()
    private var didConfigure = false
    
    // MARK: - Public API
    
    var allowedContentTypes: [UTType] { [.pdf] }
    
    func configure(pdfStorage: PDFStorage) {
        guard !didConfigure else { return }
        didConfigure = true
        
        self.pdfStorage = pdfStorage
        self.scannerService = ScannerService(pdfStorage: pdfStorage)
        
        loadRecentDocuments()
        setupScannerBindings()
        setupPDFStorageObserver()
    }
    
    func loadRecentDocuments() {
        guard let pdfStorage else { return }
        recentDocuments = pdfStorage.documents
    }
    
    func processImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            DELogger.log(text: "Processing \(urls.count) imported files")
            Task {
                await processImportedFiles(urls)
            }
        case .failure(let error):
            DELogger.log(text: "File import error: \(error.localizedDescription)")
        }
        isShowingFileImporter = false
    }
    
    // MARK: Scanner actions
    
    func startScanning() {
        scannerService?.startScanning()
    }
    
    func handleScanCompleted(images: [UIImage]) {
        scannerService?.handleScanCompleted(images: images)
    }
    
    func handleScanCancelled() {
        scannerService?.handleScanCancelled()
    }
    
    func handleScanError(_ error: Error) {
        scannerService?.handleScanError(error)
    }
}

// MARK: - Private helpers

private extension DashboardViewModel {
    func setupScannerBindings() {
        guard let scannerService else { return }
        
        scannerService.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleScannerStateChange(state)
            }
            .store(in: &cancellables)
        
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
    
    func handleScannerStateChange(_ state: ScannerState) {
        DELogger.log(text: "Scanner state changed: \(state)")
        
        switch state {
        case .completed(let document):
            DELogger.log(text: "Appending document \(document.name)")
            // recentDocuments обновится автоматически через setupPDFStorageObserver
        case .error(let error):
            DELogger.log(text: "Scanner error surfaced: \(error.localizedDescription)")
        default:
            break
        }
    }
    
    func processImportedFiles(_ urls: [URL]) async {
        guard let pdfStorage else {
            DELogger.log(text: "PDFStorage is not configured")
            return
        }
        
        for url in urls {
            do {
                guard url.pathExtension.lowercased() == "pdf" else {
                    DELogger.log(text: "Skipping non-PDF file: \(url.lastPathComponent)")
                    continue
                }
                
                // 1. Получаем доступ к security-scoped ресурсу
                let hasAccess = url.startAccessingSecurityScopedResource()
                defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
                
                // 2. Читаем данные и создаём PDFDocument
                let data = try Data(contentsOf: url)
                guard let pdfDocument = PDFDocument(data: data) else {
                    DELogger.log(text: "Failed to load PDF from: \(url.lastPathComponent)")
                    continue
                }
                
                // 3. Создаём DTO и сохраняем как обычно
                let document = DocumentDTO(
                    id: UUID().uuidString,
                    pdf: pdfDocument,
                    name: url.deletingPathExtension().lastPathComponent,
                    type: .pdf,
                    date: .now,
                    url: nil,
                    isFavorite: false
                )
                
                try await pdfStorage.saveDocument(document)
                DELogger.log(text: "Successfully imported and saved: \(document.name)")
            } catch {
                DELogger.log(text: "Error processing file \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }
    
    func setupPDFStorageObserver() {
        guard let pdfStorage else { return }
        
        pdfStorage.$documents
            .receive(on: DispatchQueue.main)
            .sink { [weak self] documents in
                self?.recentDocuments = documents
            }
            .store(in: &cancellables)
    }
}
