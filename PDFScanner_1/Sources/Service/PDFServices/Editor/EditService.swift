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
    @Published var insertionGeometry: CGSize = .zero
    
    // Signature
    @Published var showingSignatureCreator = false
    @Published var showingSignatureInsertMode = false
    @Published var currentSignature: UIImage?
    
    // Document state
    @Published var hasUnsavedChanges = false
    @Published var isProcessing = false
    
    // Annotations service
    @Published var annotationsService = AnnotationsService()
    
    private var documentId: UUID?
    private var pdfStorage: PDFStorage?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    
    func configure(documentId: UUID, pdfStorage: PDFStorage) {
        self.documentId = documentId
        self.pdfStorage = pdfStorage
        loadDocument()
        setupAnnotationsBinding()
    }
    
    private func setupAnnotationsBinding() {
        // Listen for annotations changes
        annotationsService.$hasUnsavedAnnotations
            .sink { [weak self] hasUnsaved in
                if hasUnsaved {
                    self?.hasUnsavedChanges = true
                }
            }
            .store(in: &cancellables)
        
        // Sync highlight settings
        $selectedHighlightColor
            .sink { [weak self] color in
                self?.annotationsService.updateHighlightColor(color)
            }
            .store(in: &cancellables)
        
        $highlightOpacity
            .sink { [weak self] opacity in
                self?.annotationsService.updateHighlightOpacity(opacity)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Document Loading
    
    private func loadDocument() {
        guard let documentId = documentId,
              let pdfStorage = pdfStorage else { return }
        
        if let document = pdfStorage.documents.first(where: { $0.id == documentId.uuidString }) {
            self.pdfDocument = document.pdf
            self.currentPageIndex = 0
            
            // Configure annotations service
            if let pdfDoc = document.pdf {
                annotationsService.configure(document: pdfDoc, pageIndex: currentPageIndex)
            }
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
    
    // MARK: - Highlight Tools (via AnnotationsService)
    
    func handleTextSelection(selectedText: String, bounds: CGRect, geometrySize: CGSize) {
        guard selectedTool == .highlight else { return }
        
        annotationsService.addHighlightAnnotation(selectedText: selectedText, bounds: bounds)
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
              let document = pdfDocument else { return }
        
        let geometrySize = insertionGeometry != .zero ? insertionGeometry : CGSize(width: 400, height: 600)
        annotationsService.addImageAnnotation(image: image, at: point, in: geometrySize)
        
        hasUnsavedChanges = true
        showingImageInsertMode = false
        selectedTool = nil
        insertionPoint = .zero
    }
    
    func insertImageAtStoredPoint(_ image: UIImage) {
        guard insertionPoint != .zero else { return }
        insertImage(image, at: insertionPoint)
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
    
    func insertSignature(at point: CGPoint, geometrySize: CGSize) {
        guard selectedTool == .signature,
              let signature = currentSignature else { return }
        
        annotationsService.addImageAnnotation(image: signature, at: point, in: geometrySize)
        
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
        annotationsService.updateCurrentPage(currentPageIndex)
    }
    
    func goToPreviousPage() {
        guard currentPageIndex > 0 else { return }
        
        currentPageIndex -= 1
        annotationsService.updateCurrentPage(currentPageIndex)
    }
    
    func goToPage(_ index: Int) {
        guard let document = pdfDocument,
              index >= 0 && index < document.pageCount else { return }
        
        currentPageIndex = index
        annotationsService.updateCurrentPage(currentPageIndex)
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
        
        // Save annotations
        annotationsService.saveAnnotations()
        
        // Find and update document in storage
        if let docIndex = pdfStorage.documents.firstIndex(where: { $0.id == documentId.uuidString }) {
            var updatedDoc = pdfStorage.documents[docIndex]
            updatedDoc.pdf = document
            pdfStorage.documents[docIndex] = updatedDoc
            
            // Write to file if URL exists
            if let url = updatedDoc.url {
                document.write(to: url)
            }
        }
        
        hasUnsavedChanges = false
    }
    
    func discardChanges() {
        // Reload original document
        loadDocument()
        annotationsService.discardAnnotations()
        hasUnsavedChanges = false
        selectedTool = nil
        resetToolStates()
    }
}