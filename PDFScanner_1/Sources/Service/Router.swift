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

enum Destination: Hashable {
    case main(MainRoute)
}

extension Destination: AppDesination {
    @ViewBuilder
    func makeView() -> some View {
        switch self {
        case .main(let route):
            route.makeView()
        }
    }
}

protocol AppDesination: Hashable {
    associatedtype Screen: View
    @ViewBuilder func makeView() -> Screen
}

enum MainRoute: AppDesination {
    case dashboard
    case scanner(mode: ScanMode)
    case converter
    case editor(documentId: UUID)
    case merge
    case history
    case documentDetail(documentId: UUID)

    @ViewBuilder
    func makeView() -> some View {
        switch self {
        case .dashboard:
            DashboardView()
        case .scanner(let mode):
            ScannerView(mode: mode)
        case .converter:
            ConverterView()
        case .editor(let documentId):
            EditorView(documentId: documentId)
        case .merge:
            MergeView()
        case .history:
            HistoryView()
        case .documentDetail(let documentId):
            DocumentDetailView(documentId: documentId)
        }
    }
}

enum ScanMode: Hashable {
    case single
    case multi
    case batch
}

