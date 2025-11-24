import SwiftUI

struct ConverterView: View {
    
    @EnvironmentObject private var router: Router
    
    var body: some View {
        VStack {
            Text("Converter View")
                .font(.bold(24))
                .foregroundStyle(.appText)
            
            Text("Convert documents to different formats")
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
    ConverterView()
        .environmentObject(Router())
}