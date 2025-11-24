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
    
    init(pdf: PDFDocument? = nil,
         name: String = "",
         type: DocumentType = .pdf,
         size: String = "",
         date: Date = .now,
         url: URL? = nil,
         isFavorite: Bool = false) {
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
            pdf?.page(at: 0)?.toImage() ?? UIImage(systemName: "document")!
        case .doc:
            UIImage(systemName: "document")!
        }
    }
    
}

enum DocumentType: String {
    case pdf
    case doc
}
