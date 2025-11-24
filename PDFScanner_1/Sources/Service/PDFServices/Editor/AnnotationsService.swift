import Foundation
import PDFKit
import UIKit
import Combine

@MainActor
final class AnnotationsService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var annotations: [IdentifiablePDFAnnotation] = []
    @Published var hasUnsavedAnnotations = false
    
    // Highlight settings
    @Published var highlightColor: HighlightColor = .yellow
    @Published var highlightOpacity: Float = 0.3
    
    // Current document context
    private var currentDocument: PDFDocument?
    private var currentPageIndex: Int = 0
    
    // MARK: - Configuration
    
    func configure(document: PDFDocument, pageIndex: Int) {
        self.currentDocument = document
        self.currentPageIndex = pageIndex
        loadAnnotationsForCurrentPage()
    }
    
    func updateCurrentPage(_ pageIndex: Int) {
        self.currentPageIndex = pageIndex
        loadAnnotationsForCurrentPage()
    }
    
    // MARK: - Highlight Annotations
    
    func addHighlightAnnotation(selectedText: String, bounds: CGRect) {
        guard let document = currentDocument,
              let page = document.page(at: currentPageIndex) else { return }
        
        // If in clear mode, remove existing highlights instead of adding
        if highlightColor.isClearMode {
            removeHighlightsInBounds(bounds, for: page, containing: selectedText)
            hasUnsavedAnnotations = true
            return
        }
        
        // Remove existing highlight if overlapping
        removeExistingHighlight(at: bounds, for: page, containing: selectedText)
        
        // Create new highlight annotation
        let highlight = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
        highlight.color = highlightColor.color.withAlphaComponent(CGFloat(highlightOpacity))
        highlight.contents = selectedText
        
        // Add to page
        page.addAnnotation(highlight)
        
        // Create identifiable annotation
        let identifiableAnnotation = IdentifiablePDFAnnotation(
            annotation: highlight,
            position: bounds.origin,
            midPosition: CGPoint(x: bounds.midX, y: bounds.midY),
            boundingBox: bounds,
            scale: 1.0
        )
        
        // Update local state
        annotations.append(identifiableAnnotation)
        hasUnsavedAnnotations = true
    }
    
    func removeHighlightAnnotation(_ annotation: IdentifiablePDFAnnotation) {
        guard let document = currentDocument,
              let page = document.page(at: currentPageIndex) else { return }
        
        // Remove from PDF page
        page.removeAnnotation(annotation.annotation)
        
        // Remove from local state
        annotations.removeAll { $0.id == annotation.id }
        hasUnsavedAnnotations = true
    }
    
    private func removeExistingHighlight(at bounds: CGRect, for page: PDFPage, containing text: String) {
        let existingHighlights = page.annotations.filter {
            $0.bounds.intersects(bounds) &&
            ($0.contents?.contains(text) == true) &&
            $0.type == "Highlight"
        }
        
        existingHighlights.forEach { annotation in
            page.removeAnnotation(annotation)
            annotations.removeAll { $0.annotation == annotation }
        }
    }
    
    private func removeHighlightsInBounds(_ bounds: CGRect, for page: PDFPage, containing text: String) {
        // Find all highlights that intersect with the selection bounds
        let highlightsToRemove = page.annotations.filter {
            $0.bounds.intersects(bounds) &&
            $0.type == "Highlight" &&
            // Remove any highlight in the area, regardless of text match for better UX
            ($0.contents?.contains(text) == true || bounds.intersects($0.bounds))
        }
        
        highlightsToRemove.forEach { annotation in
            page.removeAnnotation(annotation)
            annotations.removeAll { $0.annotation == annotation }
        }
        
        // If no highlights found in bounds, try removing any highlight containing selected text
        if highlightsToRemove.isEmpty {
            let textBasedHighlights = page.annotations.filter {
                $0.type == "Highlight" &&
                $0.contents?.contains(text) == true
            }
            
            textBasedHighlights.forEach { annotation in
                page.removeAnnotation(annotation)
                annotations.removeAll { $0.annotation == annotation }
            }
        }
    }
    
    // MARK: - Note Annotations
    
    func addNoteAnnotation(at location: CGPoint, with text: String, in geometrySize: CGSize) {
        guard let document = currentDocument,
              let page = document.page(at: currentPageIndex) else { return }
        
        // Calculate bounds for note annotation
        let bounds = calculateTransformedLocation(
            location: location,
            geometrySize: geometrySize,
            contentSize: CGSize(width: 20, height: 20)
        )
        
        // Create note annotation with bubble icon
        if let image = UIImage(systemName: "bubble.fill") {
            let stampAnnotation = CustomImageAnnotation(bounds: bounds, image: image)
            stampAnnotation.color = .systemBlue
            stampAnnotation.contents = text
            stampAnnotation.isReadOnly = true
            page.addAnnotation(stampAnnotation)
            
            // Create identifiable annotation
            let identifiableAnnotation = IdentifiablePDFAnnotation(
                annotation: stampAnnotation,
                position: location,
                midPosition: CGPoint(x: bounds.midX, y: bounds.midY),
                boundingBox: bounds,
                scale: 1.0
            )
            
            annotations.append(identifiableAnnotation)
            hasUnsavedAnnotations = true
        }
    }
    
    func updateNoteAnnotation(oldText: String, newText: String) {
        guard let document = currentDocument,
              let page = document.page(at: currentPageIndex) else { return }
        
        if let annotation = page.annotations.first(where: { $0.contents == oldText }) {
            annotation.contents = newText
            
            // Update local state
            if let index = annotations.firstIndex(where: { $0.annotation == annotation }) {
                annotations[index].annotation.contents = newText
            }
            
            hasUnsavedAnnotations = true
        }
    }
    
    func removeNoteAnnotation(with text: String) {
        guard let document = currentDocument,
              let page = document.page(at: currentPageIndex) else { return }
        
        let annotationsToRemove = page.annotations.filter { $0.contents == text }
        
        annotationsToRemove.forEach { annotation in
            page.removeAnnotation(annotation)
            annotations.removeAll { $0.annotation == annotation }
        }
        
        hasUnsavedAnnotations = true
    }
    
    // MARK: - Text Format Annotations
    
    func addFormatAnnotations(selectedText: String, bounds: CGRect, fontStyles: Set<FontStyle>) {
        guard let document = currentDocument,
              let page = document.page(at: currentPageIndex) else { return }
        
        // Remove existing format annotations
        removeExistingFormatAnnotations(at: bounds, for: page)
        
        // Add underline if selected
        if fontStyles.contains(.underline) {
            let underline = PDFAnnotation(bounds: bounds, forType: .underline, withProperties: nil)
            underline.color = .black
            page.addAnnotation(underline)
            
            let identifiableAnnotation = IdentifiablePDFAnnotation(
                annotation: underline,
                position: bounds.origin,
                midPosition: CGPoint(x: bounds.midX, y: bounds.midY),
                boundingBox: bounds,
                scale: 1.0
            )
            annotations.append(identifiableAnnotation)
        }
        
        // Add strikethrough if selected
        if fontStyles.contains(.strikethrough) {
            let strikeOut = PDFAnnotation(bounds: bounds, forType: .strikeOut, withProperties: nil)
            strikeOut.color = .black
            page.addAnnotation(strikeOut)
            
            let identifiableAnnotation = IdentifiablePDFAnnotation(
                annotation: strikeOut,
                position: bounds.origin,
                midPosition: CGPoint(x: bounds.midX, y: bounds.midY),
                boundingBox: bounds,
                scale: 1.0
            )
            annotations.append(identifiableAnnotation)
        }
        
        hasUnsavedAnnotations = true
    }
    
    private func removeExistingFormatAnnotations(at bounds: CGRect, for page: PDFPage) {
        let formatAnnotations = page.annotations.filter {
            $0.bounds.intersects(bounds) &&
            ($0.type == "FreeText" || $0.type == "Underline" || $0.type == "StrikeOut")
        }
        
        formatAnnotations.forEach { annotation in
            page.removeAnnotation(annotation)
            annotations.removeAll { $0.annotation == annotation }
        }
    }
    
    // MARK: - Image Annotations
    
    func addImageAnnotation(image: UIImage, at position: CGPoint, in geometrySize: CGSize) {
        guard let document = currentDocument,
              let page = document.page(at: currentPageIndex) else { return }
        
        let bounds = calculateTransformedLocation(
            location: position,
            geometrySize: geometrySize,
            contentSize: image.size
        )
        
        let imageAnnotation = ImageAnnotation(bounds: bounds, image: image)
        page.addAnnotation(imageAnnotation)
        
        let identifiableAnnotation = IdentifiablePDFAnnotation(
            annotation: imageAnnotation,
            position: position,
            midPosition: CGPoint(x: bounds.midX, y: bounds.midY),
            boundingBox: bounds,
            scale: 1.0
        )
        
        annotations.append(identifiableAnnotation)
        hasUnsavedAnnotations = true
    }
    
    // MARK: - Highlight Settings
    
    func updateHighlightColor(_ color: HighlightColor) {
        highlightColor = color
    }
    
    func updateHighlightOpacity(_ opacity: Float) {
        highlightOpacity = opacity
    }
    
    // MARK: - Document Management
    
    func saveAnnotations() {
        // Annotations are already saved to PDF pages
        // This method can be used for additional persistence logic
        hasUnsavedAnnotations = false
    }
    
    func discardAnnotations() {
        // Remove all annotations from current page
        guard let document = currentDocument,
              let page = document.page(at: currentPageIndex) else { return }
        
        annotations.forEach { identifiableAnnotation in
            page.removeAnnotation(identifiableAnnotation.annotation)
        }
        
        annotations.removeAll()
        hasUnsavedAnnotations = false
    }
    
    private func loadAnnotationsForCurrentPage() {
        guard let document = currentDocument,
              let page = document.page(at: currentPageIndex) else {
            annotations.removeAll()
            return
        }
        
        // Convert PDFAnnotations to IdentifiablePDFAnnotations
        annotations = page.annotations.compactMap { annotation in
            IdentifiablePDFAnnotation(
                annotation: annotation,
                position: annotation.bounds.origin,
                midPosition: CGPoint(x: annotation.bounds.midX, y: annotation.bounds.midY),
                boundingBox: annotation.bounds,
                scale: 1.0
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func calculateTransformedLocation(location: CGPoint, geometrySize: CGSize, contentSize: CGSize) -> CGRect {
        guard let page = currentDocument?.page(at: currentPageIndex) else {
            return CGRect(origin: location, size: contentSize)
        }
        
        let pageRect = page.bounds(for: .mediaBox)
        
        // Convert from view coordinates to PDF coordinates
        let scaleX = pageRect.width / geometrySize.width
        let scaleY = pageRect.height / geometrySize.height
        
        let pdfX = location.x * scaleX
        let pdfY = pageRect.height - (location.y * scaleY) // Flip Y coordinate
        
        return CGRect(
            x: pdfX,
            y: pdfY - contentSize.height,
            width: contentSize.width,
            height: contentSize.height
        )
    }
}

// MARK: - Supporting Types

struct IdentifiablePDFAnnotation: Identifiable {
    let id = UUID()
    let annotation: PDFAnnotation
    var position: CGPoint
    var midPosition: CGPoint
    var boundingBox: CGRect
    var scale: CGFloat
}

// MARK: - Custom Annotation Classes

class CustomImageAnnotation: PDFAnnotation {
    private let _image: UIImage
    
    var image: UIImage {
        return _image
    }
    
    init(bounds: CGRect, image: UIImage) {
        self._image = image
        super.init(bounds: bounds, forType: .stamp, withProperties: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        guard let cgImage = _image.cgImage else { return }
        
        context.saveGState()
        context.translateBy(x: bounds.minX, y: bounds.minY)
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: 0, y: -bounds.height)
        context.draw(cgImage, in: CGRect(origin: .zero, size: bounds.size))
        context.restoreGState()
    }
}

class ImageAnnotation: PDFAnnotation {
    private let _image: UIImage
    
    var image: UIImage {
        return _image
    }
    
    init(bounds: CGRect, image: UIImage) {
        self._image = image
        super.init(bounds: bounds, forType: .stamp, withProperties: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        guard let cgImage = _image.cgImage else { return }
        
        context.saveGState()
        
        // Draw image exactly within the bounds
        // bounds.origin is the bottom-left corner in PDF coordinates
        // bounds.size is the width and height
        context.draw(cgImage, in: bounds)
        
        context.restoreGState()
        
        print("🎨 ImageAnnotation drawn at exact bounds: \(bounds)")
    }
}

// MARK: - FontStyle Enum

enum FontStyle {
    case underline
    case strikethrough
    case bold
    case italic
}