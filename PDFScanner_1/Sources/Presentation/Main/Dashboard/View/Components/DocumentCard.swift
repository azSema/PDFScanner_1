import SwiftUI

struct DocumentCard: View {
    let document: DocumentDTO
    let onTap: () -> Void
    let actionsManager: DocumentActionsManager
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.appSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.appBorder, lineWidth: 1)
                    )
                
                HStack {
                    Image(uiImage: document.thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding()
                    
                    VStack(spacing: 2) {
                        Text(document.name)
                            .font(.medium(12))
                            .foregroundStyle(.appText)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text(formatDate(document.date))
                            .font(.regular(10))
                            .foregroundStyle(.appTextSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            DocumentActionsView(actionsManager: actionsManager)
                .contextMenu(for: document)
        }
    }
}

// MARK: - Helper

private extension DocumentCard {
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}
