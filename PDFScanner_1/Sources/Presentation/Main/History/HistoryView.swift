import SwiftUI
import PDFKit

struct HistoryView: View {
    
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var pdfStorage: PDFStorage
    
    @State private var searchText: String = ""
    @State private var showOnlyFavorites: Bool = false
    
    var filteredDocuments: [DocumentDTO] {
        var documents = pdfStorage.documents
        
        // Filter by favorites if enabled
        if showOnlyFavorites {
            documents = documents.filter { $0.isFavorite }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            documents = documents.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        return documents.sorted { $0.date > $1.date }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if pdfStorage.isLoading {
                loadingView
            } else if filteredDocuments.isEmpty {
                emptyView
            } else {
                documentsList
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search documents...")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showOnlyFavorites.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: showOnlyFavorites ? "heart.fill" : "heart")
                            .foregroundColor(showOnlyFavorites ? .red : .appSecondary)
                        
                        if showOnlyFavorites {
                            Text("All")
                                .font(.regular(14))
                                .foregroundColor(.appText)
                        } else {
                            Text("Favorites")
                                .font(.regular(14)) 
                                .foregroundColor(.appSecondary)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Documents List
    
    private var documentsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredDocuments, id: \.id) { document in
                    HistoryDocumentCell(document: document) {
                        router.push(.main(.documentDetail(documentId: UUID(uuidString: document.id) ?? UUID())))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Loading & Empty Views
    
    private var loadingView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
                .tint(.appPrimary)
            
            Text("Loading documents...")
                .font(.medium(16))
                .foregroundColor(.appSecondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: getEmptyStateIcon())
                .font(.system(size: 64))
                .foregroundColor(.appSecondary)
            
            VStack(spacing: 8) {
                Text(getEmptyStateTitle())
                    .font(.bold(24))
                    .foregroundColor(.appText)
                
                Text(getEmptyStateSubtitle())
                    .font(.medium(16))
                    .foregroundColor(.appSecondary)
                    .multilineTextAlignment(.center)
            }
            
            if shouldShowStartScanningButton() {
                Button("Start Scanning") {
                    router.popToRoot()
                }
                .font(.medium(16))
                .foregroundColor(.white)
                .frame(height: 48)
                .frame(maxWidth: 200)
                .background(Color.appPrimary)
                .cornerRadius(12)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
    
    // MARK: - Empty State Helpers
    
    private func getEmptyStateIcon() -> String {
        if !searchText.isEmpty {
            return "magnifyingglass"
        } else if showOnlyFavorites {
            return "heart"
        } else {
            return "doc.text"
        }
    }
    
    private func getEmptyStateTitle() -> String {
        if !searchText.isEmpty {
            return "No Results"
        } else if showOnlyFavorites {
            return "No Favorites"
        } else {
            return "No Documents"
        }
    }
    
    private func getEmptyStateSubtitle() -> String {
        if !searchText.isEmpty {
            return "Try a different search term"
        } else if showOnlyFavorites {
            return "Tap the heart icon on documents to add them to favorites"
        } else {
            return "Start scanning documents to see them here"
        }
    }
    
    private func shouldShowStartScanningButton() -> Bool {
        return searchText.isEmpty && !showOnlyFavorites
    }
}

// MARK: - History Document Cell

struct HistoryDocumentCell: View {
    let document: DocumentDTO
    let onTap: () -> Void
    
    @EnvironmentObject private var pdfStorage: PDFStorage
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Document Thumbnail
                Image(uiImage: document.thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 75)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.appBorder, lineWidth: 1)
                    )
                
                // Document Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.name)
                        .font(.medium(16))
                        .foregroundColor(.appText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text("\(document.type.rawValue.uppercased()) • \(formattedDate)")
                        .font(.regular(14))
                        .foregroundColor(.appSecondary)
                    
                    if let pdf = document.pdf, pdf.pageCount > 0 {
                        Text("\(pdf.pageCount) \(pdf.pageCount == 1 ? "page" : "pages")")
                            .font(.regular(12))
                            .foregroundColor(.appSecondary)
                    }
                }
                
                Spacer()
                
                // Favorite & Actions
                VStack(spacing: 8) {
                    Button(action: {
                        pdfStorage.toggleFavorite(document)
                    }) {
                        Image(systemName: document.isFavorite ? "heart.fill" : "heart")
                            .foregroundColor(document.isFavorite ? .red : .appSecondary)
                            .font(.system(size: 18))
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.appSecondary)
                        .font(.system(size: 14))
                }
            }
            .padding(16)
            .background(Color.appSurface)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: document.date)
    }
}

#Preview {
    HistoryView()
        .environmentObject(Router())
        .environmentObject(PDFStorage())
}