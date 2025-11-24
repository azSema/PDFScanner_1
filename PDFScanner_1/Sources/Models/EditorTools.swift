import Foundation
import UIKit

enum EditorTool: String, CaseIterable {
    case highlight = "highlight"
    case addImage = "addImage"
    case signature = "signature"
    case rotate = "rotate"
    
    var title: String {
        switch self {
        case .highlight:
            return "Highlight"
        case .addImage:
            return "Add Image"
        case .signature:
            return "Signature"
        case .rotate:
            return "Rotate"
        }
    }
    
    var systemImage: String {
        switch self {
        case .highlight:
            return "highlighter"
        case .addImage:
            return "photo.badge.plus"
        case .signature:
            return "signature"
        case .rotate:
            return "rotate.right"
        }
    }
    
    var description: String {
        switch self {
        case .highlight:
            return "Highlight text and content"
        case .addImage:
            return "Insert images into document"
        case .signature:
            return "Create and add digital signature"
        case .rotate:
            return "Rotate pages"
        }
    }
}

// MARK: - Highlight Colors

enum HighlightColor: String, CaseIterable {
    case yellow = "yellow"
    case green = "green"
    case blue = "blue"
    case red = "red"
    case orange = "orange"
    case purple = "purple"
    case clear = "clear"
    
    var color: UIColor {
        switch self {
        case .yellow:
            return .systemYellow
        case .green:
            return .systemGreen
        case .blue:
            return .systemBlue
        case .red:
            return .systemRed
        case .orange:
            return .systemOrange
        case .purple:
            return .systemPurple
        case .clear:
            return .clear
        }
    }
    
    var title: String {
        switch self {
        case .yellow:
            return "Yellow"
        case .green:
            return "Green"
        case .blue:
            return "Blue"
        case .red:
            return "Red"
        case .orange:
            return "Orange"
        case .purple:
            return "Purple"
        case .clear:
            return "Clear"
        }
    }
    
    var isClearMode: Bool {
        return self == .clear
    }
}