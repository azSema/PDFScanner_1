import SwiftUI

struct DocumentDetailView: View {
    
    let documentId: UUID
    @EnvironmentObject private var router: Router
    
    var body: some View {
        VStack {
            Text("Document Detail")
                .font(.bold(24))
                .foregroundStyle(.appText)
            
            Text("Document ID: \(documentId.uuidString.prefix(8))...")
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
    DocumentDetailView(documentId: UUID())
        .environmentObject(Router())
}