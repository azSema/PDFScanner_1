import SwiftUI
import PDFKit

struct ImageOverlay: View {
    @ObservedObject var editService: EditService
    @Binding var annotation: IdentifiablePDFAnnotation
    @State private var isDragging = false
    @State private var isScaling = false
    @State private var showMenu = false
    
    let geometry: GeometryProxy
    
    var body: some View {
        // Get image from annotation
        let image = getAnnotationImage()
        let width = (image?.size.width ?? 100) * annotation.scale
        let height = (image?.size.height ?? 100) * annotation.scale
        
        // Convert PDF coordinates to view coordinates on first appearance
        let viewPosition = convertedViewPosition(for: CGSize(width: width, height: height))
        let clampedPosition = self.clampedPosition(for: CGSize(width: width, height: height), viewPosition: viewPosition)
        
        ZStack {
            // Image
            if let image = getAnnotationImage() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: width, height: height)
                    .position(clampedPosition)
                    .onLongPressGesture {
                        showMenu = true
                    }
                    .contextMenu {
                        if showMenu {
                            Button("Copy") {
                                UIPasteboard.general.image = image
                            }
                            Button("Delete", role: .destructive) {
                                editService.cancelImageOverlay()
                            }
                        }
                    }
                    .overlay(
                        // Border overlay when dragging or scaling
                        Rectangle()
                            .stroke(Color.blue.opacity(0.7), lineWidth: 2)
                            .opacity(isDragging || isScaling ? 1 : 0)
                    )
            }
            
            // Interactive border and corners when dragging or scaling
            if isDragging || isScaling {
                let rectangleWidth = width
                let rectangleHeight = height
                let inset: CGFloat = 1
                
                Rectangle()
                    .stroke(Color.blue, lineWidth: 2)
                    .frame(width: rectangleWidth - inset, height: rectangleHeight - inset)
                    .position(clampedPosition)
                
                // Corner handles for visual feedback
                Group {
                    // Top-left corner
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 12, height: 12)
                        .position(x: clampedPosition.x - rectangleWidth/2 + 6, 
                                y: clampedPosition.y - rectangleHeight/2 + 6)
                    
                    // Top-right corner  
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 12, height: 12)
                        .position(x: clampedPosition.x + rectangleWidth/2 - 6, 
                                y: clampedPosition.y - rectangleHeight/2 + 6)
                    
                    // Bottom-left corner
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 12, height: 12)
                        .position(x: clampedPosition.x - rectangleWidth/2 + 6, 
                                y: clampedPosition.y + rectangleHeight/2 - 6)
                    
                    // Bottom-right corner
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 12, height: 12)
                        .position(x: clampedPosition.x + rectangleWidth/2 - 6, 
                                y: clampedPosition.y + rectangleHeight/2 - 6)
                }
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    print("🔄 Image drag changed: \(value.location)")
                    let clampedX = min(max(value.location.x, width/2), geometry.size.width - width/2)
                    let clampedY = min(max(value.location.y, height/2), geometry.size.height - height/2)
                    
                    // Update the annotation directly
                    annotation.midPosition = CGPoint(x: clampedX, y: clampedY)
                    annotation.position = CGPoint(x: clampedX, y: clampedY)
                    isDragging = true
                }
                .onEnded { _ in
                    print("🏁 Image drag ended at: \(annotation.midPosition)")
                    isDragging = false
                    saveImagePosition()
                }
        )
        .gesture(
            MagnificationGesture()
                .onChanged { scale in
                    print("🔍 Image scale changed: \(scale)")
                    // Гибкий диапазон масштабирования как у подписей
                    let minScale: CGFloat = 0.1  
                    let maxScale: CGFloat = 5.0  
                    let clampedScale = min(max(scale, minScale), maxScale)
                    annotation.scale = clampedScale
                    isScaling = true
                }
                .onEnded { _ in
                    print("📏 Image scale ended: \(annotation.scale)")
                    isScaling = false
                    saveImagePosition()
                }
        )
    }
    
    private func convertedViewPosition(for size: CGSize) -> CGPoint {
        // If midPosition is normalized (0-1), convert to view coordinates
        if annotation.midPosition.x <= 1.0 && annotation.midPosition.y <= 1.0 {
            let viewX = annotation.midPosition.x * geometry.size.width
            let viewY = annotation.midPosition.y * geometry.size.height
            
            print("🔄 Converting normalized coordinates to view: \(viewX), \(viewY)")
            
            // Update annotation with actual view coordinates but only once
            let viewPosition = CGPoint(x: viewX, y: viewY)
            annotation.midPosition = viewPosition
            
            return viewPosition
        }
        
        // Already in view coordinates
        return annotation.midPosition
    }
    
    private func getAnnotationImage() -> UIImage? {
        if let imageAnnotation = annotation.annotation as? ImageAnnotation {
            return imageAnnotation.image
        } else if let customImageAnnotation = annotation.annotation as? CustomImageAnnotation {
            return customImageAnnotation.image
        }
        return nil
    }
    
    private func clampedPosition(for size: CGSize, viewPosition: CGPoint) -> CGPoint {
        let clampedX = min(max(viewPosition.x, size.width / 2), geometry.size.width - size.width / 2)
        let clampedY = min(max(viewPosition.y, size.height / 2), geometry.size.height - size.height / 2)
        
        return CGPoint(x: clampedX, y: clampedY)
    }
    
    private func saveImagePosition() {
        // Convert view coordinates back to PDF coordinates and save
        guard let document = editService.pdfDocument,
              let page = document.page(at: editService.currentPageIndex) else { return }
        
        let pageRect = page.bounds(for: .mediaBox)
        
        // Try to get actual PDF display size and offset, fallback to geometry
        let displaySize: CGSize
        let displayOffset: CGPoint
        
        if let actualPDFData = editService.getActualPDFDisplaySize() {
            displaySize = actualPDFData.size
            displayOffset = actualPDFData.offset
            print("🎯 Using actual PDF display size: \(displaySize), offset: \(displayOffset)")
        } else {
            displaySize = geometry.size
            displayOffset = .zero
            print("⚠️ Using geometry size as fallback: \(displaySize), no offset")
        }
        
        // Log geometry info for debugging
        print("🔍 Geometry size: \(geometry.size)")
        print("🔍 Display size used: \(displaySize)")
        print("🔍 Display offset: \(displayOffset)")
        print("🔍 PDF page bounds: \(pageRect)")
        
        // Calculate scale factors using actual display size
        let scaleX = pageRect.width / displaySize.width
        let scaleY = pageRect.height / displaySize.height
        
        print("🔍 Scale factors: X=\(scaleX), Y=\(scaleY)")
        
        // Get actual current image size (with scaling applied)
        let image = getAnnotationImage()
        let originalWidth = image?.size.width ?? 100
        let originalHeight = image?.size.height ?? 100
        
        // Current sizes in view coordinates
        let currentWidthView = originalWidth * annotation.scale
        let currentHeightView = originalHeight * annotation.scale
        
        // Convert to PDF coordinates
        let currentWidthPDF = currentWidthView * scaleX
        let currentHeightPDF = currentHeightView * scaleY
        
        print("🔍 Image size: Original(\(originalWidth)x\(originalHeight)) → View(\(currentWidthView)x\(currentHeightView)) → PDF(\(currentWidthPDF)x\(currentHeightPDF))")
        
        // Convert view coordinates to PDF coordinates
        // IMPORTANT: Account for PDF display offset!
        // SwiftUI: (0,0) = top-left, Y increases down
        // PDF: (0,0) = bottom-left, Y increases up
        
        // Adjust view position by removing PDF offset before scaling
        let adjustedViewX = annotation.midPosition.x - displayOffset.x
        let adjustedViewY = annotation.midPosition.y - displayOffset.y
        
        let pdfCenterX = adjustedViewX * scaleX
        let pdfCenterY = pageRect.height - (adjustedViewY * scaleY) // Flip Y axis for PDF
        
        print("🔍 Position adjustment: ViewPos(\(annotation.midPosition)) → Adjusted(\(adjustedViewX), \(adjustedViewY)) → PDFCenter(\(pdfCenterX), \(pdfCenterY))")
        
        // Create bounds with center positioning
        let newBounds = CGRect(
            x: pdfCenterX - currentWidthPDF / 2,
            y: pdfCenterY - currentHeightPDF / 2,
            width: currentWidthPDF,
            height: currentHeightPDF
        )
        
        // Update annotation bounds
        annotation.annotation.bounds = newBounds
        annotation.boundingBox = newBounds
        
        // Update position fields to match new bounds  
        annotation.position = CGPoint(x: pdfCenterX, y: pdfCenterY)
        
        editService.hasUnsavedChanges = true
        
        print("💾 Final image bounds set: \(newBounds)")
        print("🎯 Expected center in PDF: (\(pdfCenterX), \(pdfCenterY))")
    }
}