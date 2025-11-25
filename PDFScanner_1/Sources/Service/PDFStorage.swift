import Foundation
import PDFKit
import SwiftUI
import Combine

struct DocumentMetadata: Codable {
    let id: String
    var name: String
    var isFavorite: Bool
    let dateCreated: Date
    
    init(id: String, name: String, isFavorite: Bool = false, dateCreated: Date = Date()) {
        self.id = id
        self.name = name
        self.isFavorite = isFavorite
        self.dateCreated = dateCreated
    }
}

@MainActor
final class PDFStorage: ObservableObject {
    
    @Published var documents: [DocumentDTO] = []
    @Published var isLoading = false
    
    private let fileManager = FileManager.default
    private let documentsDirectory: URL
    private let metadataDirectory: URL
    
    init() {
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PDFScanner", isDirectory: true)
        
        metadataDirectory = documentsDirectory.appendingPathComponent("Metadata", isDirectory: true)
        
        createDocumentsDirectoryIfNeeded()
        loadDocuments()
    }
    
    // MARK: - Public Methods
    
    func addDocument(_ document: DocumentDTO) {
        documents.append(document)
    }
    
    func removeDocument(_ document: DocumentDTO) {
        documents.removeAll { $0.id == document.id }
        
        // Remove PDF file
        if let url = document.url, url.path.contains("PDFScanner") {
            try? fileManager.removeItem(at: url)
        }
        
        // Remove metadata file
        let metadataURL = metadataDirectory.appendingPathComponent("\(document.id).json")
        try? fileManager.removeItem(at: metadataURL)
    }
    
    func toggleFavorite(_ document: DocumentDTO) {
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
        documents[index].isFavorite.toggle()
        
        // Update metadata
        try? saveDocumentMetadata(documents[index])
    }
    
    func renameDocument(_ document: DocumentDTO, to newName: String) {
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
        documents[index].name = newName
        
        // Update metadata
        try? saveDocumentMetadata(documents[index])
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
        
        // Save metadata
        try saveDocumentMetadata(updatedDocument)
        
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
        
        if !fileManager.fileExists(atPath: metadataDirectory.path) {
            try? fileManager.createDirectory(
                at: metadataDirectory,
                withIntermediateDirectories: true
            )
        }
    }
    
    private func createDocumentFromFile(at url: URL) -> DocumentDTO? {
        guard let pdfDocument = PDFDocument(url: url) else { return nil }
        
        let documentId = url.deletingPathExtension().lastPathComponent
        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        let creationDate = attributes?[.creationDate] as? Date ?? Date()
        
        // Load metadata if exists, otherwise use filename
        let metadata = loadDocumentMetadata(for: documentId)
        
        return DocumentDTO(
            id: documentId,
            pdf: pdfDocument,
            name: metadata?.name ?? url.deletingPathExtension().lastPathComponent,
            type: .pdf,
            date: metadata?.dateCreated ?? creationDate,
            url: url,
            isFavorite: metadata?.isFavorite ?? false
        )
    }
    
    // MARK: - Metadata Management
    
    private func saveDocumentMetadata(_ document: DocumentDTO) throws {
        let metadata = DocumentMetadata(
            id: document.id,
            name: document.name,
            isFavorite: document.isFavorite,
            dateCreated: document.date
        )
        
        let metadataURL = metadataDirectory.appendingPathComponent("\(document.id).json")
        let data = try JSONEncoder().encode(metadata)
        try data.write(to: metadataURL)
    }
    
    private func loadDocumentMetadata(for documentId: String) -> DocumentMetadata? {
        let metadataURL = metadataDirectory.appendingPathComponent("\(documentId).json")
        
        guard let data = try? Data(contentsOf: metadataURL),
              let metadata = try? JSONDecoder().decode(DocumentMetadata.self, from: data) else {
            return nil
        }
        
        return metadata
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
