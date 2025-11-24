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
    case home(HomeRoute)
    case history(HistoryRoute)
}

extension Destination: AppDesination {
    @ViewBuilder
    func makeView() -> some View {
        switch self {
        case .home(let r):
            r.makeView()
        case .history(let r):
            r.makeView()
        }
    }
}

protocol AppDesination: Hashable {
    associatedtype Screen: View
    @ViewBuilder func makeView() -> Screen
}

enum HomeRoute: AppDesination {
    case start
    case result(id: UUID)

    @ViewBuilder
    func makeView() -> some View {
        switch self {
        case .start: Text("Start")
        case .result(let id):Text("Result")
        }
    }
}

enum HistoryRoute: AppDesination {
    case editor(id: UUID)

    @ViewBuilder
    func makeView() -> some View {
        Text("Edit")
    }
}

