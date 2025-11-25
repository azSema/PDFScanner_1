import SwiftUI
import Combine

final class Router: ObservableObject {
    @AppStorage("isOnboarding") var isOnboarding = true
    
    @Published var path: [Destination] = []
    
    func finishOnboarding() {
        withAnimation { isOnboarding = false }
    }
    
    func push(_ route: Destination) {
        path.append(route)
    }
    
    func pop() {
        _ = path.popLast()
    }
    
    func popToRoot() {
        path.removeAll()
    }
}

enum DocumentDestination: Hashable {
    case history
    case merge
    case editor
    case converter
    
    var title: String {
        switch self {
        case .history: "Recent Documents"
        case .merge: "Documents to Merge"
        case .editor: "Document to Edit"
        case .converter: "Document to Convert"
        }
    }
    
    var allowsMultipleSelection: Bool {
        switch self {
        case .merge: true
        case .history, .editor, .converter: false
        }
    }
}
