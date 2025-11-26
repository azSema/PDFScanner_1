import SwiftUI

enum Destination: Hashable {
    case main(MainRoute)
}

extension Destination: AppDestination {
    @ViewBuilder
    func makeView() -> some View {
        switch self {
        case .main(let route):
            route.makeView()
        }
    }
}
