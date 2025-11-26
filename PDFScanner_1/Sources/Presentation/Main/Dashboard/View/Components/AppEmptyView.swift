import SwiftUI

struct AppEmptyView: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.semiBold(20))
                    .foregroundStyle(.appText)
                    .multilineTextAlignment(.center)
                
                Text(subtitle)
                    .font(.regular(16))
                    .foregroundStyle(.appTextSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 32)
    }
}
