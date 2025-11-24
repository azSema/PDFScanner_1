import PDFKit

extension UIImage {
    
    func convertImageToPDF() -> PDFDocument {
        var image = self
        if let resizeImage = resizeImageFromScreen() {
            image = resizeImage
        }
        
        guard let page = PDFPage(image: image) else { return PDFDocument() }

        let document = PDFDocument()
        let aspectRatio = self.size.height / self.size.width
        let width: CGFloat = UIScreen.main.bounds.width - 40
        let newHeight = width * aspectRatio
        let rect = CGRect(x: 0, y: 0, width: width, height: newHeight)
        
        page.setBounds(rect, for: .mediaBox)
        document.insert(page, at: .zero)
        return document
    }
    
    func convertImageToPDFPage() -> PDFPage? {
        let aspectRatio = self.size.height / self.size.width
        let pdfWidth: CGFloat = 595.28
        let pdfHeight = pdfWidth * aspectRatio
        let pdfSize = CGSize(width: pdfWidth, height: pdfHeight)

        UIGraphicsBeginImageContextWithOptions(pdfSize, false, 1.0)
        
        self.draw(in: CGRect(origin: .zero, size: pdfSize))
        
        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            UIGraphicsEndImageContext()
            return nil
        }
        UIGraphicsEndImageContext()
        
        guard let page = PDFPage(image: resizedImage) else { return nil }
        
        page.setBounds(CGRect(origin: .zero, size: pdfSize), for: .mediaBox)
        return page
    }
    
    func convertCroppedImageToPDFPage() -> PDFPage {
        let aspectRatio = self.size.height / self.size.width
        let width: CGFloat = 595.28
        let newHeight = width * aspectRatio
        
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, CGRect(x: 0, y: 0, width: width, height: newHeight), nil)
        UIGraphicsBeginPDFPage()
        self.draw(in: CGRect(x: 0, y: 0, width: width, height: newHeight))
        UIGraphicsEndPDFContext()
        
        guard
            let pdfDocument = PDFDocument(data: pdfData as Data),
            let page = pdfDocument.page(at: 0)
        else { return PDFPage() }
        
        return page
    }
    
    func calculateScale() -> CGFloat {
        let imageSize = self.size
        let maxDimension: CGFloat = 100.0
        
        if imageSize.width < maxDimension && imageSize.height < maxDimension {
            return 1.0
        }
        
        let widthScale = maxDimension / imageSize.width
        let heightScale = maxDimension / imageSize.height
        
        return min(widthScale, heightScale)
    }
    
    func rotated(by degrees: CGFloat) -> UIImage? {
        let radians = degrees * .pi / 180

        var newSize = CGRect(origin: .zero, size: self.size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .integral.size

        newSize.width = max(newSize.width, size.width)
        newSize.height = max(newSize.height, size.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        context.translateBy(x: newSize.width / 2, y: newSize.height / 2)

        context.rotate(by: radians)

        self.draw(in: CGRect(x: -self.size.width / 2, y: -self.size.height / 2,
                             width: self.size.width, height: self.size.height))

        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return rotatedImage
    }
    
    private func resizeImageFromScreen() -> UIImage? {
        let newWidth = UIScreen.main.bounds.width - 40
        let scale = newWidth / self.size.width
        let newHeight = self.size.height * scale
        
        UIGraphicsBeginImageContext(CGSize(width: newWidth, height: newHeight))
        self.draw(in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
}

extension UIImage {
    class func imageWithLabel(label: UILabel) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(label.bounds.size, false, 0.0)
        label.layer.render(in: UIGraphicsGetCurrentContext()!)
        let img = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return img
    }
}
