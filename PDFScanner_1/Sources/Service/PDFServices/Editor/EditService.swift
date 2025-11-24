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
    @Published var signatureService = SignatureService()
    @Published var activeSignatureOverlay: IdentifiablePDFAnnotation? = nil
    
    // Document state
    @Published var hasUnsavedChanges = false
    @Published var isProcessing = false
    
    // Annotations service
    @Published var annotationsService = AnnotationsService()
    
    private var documentId: UUID?
    private var pdfStorage: PDFStorage?
    private var cancellables = Set<AnyCancellable>()
    
    // Store reference to PDFView for coordinate calculations
    weak var pdfViewRef: PDFView?
    
    // MARK: - Computed Properties
    
    var currentPage: PDFPage? {
        return pdfDocument?.page(at: currentPageIndex)
    }
    
    func setPDFViewReference(_ pdfView: PDFView) {
        self.pdfViewRef = pdfView
        print("📐 PDFView reference set with bounds: \(pdfView.bounds)")
    }
    
    func getActualPDFDisplaySize() -> (size: CGSize, offset: CGPoint)? {
        guard let pdfView = pdfViewRef,
              let page = pdfDocument?.page(at: currentPageIndex) else {
            return nil
        }
        
        // Get the actual bounds of the PDF page as displayed in the view
        let pageRect = page.bounds(for: .mediaBox)
        let displayRect = pdfView.convert(pageRect, from: page)
        
        print("📐 PDF page original bounds: \(pageRect)")
        print("📐 PDF page display bounds: \(displayRect)")
        
        return (size: displayRect.size, offset: CGPoint(x: displayRect.origin.x, y: displayRect.origin.y))
    }
    
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
                // No signature - open creator
                showingSignatureCreator = true
            } else {
                // Has signature - show options
                // For now, allow creating new signature by reopening creator
                showingSignatureCreator = true
                print("🔄 Reopening signature creator for new signature")
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
              pdfDocument != nil else { return }
        
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
        print("💾 Saving signature and creating overlay")
        currentSignature = signature
        showingSignatureCreator = false
        
        // Create immediate overlay instead of insert mode
        createSignatureOverlay(with: signature)
        
        // Reset signature service for next use
        signatureService.clearSignature()
    }
    
    func createSignatureOverlay(with signature: UIImage) {
        guard let document = pdfDocument,
              let page = document.page(at: currentPageIndex) else {
            print("❌ Failed to create signature overlay - no document/page")
            return
        }
        
        print("✨ Creating signature overlay")
        
        // Calculate center position in PDF coordinates
        let pageRect = page.bounds(for: .mediaBox)
        let centerX = pageRect.width / 2
        let centerY = pageRect.height / 2
        
        // Calculate signature bounds (компактный начальный размер для лучшего UX)
        let desiredMaxWidth: CGFloat = 100    // Еще меньше для мобильных экранов
        let desiredMaxHeight: CGFloat = 50    // Пропорционально уменьшено
        
        let imageSize = signature.size
        let scaleX = desiredMaxWidth / imageSize.width
        let scaleY = desiredMaxHeight / imageSize.height
        let scale = min(scaleX, scaleY, 0.6) // Уменьшил max scale до 0.6 для компактности
        
        let finalWidth = imageSize.width * scale
        let finalHeight = imageSize.height * scale
        
        print("📏 Signature sizing: image(\(imageSize)) → final(\(finalWidth)x\(finalHeight)) scale(\(scale))")
        
        // Create annotation bounds centered on page
        // Use same coordinate system as view (no Y-flip here)
        let bounds = CGRect(
            x: centerX - finalWidth / 2,
            y: centerY - finalHeight / 2,
            width: finalWidth,
            height: finalHeight
        )
        
        // Create image annotation but DON'T add to page yet
        let imageAnnotation = ImageAnnotation(bounds: bounds, image: signature)
        
        // Create identifiable annotation for overlay
        // midPosition set to normalized center - will be converted to view coordinates
        let identifiableAnnotation = IdentifiablePDFAnnotation(
            annotation: imageAnnotation,
            position: CGPoint(x: centerX, y: centerY),
            midPosition: CGPoint(x: 0.5, y: 0.5), // Normalized center - will be converted to view coordinates
            boundingBox: bounds,
            scale: 0.3  // Компактный начальный размер - пользователь может увеличить при необходимости
        )
        
        // Set as active overlay (don't add to annotationsService yet)
        activeSignatureOverlay = identifiableAnnotation
        
        hasUnsavedChanges = true
        selectedTool = nil // Deselect tool after creating
        
        print("✅ Signature overlay created (no Y-flip in bounds)")
    }
    
    func createSignatureFromService() {
        if let signature = signatureService.generateSignatureImage() {
            saveSignature(signature)
        }
    }
    
    func insertSignature(at point: CGPoint, geometrySize: CGSize) {
        guard selectedTool == .signature,
              let signature = currentSignature else { return }
        
        print("📍 Inserting signature at: \(point)")
        annotationsService.addImageAnnotation(image: signature, at: point, in: geometrySize)
        
        hasUnsavedChanges = true
        showingSignatureInsertMode = false
        selectedTool = nil
    }
    
    func cancelSignatureInsertion() {
        showingSignatureInsertMode = false
        selectedTool = nil
        activeSignatureOverlay = nil
    }
    
    func clearSignature() {
        print("🗑️ Clearing signature")
        currentSignature = nil
        signatureService.clearSignature()
        showingSignatureInsertMode = false
        activeSignatureOverlay = nil
        selectedTool = nil
    }
    
    func resetSignatureService() {
        signatureService.clearSignature()
    }
    
    func finalizeSignatureOverlay() {
        guard let overlay = activeSignatureOverlay,
              let document = pdfDocument,
              let page = document.page(at: currentPageIndex) else {
            print("❌ Cannot finalize signature overlay - missing data")
            return
        }
        
        print("✅ Finalizing signature overlay")
        print("🔍 Before finalize - overlay bounds: \(overlay.annotation.bounds)")
        print("🔍 Before finalize - overlay midPosition: \(overlay.midPosition)")
        print("🔍 Before finalize - overlay scale: \(overlay.scale)")
        
        // Add annotation to PDF page
        page.addAnnotation(overlay.annotation)
        
        // Force PDF document update
        objectWillChange.send()
        
        // Add to annotations service for tracking
        annotationsService.annotations.append(overlay)
        
        // Clear active overlay AFTER a short delay to allow PDF to render
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.activeSignatureOverlay = nil
            self?.selectedTool = nil
            print("🔄 Overlay cleared after PDF render")
        }
        
        print("📄 Signature finalized at PDF bounds: \(overlay.annotation.bounds)")
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