import PDFKit
import SwiftUI

extension PDFDocument {
    
    static func emptyDocument() -> PDFDocument {
        let document = PDFDocument()
        document.insert(createWhitePage(), at: 0)
        return document
    }
    
    func addEmptyPage(insert at: Int) -> PDFDocument {
        let newPage = PDFDocument.createWhitePage()
        self.insert(newPage, at: at)
        return self
    }
    
    func emptyPage() -> PDFPage {
        return PDFDocument.createWhitePage()
    }
    
    func separateIntoPages() -> [DocumentDTO] {
        var separatedDocuments: [DocumentDTO] = []
        
        for pageIndex in 0..<self.pageCount {
            guard let pdfPage = self.page(at: pageIndex) else { continue }
            
            let singlePageDocument = PDFDocument()
            singlePageDocument.insert(pdfPage, at: 0)
            separatedDocuments.append(.init(pdf: singlePageDocument))
        }
        
        return separatedDocuments
    }
    
    func convertPDFDocumentToImages() async -> [UIImage] {
        let pageCount = self.pageCount
        guard pageCount > 0 else { return [] }
        
        var images: [UIImage] = []
        
        await withTaskGroup(of: UIImage?.self) { group in
            for pageIndex in 0..<pageCount {
                group.addTask {

                    autoreleasepool {
                        guard let page = self.page(at: pageIndex) else { return nil }
                        
                        let pageRect = page.bounds(for: .mediaBox)
                        
                        UIGraphicsBeginImageContext(pageRect.size)
                        guard let context = UIGraphicsGetCurrentContext() else {
                            UIGraphicsEndImageContext()
                            return nil
                        }
                        
                        context.saveGState()
                        context.translateBy(x: 0, y: pageRect.size.height)
                        context.scaleBy(x: 1.0, y: -1.0)
                        context.translateBy(x: -pageRect.origin.x, y: -pageRect.origin.y)
                        
                        page.draw(with: .mediaBox, to: context)
                        
                        context.restoreGState()

                        let image = UIGraphicsGetImageFromCurrentImageContext()
                        UIGraphicsEndImageContext()
                        
                        return image
                    }
                }
            }
            
            for await image in group {
                if let image = image {
                    images.append(image)
                }
            }
        }
        
        return images
    }
    
    static func createPDF(from documents: [DocumentDTO]) -> PDFDocument {
        let pdfDocument = PDFDocument()
        
        for (index, document) in documents.enumerated() {
            if let pdfPage = document.pdf?.page(at: 0) {
                pdfDocument.insert(pdfPage, at: index)
            }
        }
        
        return pdfDocument
    }
    
    func getPage(at index: Int) -> PDFPage? {
        return self.page(at: index)
    }
    
    func replacePage(at index: Int, with newPage: PDFPage) {
        guard index >= 0 && index < pageCount else { return }
        
        removePage(at: index)
        insert(newPage, at: index)
    }
    
    private static func createWhitePage() -> PDFPage {
        let rect = CGRect(x: .zero, y: .zero, width: 595.28, height: 841.89)

        UIGraphicsBeginImageContext(rect.size)
        guard let context = UIGraphicsGetCurrentContext() else { return PDFPage() }
        
        UIColor.white.setFill()
        context.fill(rect)

        guard let image = UIGraphicsGetImageFromCurrentImageContext() else { return PDFPage() }
        UIGraphicsEndImageContext()

        guard let imagePage = PDFPage(image: image) else { return PDFPage() }
        imagePage.setBounds(rect, for: .mediaBox)
        return imagePage
    }
}

extension PDFPage {
    func pageToDocument() -> PDFDocument {
        let document = PDFDocument()
        document.insert(self, at: 0)
        return document
    }
    
    func toImage() -> UIImage? {
        let pdfPageBounds = self.bounds(for: .mediaBox)
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: pdfPageBounds.size, format: format)
        
        return renderer.image { context in
            let ctx = context.cgContext
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fill(pdfPageBounds)
            
            ctx.saveGState()
            ctx.translateBy(x: 0, y: pdfPageBounds.size.height)
            ctx.scaleBy(x: 1.0, y: -1.0)
            ctx.translateBy(x: -pdfPageBounds.origin.x, y: -pdfPageBounds.origin.y)
            
            self.draw(with: .mediaBox, to: ctx)
            
            ctx.restoreGState()
        }
    }

    func rotateClockwise() -> PDFPage {
        let page = self
        let currentRotation = page.rotation
        page.rotation = (currentRotation + 90) % 360
        return page
    }
    
    func calculateTransformedLocation(
        location: CGPoint,
        geometrySize: CGSize,
        contentSize: CGSize
    ) -> CGRect {
        let adjustedLocation = CGPoint(
            x: location.x - contentSize.width / 2,
            y: location.y - contentSize.height / 2
        )
        
        let pageBounds = self.bounds(for: .mediaBox)
        var scaleX = pageBounds.width / geometrySize.width
        var scaleY = pageBounds.height / geometrySize.height
        var transformedX: CGFloat = 0
        var transformedY: CGFloat = 0
        
        switch self.rotation {
        case 90:
            scaleX = pageBounds.height / geometrySize.width
            scaleY = pageBounds.width / geometrySize.height
            transformedX = adjustedLocation.y * scaleY
            transformedY = adjustedLocation.x * scaleX
        case 180:
            transformedX = ((geometrySize.width - contentSize.width) - adjustedLocation.x) * scaleX
            transformedY = adjustedLocation.y * scaleY
        case 270:
            scaleX = pageBounds.height / geometrySize.width
            scaleY = pageBounds.width / geometrySize.height
            transformedX = ((geometrySize.height - contentSize.width) - adjustedLocation.y) * scaleY
            transformedY = ((geometrySize.width  - contentSize.width) - adjustedLocation.x) * scaleX
        default:
            transformedX = adjustedLocation.x * scaleX
            transformedY = (geometrySize.height - contentSize.height - adjustedLocation.y) * scaleY
        }
        
        return CGRect(x: transformedX,
                      y: transformedY,
                      width: contentSize.width * scaleX,
                      height: contentSize.height * scaleY)
    }
    
//    func applyingAnnotations(
//        from annotations: [TextAnnotation],
//        originalSize mediaSize: CGSize,
//        image: UIImage
//    ) -> PDFPage? {
//        guard let newPage = PDFPage(image: image) else { return nil }
//
//        let scaleX = bounds(for: .mediaBox).width / mediaSize.width
//        let scaleY = bounds(for: .mediaBox).height / mediaSize.height
//
//        newPage.setBounds(bounds(for: .mediaBox), for: .mediaBox)
//
//        for annotation in annotations {
//            let pageBounds = bounds(for: .mediaBox)
//            let invertedY = pageBounds.height - (annotation.frame.origin.y * scaleY) - (annotation.frame.height * scaleY)
//            let correctedFrame = CGRect(
//                x: annotation.frame.origin.x * scaleX,
//                y: invertedY,
//                width: annotation.frame.width * scaleX,
//                height: annotation.frame.height * scaleY
//            )
//
//            let pdfAnnotation = PDFAnnotation(bounds: correctedFrame, forType: .freeText, withProperties: nil)
//            pdfAnnotation.contents = annotation.attributed.string
//            pdfAnnotation.font = annotation.font.withSize(annotation.font.pointSize * scaleY)
//            pdfAnnotation.fontColor = annotation.textColor
//            pdfAnnotation.color = .clear
//            pdfAnnotation.interiorColor = annotation.textColor
//
//            newPage.addAnnotation(pdfAnnotation)
//        }
//
//        return newPage
//    }
    
}
