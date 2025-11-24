import SwiftUI

struct AppEmptyView: View {
    
    let title: String
    let subtitle: String
    let imageName: String
    
    init(title: String, subtitle: String, imageName: String) {
        self.title = title
        self.subtitle = subtitle
        self.imageName = imageName
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Image placeholder
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .foregroundStyle(.appTextSecondary.opacity(0.6))
            
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
        .padding(.vertical, 48)
    }
}

#Preview {
    VStack {
        AppEmptyView(
            title: "No Documents Yet",
            subtitle: "Start scanning documents to see them here. Tap the scan button above to get started.",
            imageName: "doc.text"
        )
        .padding()
        
        Spacer()
    }
    .background(.appBackground)
}