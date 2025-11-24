import SwiftUI

struct RecentScansRow: View {
    
    let documents: [DocumentDTO]
    let onDocumentTap: (DocumentDTO) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(documents, id: \.id) { document in
                    DocumentCard(document: document) {
                        playHaptic(.light)
                        onDocumentTap(document)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 0))
    }
}

struct DocumentCard: View {
    
    let document: DocumentDTO
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.appSurface)
                        .frame(width: 100, height: 130)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.appBorder, lineWidth: 1)
                        )
                    
                    Image(uiImage: document.thumbnail)
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 80, height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.white)
                }
                
                VStack(spacing: 2) {
                    Text(document.name)
                        .font(.medium(12))
                        .foregroundStyle(.appText)
                        .lineLimit(1)
                    
                    Text(formatDate(document.date))
                        .font(.regular(10))
                        .foregroundStyle(.appTextSecondary)
                }
                .frame(width: 100)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct RecentScansLoadingView: View {
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.appSurface)
                            .frame(width: 100, height: 130)
                        
                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.appSurface)
                                .frame(width: 60, height: 12)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.appSurface)
                                .frame(width: 40, height: 10)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

struct RecentScansEmptyView: View {
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 40))
                .foregroundStyle(.appTextSecondary)
            
            Text("No recent scans")
                .font(.medium(16))
                .foregroundStyle(.appText)
            
            Text("Start scanning documents to see them here")
                .font(.regular(14))
                .foregroundStyle(.appTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack {
        RecentScansRow(documents: [
            DocumentDTO(name: "Document 1", type: .pdf, date: Date()),
            DocumentDTO(name: "Document 2", type: .pdf, date: Date())
        ]) { _ in }
        
        Divider().padding()
        
        RecentScansEmptyView()
    }
    .background(.appBackground)
}
