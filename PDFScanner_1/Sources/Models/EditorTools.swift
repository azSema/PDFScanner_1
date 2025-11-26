import UIKit

enum EditorTool: CaseIterable {
    case highlight
    case addImage
    case signature
    case rotate
    
    var title: String {
        switch self {
        case .highlight: "Highlight"
        case .addImage: "Add Image"
        case .signature: "Signature"
        case .rotate: "Rotate"
        }
    }
    
    var systemImage: String {
        switch self {
        case .highlight: "highlighter"
        case .addImage: "photo.badge.plus"
        case .signature: "signature"
        case .rotate: "rotate.right"
        }
    }
}

// MARK: - Highlight Colors

enum HighlightColor: CaseIterable {
    case yellow
    case green
    case blue
    case red
    case orange
    case purple
    case clear
    
    var color: UIColor {
        switch self {
        case .yellow: .systemYellow
        case .green: .systemGreen
        case .blue: .systemBlue
        case .red: .systemRed
        case .orange: .systemOrange
        case .purple: .systemPurple
        case .clear: .clear
        }
    }
    
    var isClearMode: Bool {
        return self == .clear
    }
}
