import SwiftUI
import PDFKit

struct DocumentDetailView: View {
    
    let documentId: UUID
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var pdfStorage: PDFStorage
    
    @State private var showingDeleteAlert = false
    @State private var showingRenameAlert = false
    @State private var newName = ""
    
    private var document: DocumentDTO? {
        pdfStorage.documents.first { $0.id == documentId.uuidString }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if let document = document, let pdfDocument = document.pdf {
                // PDF Viewer
                PDFViewWrapper(pdfDocument: pdfDocument)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Bottom Info Panel
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(document.name)
                                .font(.medium(18))
                                .foregroundColor(.appText)
                                .lineLimit(2)
                            
                            Text("\(pdfDocument.pageCount) pages • \(formattedDate)")
                                .font(.regular(14))
                                .foregroundColor(.appSecondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            pdfStorage.toggleFavorite(document)
                        }) {
                            Image(systemName: document.isFavorite ? "heart.fill" : "heart")
                                .foregroundColor(document.isFavorite ? .red : .appSecondary)
                                .font(.system(size: 20))
                        }
                    }
                    
                    // Action Buttons
                    HStack(spacing: 12) {
                        actionButton(
                            title: "Rename",
                            icon: "pencil",
                            action: {
                                newName = document.name
                                showingRenameAlert = true
                            }
                        )
                        
                        actionButton(
                            title: "Share",
                            icon: "square.and.arrow.up",
                            action: {
                                shareDocument(document)
                            }
                        )
                        
                        actionButton(
                            title: "Delete",
                            icon: "trash",
                            action: {
                                showingDeleteAlert = true
                            }
                        )
                        .foregroundColor(.red)
                    }
                }
                .padding(16)
                .background(Color.appSurface)
            } else {
                // Document Not Found
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 64))
                        .foregroundColor(.appSecondary)
                    
                    Text("Document Not Found")
                        .font(.bold(24))
                        .foregroundColor(.appText)
                    
                    Text("This document may have been deleted")
                        .font(.medium(16))
                        .foregroundColor(.appSecondary)
                    
                    Button("Back to History") {
                        router.pop()
                    }
                    .font(.medium(16))
                    .foregroundColor(.appPrimary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Document")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Document", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let document = document {
                    pdfStorage.removeDocument(document)
                    router.pop()
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Rename Document", isPresented: $showingRenameAlert) {
            TextField("Document Name", text: $newName)
            Button("Cancel") { }
            Button("Save") {
                if let document = document, !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    pdfStorage.renameDocument(document, to: newName.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        } message: {
            Text("Enter a new name for this document")
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func actionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                
                Text(title)
                    .font(.regular(12))
            }
            .foregroundColor(.appText)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.appBackground)
            .cornerRadius(8)
        }
    }
    
    // MARK: - Actions
    
    private func shareDocument(_ document: DocumentDTO) {
        guard let url = document.url else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    private var formattedDate: String {
        guard let document = document else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: document.date)
    }
}

#Preview {
    DocumentDetailView(documentId: UUID())
        .environmentObject(Router())
        .environmentObject(PDFStorage())
}