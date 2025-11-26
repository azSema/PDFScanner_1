import SwiftUI

struct ProBanner: View {
    
    @EnvironmentObject var premium: PremiumManager
    
    var body: some View {
        Button {
            withAnimation {
                premium.isShowingPaywall.toggle()
            }
        } label: {
            Image(.pro)
                .resizable()
                .scaledToFit()
                .padding(-10)
                .padding(.bottom, -10)
        }
    }
}

#Preview {
    ProBanner()
}
