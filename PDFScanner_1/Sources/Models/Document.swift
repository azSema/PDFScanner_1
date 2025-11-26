import Foundation
import PDFKit

struct DocumentDTO: Identifiable, Hashable {
    var id: String = UUID().uuidString
    var pdf: PDFDocument?
    var name: String
    var type: DocumentType
    var date: Date
    var url: URL?
    var isFavorite: Bool
    
    init(
        id: String = UUID().uuidString,
        pdf: PDFDocument? = nil,
        name: String = "",
        type: DocumentType = .pdf,
        size: String = "",
        date: Date = .now,
        url: URL? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.pdf = pdf
        self.name = name
        self.type = type
        self.date = date
        self.url = url
        self.isFavorite = isFavorite
    }
    
    var thumbnail: UIImage {
        switch type {
        case .pdf:
            guard let pdf = pdf else {
                print("⚠️ PDF is nil for document: \(name)")
                return UIImage(systemName: "document.fill") ?? UIImage()
            }
            
            guard pdf.pageCount > 0 else {
                print("⚠️ PDF has no pages for document: \(name)")
                return UIImage(systemName: "document.fill") ?? UIImage()
            }
            
            guard let page = pdf.page(at: 0) else {
                print("⚠️ Could not get first page for document: \(name)")
                return UIImage(systemName: "document.fill") ?? UIImage()
            }
            
            let image = page.toImage()
            print("✅ Created thumbnail for document: \(name)")
            return image
            
        case .doc:
            return UIImage(systemName: "document.fill") ?? UIImage()
        }
    }
}
