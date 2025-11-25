import Foundation

enum DocumentAction: CaseIterable {
    case preview
    case edit
    case convert
    case rename
    case share
    case toggleFavorite
    case delete
    
    var title: String {
        switch self {
        case .preview: "Preview"
        case .edit: "Edit"
        case .convert: "Convert to Images"
        case .rename: "Rename"
        case .share: "Share"
        case .toggleFavorite: "Toggle Favorite"
        case .delete: "Delete"
        }
    }
    
    var systemImage: String {
        switch self {
        case .preview: "eye"
        case .edit: "square.and.pencil"
        case .convert: "arrow.triangle.2.circlepath"
        case .rename: "pencil"
        case .share: "square.and.arrow.up"
        case .toggleFavorite: "heart"
        case .delete: "trash"
        }
    }
    
    var isDestructive: Bool {
        self == .delete
    }
    
    func favoriteTitle(for document: DocumentDTO) -> String {
        document.isFavorite ? "Remove from Favorites" : "Add to Favorites"
    }
    
    func favoriteIcon(for document: DocumentDTO) -> String {
        document.isFavorite ? "heart.slash" : "heart"
    }
}
