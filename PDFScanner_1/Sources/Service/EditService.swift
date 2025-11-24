import Foundation
import Combine
import PDFKit
import UIKit

@MainActor
final class EditService: ObservableObject {
    
    @Published var selectedTool: EditorTool? = nil
    @Published var isToolbarVisible = true
    @Published var pdfDocument: PDFDocument?
    @Published var currentPageIndex = 0
    
    // Highlight settings
    @Published var selectedHighlightColor: HighlightColor = .yellow
    @Published var highlightOpacity: Float = 0.3
    @Published var showingHighlightPanel = false
    
    // Image insertion
    @Published var showingImagePicker = false
    @Published var showingImageInsertMode = false
    @Published var insertionPoint: CGPoint = .zero
    
    // Signature
    @Published var showingSignatureCreator = false
    @Published var showingSignatureInsertMode = false
    @Published var currentSignature: UIImage?
    
    // Document state
    @Published var hasUnsavedChanges = false
    @Published var isProcessing = false
    
    private var documentId: UUID?
    private var pdfStorage: PDFStorage?
    
    // MARK: - Configuration
    
    func configure(documentId: UUID, pdfStorage: PDFStorage) {
        self.documentId = documentId
        self.pdfStorage = pdfStorage
        loadDocument()
    }
    
    // MARK: - Document Loading
    
    private func loadDocument() {
        guard let documentId = documentId,
              let pdfStorage = pdfStorage else { return }
        
        if let document = pdfStorage.documents.first(where: { $0.id == documentId.uuidString }) {
            self.pdfDocument = document.pdf
            self.currentPageIndex = 0
        }
    }
    
    // MARK: - Tool Selection
    
    func selectTool(_ tool: EditorTool) {
        // Deselect if same tool
        if selectedTool == tool {
            selectedTool = nil
            resetToolStates()
            return
        }
        
        selectedTool = tool
        resetToolStates()
        
        // Configure tool-specific states
        switch tool {
        case .highlight:
            showingHighlightPanel = true
        case .addImage:
            showingImageInsertMode = true
        case .signature:
            if currentSignature == nil {
                showingSignatureCreator = true
            } else {
                showingSignatureInsertMode = true
            }
        case .rotate:
            // Rotate action happens immediately
            rotateCurrentPage()
        }
    }
    
    private func resetToolStates() {
        showingHighlightPanel = false
        showingImageInsertMode = false
        showingSignatureInsertMode = false
    }
    
    // MARK: - Highlight Tools
    
    func applyHighlight(at point: CGPoint, in bounds: CGRect) {
        guard selectedTool == .highlight,
              let document = pdfDocument,
              let page = document.page(at: currentPageIndex) else { return }
        
        // TODO: Implement highlight annotation
        // This is where we'd add highlight annotation to PDF
        print("Applying highlight at: \(point) with color: \(selectedHighlightColor.title)")
        
        hasUnsavedChanges = true
    }
    
    func updateHighlightColor(_ color: HighlightColor) {
        selectedHighlightColor = color
    }
    
    func updateHighlightOpacity(_ opacity: Float) {
        highlightOpacity = opacity
    }
    
    // MARK: - Image Tools
    
    func insertImage(_ image: UIImage, at point: CGPoint) {
        guard selectedTool == .addImage,
              let document = pdfDocument,
              let page = document.page(at: currentPageIndex) else { return }
        
        // TODO: Implement image insertion
        print("Inserting image at: \(point)")
        
        hasUnsavedChanges = true
        showingImageInsertMode = false
        selectedTool = nil
    }
    
    func cancelImageInsertion() {
        showingImageInsertMode = false
        selectedTool = nil
    }
    
    // MARK: - Signature Tools
    
    func saveSignature(_ signature: UIImage) {
        currentSignature = signature
        showingSignatureCreator = false
        showingSignatureInsertMode = true
    }
    
    func insertSignature(at point: CGPoint) {
        guard selectedTool == .signature,
              let signature = currentSignature,
              let document = pdfDocument,
              let page = document.page(at: currentPageIndex) else { return }
        
        // TODO: Implement signature insertion
        print("Inserting signature at: \(point)")
        
        hasUnsavedChanges = true
        showingSignatureInsertMode = false
        selectedTool = nil
    }
    
    func cancelSignatureInsertion() {
        showingSignatureInsertMode = false
        selectedTool = nil
    }
    
    func clearSignature() {
        currentSignature = nil
        showingSignatureInsertMode = false
        selectedTool = nil
    }
    
    // MARK: - Rotation Tools
    
    private func rotateCurrentPage() {
        guard let document = pdfDocument,
              let page = document.page(at: currentPageIndex) else { return }
        
        // Rotate page 90 degrees clockwise
        let currentRotation = page.rotation
        page.rotation = (currentRotation + 90) % 360
        
        hasUnsavedChanges = true
        selectedTool = nil
        
        // Force refresh
        objectWillChange.send()
    }
    
    // MARK: - Navigation
    
    func goToNextPage() {
        guard let document = pdfDocument,
              currentPageIndex < document.pageCount - 1 else { return }
        
        currentPageIndex += 1
    }
    
    func goToPreviousPage() {
        guard currentPageIndex > 0 else { return }
        currentPageIndex -= 1
    }
    
    func goToPage(_ index: Int) {
        guard let document = pdfDocument,
              index >= 0 && index < document.pageCount else { return }
        
        currentPageIndex = index
    }
    
    // MARK: - Save Changes
    
    func saveChanges() async throws {
        guard hasUnsavedChanges,
              let document = pdfDocument,
              let documentId = documentId,
              let pdfStorage = pdfStorage else { return }
        
        isProcessing = true
        
        defer {
            isProcessing = false
        }
        
        // TODO: Save the modified PDF document
        // This would involve saving the document with annotations back to storage
        
        hasUnsavedChanges = false
    }
    
    func discardChanges() {
        // Reload original document
        loadDocument()
        hasUnsavedChanges = false
        selectedTool = nil
        resetToolStates()
    }
}