import PDFKit
import SwiftUI

extension PDFPage {
    
    /// Рендерит текущую страницу в изображение `UIImage`.
    func toImage() -> UIImage {
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
}
