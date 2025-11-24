import SwiftUI

struct MergeView: View {
    
    @EnvironmentObject private var router: Router
    
    var body: some View {
        VStack {
            Text("Merge View")
                .font(.bold(24))
                .foregroundStyle(.appText)
            
            Text("Combine multiple documents into one")
                .font(.regular(16))
                .foregroundStyle(.appTextSecondary)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            Button("Back to Dashboard") {
                router.popToRoot()
            }
            .font(.medium(16))
            .foregroundStyle(.appPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.appBackground)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    MergeView()
        .environmentObject(Router())
}