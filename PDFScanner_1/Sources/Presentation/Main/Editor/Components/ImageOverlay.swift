import SwiftUI
import PDFKit

struct ImageOverlay: View {
    @ObservedObject var editService: EditService
    @Binding var annotation: IdentifiablePDFAnnotation
    
    @State private var isDragging = false
    @State private var isScaling = false
    @State private var showMenu = false
    @State private var didSetupInitialScale = false
    @State private var baseScale: CGFloat = 1.0
    @State private var cornerDragState: CornerDragState? = nil  // <— новое
    
    enum CornerDragState {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    let geometry: GeometryProxy
    
    var body: some View {
        let image = getAnnotationImage()
        let width = (image?.size.width ?? 100) * annotation.scale
        let height = (image?.size.height ?? 100) * annotation.scale
        
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
            }
            
            // Border - ВСЕГДА видимый
            Rectangle()
                .stroke(Color.blue.opacity(0.7), lineWidth: 2)
                .frame(width: width, height: height)
                .position(clampedPosition)
            
            // Corner handles - ВСЕГДА видимые
            cornerHandles(
                width: width,
                height: height,
                position: clampedPosition
            )
        }
        .onAppear {
            guard !didSetupInitialScale, let image else { return }
            didSetupInitialScale = true
            
            let targetRelativeWidth: CGFloat = 0.15
            let targetWidth = geometry.size.width * targetRelativeWidth
            let ratio = targetWidth / image.size.width
            
            let initialScale = min(max(ratio, 0.05), 0.5)
            baseScale = initialScale
            annotation.scale = initialScale
        }
        .gesture(
            // Drag для перемещения (только если не тапаем по углу)
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    // Проверяем, не тапаем ли мы по углу
                    if isPointNearCorner(value.startLocation, width: width, height: height, position: clampedPosition) {
                        return  // Игнорируем drag, если начали с угла
                    }
                    
                    let clampedX = min(max(value.location.x, width/2), geometry.size.width - width/2)
                    let clampedY = min(max(value.location.y, height/2), geometry.size.height - height/2)
                    
                    annotation.midPosition = CGPoint(x: clampedX, y: clampedY)
                    annotation.position = CGPoint(x: clampedX, y: clampedY)
                    isDragging = true
                }
                .onEnded { _ in
                    isDragging = false
                    saveImagePosition()
                }
        )
    }
    
    // MARK: - Corner Handles
    
    @ViewBuilder
    private func cornerHandles(width: CGFloat, height: CGFloat, position: CGPoint) -> some View {
        let cornerSize: CGFloat = 20
        let halfWidth = width / 2
        let halfHeight = height / 2
        
        Group {
            // Top-left corner
            cornerHandle(
                position: CGPoint(
                    x: position.x - halfWidth,
                    y: position.y - halfHeight
                ),
                corner: .topLeft,
                width: width,
                height: height,
                centerPosition: position
            )
            
            // Top-right corner
            cornerHandle(
                position: CGPoint(
                    x: position.x + halfWidth,
                    y: position.y - halfHeight
                ),
                corner: .topRight,
                width: width,
                height: height,
                centerPosition: position
            )
            
            // Bottom-left corner
            cornerHandle(
                position: CGPoint(
                    x: position.x - halfWidth,
                    y: position.y + halfHeight
                ),
                corner: .bottomLeft,
                width: width,
                height: height,
                centerPosition: position
            )
            
            // Bottom-right corner
            cornerHandle(
                position: CGPoint(
                    x: position.x + halfWidth,
                    y: position.y + halfHeight
                ),
                corner: .bottomRight,
                width: width,
                height: height,
                centerPosition: position
            )
        }
    }
    
    @ViewBuilder
    private func cornerHandle(
        position: CGPoint,
        corner: CornerDragState,
        width: CGFloat,
        height: CGFloat,
        centerPosition: CGPoint
    ) -> some View {
        Circle()
            .fill(Color.blue)
            .frame(width: 20, height: 20)
            .position(position)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        cornerDragState = corner
                        isScaling = true
                        
                        // Вычисляем новую ширину и высоту на основе движения угла
                        let deltaX = value.translation.width
                        let deltaY = value.translation.height
                        
                        // Для каждого угла своя логика изменения размера
                        let newWidth: CGFloat
                        let newHeight: CGFloat
                        
                        switch corner {
                        case .topLeft:
                            newWidth = max(50, width - deltaX)
                            newHeight = max(50, height - deltaY)
                        case .topRight:
                            newWidth = max(50, width + deltaX)
                            newHeight = max(50, height - deltaY)
                        case .bottomLeft:
                            newWidth = max(50, width - deltaX)
                            newHeight = max(50, height + deltaY)
                        case .bottomRight:
                            newWidth = max(50, width + deltaX)
                            newHeight = max(50, height + deltaY)
                        }
                        
                        // Вычисляем новый scale на основе изменения размера
                        guard let image = getAnnotationImage() else { return }
                        let scaleX = newWidth / image.size.width
                        let scaleY = newHeight / image.size.height
                        let newScale = min(max(min(scaleX, scaleY), 0.05), 3.0)  // ограничиваем диапазон
                        
                        annotation.scale = newScale
                    }
                    .onEnded { _ in
                        baseScale = annotation.scale
                        cornerDragState = nil
                        isScaling = false
                        saveImagePosition()
                    }
            )
    }
    
    private func isPointNearCorner(_ point: CGPoint, width: CGFloat, height: CGFloat, position: CGPoint) -> Bool {
        let cornerSize: CGFloat = 30  // зона захвата угла
        let halfWidth = width / 2
        let halfHeight = height / 2
        
        let corners = [
            CGPoint(x: position.x - halfWidth, y: position.y - halfHeight),  // top-left
            CGPoint(x: position.x + halfWidth, y: position.y - halfHeight),  // top-right
            CGPoint(x: position.x - halfWidth, y: position.y + halfHeight),  // bottom-left
            CGPoint(x: position.x + halfWidth, y: position.y + halfHeight)   // bottom-right
        ]
        
        return corners.contains { corner in
            abs(point.x - corner.x) < cornerSize && abs(point.y - corner.y) < cornerSize
        }
    }
    
    private func convertedViewPosition(for size: CGSize) -> CGPoint {
        if annotation.midPosition.x <= 1.0 && annotation.midPosition.y <= 1.0 {
            let viewX = annotation.midPosition.x * geometry.size.width
            let viewY = annotation.midPosition.y * geometry.size.height
            return CGPoint(x: viewX, y: viewY)
        }
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
