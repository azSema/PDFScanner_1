import SwiftUI

struct DocumentCell: View {
    let document: DocumentDTO
    let isSelected: Bool
    let allowsSelection: Bool
    let onTap: () -> Void
    let onSelectionToggle: (() -> Void)?
    let actionsManager: DocumentActionsManager?
    
    init(
        document: DocumentDTO,
        isSelected: Bool = false,
        allowsSelection: Bool = false,
        onTap: @escaping () -> Void,
        onSelectionToggle: (() -> Void)? = nil,
        actionsManager: DocumentActionsManager? = nil
    ) {
        self.document = document
        self.isSelected = isSelected
        self.allowsSelection = allowsSelection
        self.onTap = onTap
        self.onSelectionToggle = onSelectionToggle
        self.actionsManager = actionsManager
    }
    
    var body: some View {
        Button(action: {
            if allowsSelection {
                onSelectionToggle?()
            } else {
                onTap()
            }
        }) {
            HStack(spacing: 16) {
                // Thumbnail
                Image(uiImage: document.thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.appSurface)
                    )
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    Text(document.name.isEmpty ? "Untitled Document" : document.name)
                        .font(.semibold(16))
                        .foregroundColor(.appText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 8) {
                        Text(document.type.rawValue.uppercased())
                            .font(.medium(12))
                            .foregroundColor(.appSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.appSurface)
                            .clipShape(Capsule())
                        
                        Text(formattedDate)
                            .font(.medium(12))
                            .foregroundColor(.appSecondary)
                        
                        Spacer()
                    }
                    
                    if document.isFavorite {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                            
                            Text("Favorite")
                                .font(.medium(12))
                                .foregroundColor(.appSecondary)
                            
                            Spacer()
                        }
                    }
                }
                
                Spacer()
                
                // Selection indicator or arrow
                if allowsSelection {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .appPrimary : .appSecondary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                }
            }
            .padding(16)
            .background(Color.appBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? Color.appPrimary : Color.appBorder,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            if let actionsManager = actionsManager {
                DocumentActionsView(actionsManager: actionsManager)
                    .contextMenu(for: document)
            }
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        let today = Date()
        
        if calendar.isDate(document.date, inSameDayAs: today) {
            formatter.dateFormat = "HH:mm"
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                  calendar.isDate(document.date, inSameDayAs: yesterday) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "MMM d"
        }
        return formatter.string(from: document.date)
    }
}

#Preview {
    VStack(spacing: 16) {
        DocumentCell(
            document: DocumentDTO(
                name: "Important Contract",
                type: .pdf,
                date: Date()
            ),
            onTap: { }
        )
        
        DocumentCell(
            document: DocumentDTO(
                name: "Meeting Notes",
                type: .doc,
                date: Date().addingTimeInterval(-86400),
                isFavorite: true
            ),
            isSelected: true,
            allowsSelection: true,
            onTap: { },
            onSelectionToggle: { }
        )
    }
    .padding()
    .background(Color.appSurface)
}