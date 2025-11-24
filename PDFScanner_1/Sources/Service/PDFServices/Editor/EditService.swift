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
    
    // Image overlay state
    @Published var currentImage: UIImage?
    @Published var activeImageOverlay: IdentifiablePDFAnnotation? = nil
    
    // Add page functionality
    @Published var showingAddPageActionSheet = false
    @Published var showingFileImporter = false
    
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
            // Show image picker for user to select image
            showingImagePicker = true
            print("🖼️ Showing image picker")
            
            // DEBUG: Uncomment line below to test with sample image instead of photo picker
            // testCreateImageOverlay()
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
        
        // Clear active overlays
        activeSignatureOverlay = nil
        activeImageOverlay = nil
        currentSignature = nil
        currentImage = nil
        
        // Clear add page states
        showingAddPageActionSheet = false
        showingFileImporter = false
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
    
    /// Creates an interactive overlay for image positioning before final placement in PDF
    /// Uses the same coordinate system and overlay approach as signatures for consistent UX
    func createImageOverlay(with image: UIImage) {
        guard let document = pdfDocument,
              let page = document.page(at: currentPageIndex) else {
            print("❌ Failed to create image overlay - no document/page")
            return
        }
        
        print("✨ Creating image overlay")
        
        // Calculate center position in PDF coordinates
        let pageRect = page.bounds(for: .mediaBox)
        let centerX = pageRect.width / 2
        let centerY = pageRect.height / 2
        
        // Calculate image bounds (компактный начальный размер для лучшего UX)
        let desiredMaxWidth: CGFloat = 120   
        let desiredMaxHeight: CGFloat = 120   
        
        let imageSize = image.size
        let scaleX = desiredMaxWidth / imageSize.width
        let scaleY = desiredMaxHeight / imageSize.height
        let scale = min(scaleX, scaleY, 0.6) // Компактный начальный размер
        
        let finalWidth = imageSize.width * scale
        let finalHeight = imageSize.height * scale
        
        print("📏 Image sizing: image(\(imageSize)) → final(\(finalWidth)x\(finalHeight)) scale(\(scale))")
        
        // Create annotation bounds centered on page
        let bounds = CGRect(
            x: centerX - finalWidth / 2,
            y: centerY - finalHeight / 2,
            width: finalWidth,
            height: finalHeight
        )
        
        // Create image annotation but DON'T add to page yet
        let imageAnnotation = ImageAnnotation(bounds: bounds, image: image)
        
        // Create identifiable annotation for overlay
        let identifiableAnnotation = IdentifiablePDFAnnotation(
            annotation: imageAnnotation,
            position: CGPoint(x: centerX, y: centerY),
            midPosition: CGPoint(x: 0.5, y: 0.5), // Normalized center - will be converted to view coordinates
            boundingBox: bounds,
            scale: 0.3  // Компактный начальный размер - пользователь может увеличить при необходимости
        )
        
        // Set as active overlay (don't add to annotationsService yet)
        activeImageOverlay = identifiableAnnotation
        currentImage = image
        
        hasUnsavedChanges = true
        
        print("📸 Image overlay created and ready for positioning")
    }
    
    func finalizeImageOverlay() {
        guard let overlay = activeImageOverlay,
              let page = currentPage else {
            print("❌ Cannot finalize image overlay - no overlay or page")
            return
        }
        
        print("✅ Finalizing image overlay")
        print("🔍 Before finalize - overlay bounds: \(overlay.annotation.bounds)")
        print("🔍 Before finalize - overlay midPosition: \(overlay.midPosition)")
        print("🔍 Before finalize - overlay scale: \(overlay.scale)")
        
        // Add the annotation to the PDF page
        page.addAnnotation(overlay.annotation)
        objectWillChange.send()  // Force UI update
        
        print("📄 Image finalized at PDF bounds: \(overlay.annotation.bounds)")
        
        // Clear the overlay after a short delay to allow PDF rendering
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.activeImageOverlay = nil
            self?.currentImage = nil
            print("🔄 Image overlay cleared after PDF render")
        }
        
        hasUnsavedChanges = true
    }
    
    func cancelImageOverlay() {
        activeImageOverlay = nil
        currentImage = nil
        print("❌ Image overlay cancelled")
    }
    
    func insertImage(_ image: UIImage, at point: CGPoint) {
        // Instead of direct insertion, create overlay for positioning
        print("🖼️ Creating image overlay instead of direct insertion")
        createImageOverlay(with: image)
        showingImageInsertMode = false
    }
    
    func insertImageAtStoredPoint(_ image: UIImage) {
        // Instead of direct insertion, create overlay for positioning
        print("🖼️ Creating image overlay from stored point")
        createImageOverlay(with: image)
        insertionPoint = .zero
    }
    
    // Test method to create image overlay with a sample image
    func testCreateImageOverlay() {
        // Create a simple test image with better visual appearance
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 200))
        let testImage = renderer.image { ctx in
            // Background gradient
            let colors = [UIColor.systemBlue.cgColor, UIColor.systemPurple.cgColor]
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: nil)!
            
            ctx.cgContext.drawLinearGradient(gradient, 
                                           start: CGPoint(x: 0, y: 0), 
                                           end: CGPoint(x: 300, y: 200), 
                                           options: [])
            
            // Add frame
            ctx.cgContext.setStrokeColor(UIColor.white.cgColor)
            ctx.cgContext.setLineWidth(4)
            ctx.cgContext.stroke(CGRect(x: 2, y: 2, width: 296, height: 196))
            
            // Add text
            let text = "Sample Image"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            
            let textSize = text.size(withAttributes: attributes)
            let textX = (300 - textSize.width) / 2
            let textY = (200 - textSize.height) / 2
            
            text.draw(at: CGPoint(x: textX, y: textY), withAttributes: attributes)
        }
        
        createImageOverlay(with: testImage)
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
    
    // MARK: - Add Page Functionality
    
    func showAddPageOptions() {
        showingFileImporter = true // Directly show file importer since it's the only option
        print("📄 Opening file importer for adding PDF pages")
    }
    
    func addPageFromFiles() {
        showingFileImporter = true
        print("📁 Opening file importer for new page")
    }
    
    func addPageToDocument(from image: UIImage) {
        guard let document = pdfDocument else {
            print("❌ No document available for adding page")
            return
        }
        
        print("📄 Adding new page to document")
        
        // Create a new PDF page from the image  
        let newPage = PDFPage(image: image)
        
        guard let newPage = newPage else {
            print("❌ Failed to create PDF page from image")
            return
        }
        
        // Add the new page to the document
        document.insert(newPage, at: document.pageCount)
        
        // Navigate to the new page
        currentPageIndex = document.pageCount - 1
        annotationsService.updateCurrentPage(currentPageIndex)
        
        // Mark as having unsaved changes
        hasUnsavedChanges = true
        
        print("✅ Added new page successfully. Total pages: \(document.pageCount)")
        print("📍 Navigated to page \(currentPageIndex + 1)")
    }
    
    func addPageToDocument(from data: Data) {
        // Try to determine if it's a PDF or image
        if data.starts(with: [0x25, 0x50, 0x44, 0x46]) { // PDF magic bytes "%PDF"
            // It's a PDF file
            addPagesFromPDF(data: data)
        } else {
            // Try to create image
            guard let image = UIImage(data: data) else {
                print("❌ Failed to create image from data")
                return
            }
            addPageToDocument(from: image)
        }
    }
    
    private func addPagesFromPDF(data: Data) {
        guard let sourcePDF = PDFDocument(data: data) else {
            print("❌ Failed to create PDF document from data")
            return
        }
        
        guard let currentDocument = pdfDocument else {
            print("❌ No current document available for adding pages")
            return
        }
        
        let pageCount = sourcePDF.pageCount
        print("📄 Adding \(pageCount) pages from PDF to current document")
        
        // Add all pages from source PDF to current document
        for pageIndex in 0..<pageCount {
            guard let page = sourcePDF.page(at: pageIndex) else {
                print("❌ Failed to get page \(pageIndex) from source PDF")
                continue
            }
            
            // Insert page at the end of current document
            currentDocument.insert(page, at: currentDocument.pageCount)
            print("✅ Added page \(pageIndex + 1)/\(pageCount)")
        }
        
        // Navigate to the first newly added page
        currentPageIndex = currentDocument.pageCount - pageCount
        annotationsService.updateCurrentPage(currentPageIndex)
        
        // Mark as having unsaved changes and update storage
        hasUnsavedChanges = true
        
        // Update the document in storage
        Task {
            await updateDocumentInStorage()
        }
        
        print("✅ Added \(pageCount) pages successfully. Total pages: \(currentDocument.pageCount)")
        print("📍 Navigated to page \(currentPageIndex + 1)")
    }
    
    private func updateDocumentInStorage() async {
        guard let documentId = documentId,
              let pdfStorage = pdfStorage,
              let currentDocument = pdfDocument else {
            print("❌ Missing required components for storage update")
            return
        }
        
        // Find the document in storage
        guard let documentIndex = pdfStorage.documents.firstIndex(where: { $0.id == documentId.uuidString }) else {
            print("❌ Document not found in storage")
            return
        }
        
        // Update the PDF document
        var updatedDocument = pdfStorage.documents[documentIndex]
        updatedDocument.pdf = currentDocument
        updatedDocument.date = Date()  // Update date instead of modifiedDate
        
        do {
            // Save the updated document
            try await pdfStorage.saveDocument(updatedDocument)
            print("✅ Document updated in storage successfully")
        } catch {
            print("❌ Failed to update document in storage: \(error)")
        }
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