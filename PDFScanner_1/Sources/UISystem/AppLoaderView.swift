import ActivityIndicatorView
import SwiftUI

struct AppLoaderView: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            
            ActivityIndicatorView(
                isVisible: .constant(true),
                type: .flickeringDots(count: 7)
            )
            .frame(width: 60, height: 60)
            .foregroundStyle(.white)
        }
        .ignoresSafeArea()
    }
}
