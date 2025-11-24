import SwiftUI
import Combine
import PDFKit

enum MergeState {
    case idle
    case selectDocuments
    case arrangeOrder
    case processing
    case preview(URL)
    case completed
    case error(Error)
}

@MainActor
final class MergeService: ObservableObject {
    
    @Published var state: MergeState = .idle
    @Published var selectedDocuments: Set<String> = []
    @Published var arrangedDocuments: [DocumentDTO] = []
    @Published var isProcessing: Bool = false
    @Published var draggedItem: DocumentDTO?
    @Published var dragOffset: CGSize = .zero
    @Published var mergedPDFURL: URL?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupStateBindings()
    }
    
    // MARK: - Public Methods
    
    func startMergeFlow() {
        state = .selectDocuments
        selectedDocuments.removeAll()
        arrangedDocuments.removeAll()
        mergedPDFURL = nil
        DELogger.log(text: "Started merge flow")
    }
    
    func toggleDocumentSelection(for documentId: String) {
        if selectedDocuments.contains(documentId) {
            selectedDocuments.remove(documentId)
        } else {
            selectedDocuments.insert(documentId)
        }
        DELogger.log(text: "Toggled document selection: \(documentId), total: \(selectedDocuments.count)")
    }
    
    func proceedToArrangeOrder(with documents: [DocumentDTO]) {
        let selectedDocs = documents.filter { selectedDocuments.contains($0.id) }
        arrangedDocuments = selectedDocs
        state = .arrangeOrder
        
        DELogger.log(text: "Proceeding to arrange stage with \(selectedDocs.count) documents")
        for (index, doc) in selectedDocs.enumerated() {
            DELogger.log(text: "  \(index + 1). \(doc.name)")
        }
    }
    
    func moveDocument(from fromIndex: Int, to toIndex: Int) {
        DELogger.log(text: "🔄 moveDocument called: from=\(fromIndex), to=\(toIndex)")
        DELogger.log(text: "📋 Current documents count: \(arrangedDocuments.count)")
        
        guard fromIndex != toIndex,
              fromIndex < arrangedDocuments.count,
              toIndex < arrangedDocuments.count else { 
            DELogger.log(text: "❌ Move cancelled: fromIndex=\(fromIndex), toIndex=\(toIndex), count=\(arrangedDocuments.count)")
            return 
        }
        
        let document = arrangedDocuments[fromIndex]
        DELogger.log(text: "📱 Moving document: \(document.name)")
        
        arrangedDocuments.remove(at: fromIndex)
        arrangedDocuments.insert(document, at: toIndex)
        
        DELogger.log(text: "✅ Move completed. New order:")
        for (index, doc) in arrangedDocuments.enumerated() {
            DELogger.log(text: "  \(index + 1). \(doc.name)")
        }
    }
    
    func startMergeProcess() {
        state = .processing
        isProcessing = true
        
        DELogger.log(text: "Starting merge process with \(arrangedDocuments.count) documents")
        
        // Extract URLs from arranged documents
        let urls = arrangedDocuments.compactMap { $0.url }
        
        // Perform merge in background
        Task {
            if let mergedURL = await mergePDFs(urls: urls) {
                await MainActor.run {
                    self.mergedPDFURL = mergedURL
                    self.state = .preview(mergedURL)
                    DELogger.log(text: "✅ Merge completed successfully: \(mergedURL.lastPathComponent)")
                }
            } else {
                await MainActor.run {
                    self.state = .error(MergeError.processingFailed)
                    DELogger.log(text: "❌ Merge failed")
                }
            }
        }
    }
    
    func saveMergedDocument(to pdfStorage: PDFStorage, with name: String) async throws {
        guard let mergedURL = mergedPDFURL,
              let pdfDocument = PDFDocument(url: mergedURL) else {
            throw MergeError.savingFailed
        }
        
        let document = DocumentDTO(
            id: UUID().uuidString,
            pdf: pdfDocument,
            name: name.isEmpty ? "Merged Document" : name,
            type: .pdf,
            date: Date(),
            url: nil,
            isFavorite: false
        )
        
        try await pdfStorage.saveDocument(document)
        
        // Clean up temp file
        try? FileManager.default.removeItem(at: mergedURL)
        
        DELogger.log(text: "✅ Merged document saved: \(document.name)")
        
        state = .completed
    }
    
    func cancelMerge() {
        // Clean up temp file if exists
        if let tempURL = mergedPDFURL {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        state = .idle
        selectedDocuments.removeAll()
        arrangedDocuments.removeAll()
        isProcessing = false
        draggedItem = nil
        dragOffset = .zero
        mergedPDFURL = nil
        
        DELogger.log(text: "Merge flow cancelled")
    }
    
    func resetToIdle() {
        // Clean up temp file if exists
        if let tempURL = mergedPDFURL {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        state = .idle
        selectedDocuments.removeAll()
        arrangedDocuments.removeAll()
        isProcessing = false
        draggedItem = nil
        dragOffset = .zero
        mergedPDFURL = nil
    }
    
    // MARK: - Computed Properties
    
    var canProceedToArrange: Bool {
        selectedDocuments.count >= 2
    }
    
    var canStartMerge: Bool {
        if case .arrangeOrder = state {
            return !arrangedDocuments.isEmpty
        }
        return false
    }
    
    // MARK: - Private Methods
    
    private func setupStateBindings() {
        $state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.handleStateChange(newState)
            }
            .store(in: &cancellables)
    }
    
    private func handleStateChange(_ newState: MergeState) {
        switch newState {
        case .idle:
            isProcessing = false
            
        case .selectDocuments:
            isProcessing = false
            
        case .arrangeOrder:
            isProcessing = false
            
        case .processing:
            isProcessing = true
            
        case .preview:
            isProcessing = false
            DELogger.log(text: "Merge preview ready")
            
        case .completed:
            isProcessing = false
            DELogger.log(text: "Merge process completed successfully")
            
        case .error(let error):
            isProcessing = false
            DELogger.log(text: "Merge error: \(error.localizedDescription)")
        }
    }
    
    private func mergePDFs(urls: [URL]) async -> URL? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = self.performMergePDFs(urls: urls)
                continuation.resume(returning: result)
            }
        }
    }
    
    nonisolated private func performMergePDFs(urls: [URL]) -> URL? {
        let outputPDF = PDFDocument()
        var pageIndex = 0

        for url in urls {
            let canAccess = url.startAccessingSecurityScopedResource()
            defer { if canAccess { url.stopAccessingSecurityScopedResource() } }
            
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("Файл не существует по указанному пути: \(url.path)")
                continue
            }
            
            guard let pdf = PDFDocument(url: url) else {
                print("Cant get pdf from: \(url)")
                continue
            }
            
            for i in 0..<pdf.pageCount {
                if let page = pdf.page(at: i) {
                    outputPDF.insert(page, at: pageIndex)
                    pageIndex += 1
                }
            }
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("merged_\(UUID().uuidString).pdf")
                
        return outputPDF.write(to: fileURL) ? fileURL : nil
    }
}

// MARK: - Merge Errors

enum MergeError: LocalizedError {
    case insufficientDocuments
    case processingFailed
    case savingFailed
    
    var errorDescription: String? {
        switch self {
        case .insufficientDocuments:
            return "At least 2 documents are required for merging"
        case .processingFailed:
            return "Failed to process documents for merging"
        case .savingFailed:
            return "Failed to save merged document"
        }
    }
}