import Foundation

enum DocumentAction: String, CaseIterable {
    case preview = "preview"
    case edit = "edit"
    case rename = "rename"
    case share = "share"
    case toggleFavorite = "toggleFavorite"
    case delete = "delete"
    
    var title: String {
        switch self {
        case .preview:
            return "Preview"
        case .edit:
            return "Edit"
        case .rename:
            return "Rename"
        case .share:
            return "Share"
        case .toggleFavorite:
            return "Toggle Favorite"
        case .delete:
            return "Delete"
        }
    }
    
    var systemImage: String {
        switch self {
        case .preview:
            return "eye"
        case .edit:
            return "square.and.pencil"
        case .rename:
            return "pencil"
        case .share:
            return "square.and.arrow.up"
        case .toggleFavorite:
            return "heart"
        case .delete:
            return "trash"
        }
    }
    
    var isDestructive: Bool {
        return self == .delete
    }
    
    func favoriteTitle(for document: DocumentDTO) -> String {
        return document.isFavorite ? "Remove from Favorites" : "Add to Favorites"
    }
    
    func favoriteIcon(for document: DocumentDTO) -> String {
        return document.isFavorite ? "heart.slash" : "heart"
    }
}