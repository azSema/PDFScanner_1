import SwiftUI

struct HistoryView: View {
    
    @EnvironmentObject private var router: Router
    
    var body: some View {
        VStack {
            Text("History View")
                .font(.bold(24))
                .foregroundStyle(.appText)
            
            Text("All your scanned documents")
                .font(.regular(16))
                .foregroundStyle(.appTextSecondary)
            
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
    HistoryView()
        .environmentObject(Router())
}