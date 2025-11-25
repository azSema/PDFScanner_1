import SwiftUI

/// Основной flow приложения (главный NavigationStack)
struct MainFlow: View {
    @EnvironmentObject private var router: Router
    
    var body: some View {
        NavigationStack(path: $router.path) {
            DashboardView()
                .navigationDestination(for: Destination.self) { destination in
                    destination.makeView()
                }
        }
    }
}
