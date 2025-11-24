import Foundation
import PDFKit
import SwiftUI
import Combine

@MainActor
final class PDFStorage: ObservableObject {
    
    @Published var documents: [DocumentDTO] = []
    @Published var isLoading = false
    
    private let fileManager = FileManager.default
    private let documentsDirectory: URL
    
    init() {
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PDFScanner", isDirectory: true)
        
        createDocumentsDirectoryIfNeeded()
        loadDocuments()
        loadSampleDocuments()
    }
    
    // MARK: - Public Methods
    
    func addDocument(_ document: DocumentDTO) {
        documents.append(document)
    }
    
    func removeDocument(withId id: String) {
        documents.removeAll { $0.id == id }
        // TODO: Also remove from file system
    }
    
    func saveDocument(_ document: DocumentDTO) async throws {
        guard let pdfDocument = document.pdf else {
            throw PDFStorageError.invalidPDF
        }
        
        let fileName = "\(document.id).pdf"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        // Save PDF to documents directory
        guard pdfDocument.write(to: fileURL) else {
            throw PDFStorageError.saveFailed
        }
        
        // Update document with file URL
        var updatedDocument = document
        updatedDocument.url = fileURL
        
        // Add or update in documents array
        if let index = documents.firstIndex(where: { $0.id == document.id }) {
            documents[index] = updatedDocument
        } else {
            documents.append(updatedDocument)
        }
    }
    
    func loadDocuments() {
        isLoading = true
        
        // Load documents from documents directory
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: documentsDirectory,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            ).filter { $0.pathExtension.lowercased() == "pdf" }
            
            for fileURL in fileURLs {
                if let document = createDocumentFromFile(at: fileURL) {
                    documents.append(document)
                }
            }
        } catch {
            print("Failed to load documents: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Private Methods
    
    private func createDocumentsDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: documentsDirectory.path) {
            try? fileManager.createDirectory(
                at: documentsDirectory,
                withIntermediateDirectories: true
            )
        }
    }
    
    private func createDocumentFromFile(at url: URL) -> DocumentDTO? {
        guard let pdfDocument = PDFDocument(url: url) else { return nil }
        
        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        let creationDate = attributes?[.creationDate] as? Date ?? Date()
        
        return DocumentDTO(
            id: url.deletingPathExtension().lastPathComponent,
            pdf: pdfDocument,
            name: url.deletingPathExtension().lastPathComponent,
            type: .pdf,
            date: creationDate,
            url: url,
            isFavorite: false
        )
    }
    
    private func loadSampleDocuments() {
        // Load sample PDFs from Bundle
        print("📄 Loading sample documents...")
        loadBundlePDF(named: "pdf1", displayName: "Sample Document 1")
        loadBundlePDF(named: "pdf2", displayName: "Sample Document 2")
        
        print("📄 Loaded \(documents.count) documents from Bundle")
    }
    
    private func loadBundlePDF(named fileName: String, displayName: String) {
        print("📄 Attempting to load \(fileName).pdf from Bundle...")
        
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "pdf") else {
            print("❌ Could not find \(fileName).pdf in Bundle")
            return
        }
        
        print("📄 Found PDF at: \(url)")
        
        guard let pdfDocument = PDFDocument(url: url) else {
            print("❌ Could not create PDFDocument from \(fileName).pdf")
            return
        }
        
        print("✅ Successfully loaded \(fileName).pdf with \(pdfDocument.pageCount) pages")
        
        let mockDocument = DocumentDTO(
            id: UUID().uuidString,
            pdf: pdfDocument,
            name: displayName,
            type: .pdf,
            date: Date().addingTimeInterval(-Double.random(in: 86400...604800)), // 1-7 days ago
            url: url,
            isFavorite: Bool.random()
        )
        
        documents.append(mockDocument)
    }
}

// MARK: - Errors

enum PDFStorageError: Error, LocalizedError {
    case invalidPDF
    case saveFailed
    case loadFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidPDF:
            return "Invalid PDF document"
        case .saveFailed:
            return "Failed to save PDF document"
        case .loadFailed:
            return "Failed to load PDF document"
        }
    }
}