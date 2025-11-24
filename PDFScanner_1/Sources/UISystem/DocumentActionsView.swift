import SwiftUI

struct DocumentActionsView: View {
    @ObservedObject var actionsManager: DocumentActionsManager
    
    var body: some View {
        EmptyView()
            .sheet(isPresented: $actionsManager.showingPreview) {
                if let url = actionsManager.previewURL {
                    NavigationView {
                        QuickLookPreview(url: url)
                            .navigationTitle("Preview")
                            .navigationBarTitleDisplayMode(.inline)
                            .navigationBarItems(
                                trailing: Button("Done") {
                                    actionsManager.showingPreview = false
                                }
                            )
                    }
                }
            }
            .sheet(isPresented: $actionsManager.showingShareSheet) {
                if !actionsManager.shareItems.isEmpty {
                    ActivityViewController(activityItems: actionsManager.shareItems)
                }
            }
            .alert("Rename Document", isPresented: $actionsManager.showingRenameAlert) {
                TextField("Document name", text: $actionsManager.newDocumentName)
                Button("Cancel", role: .cancel) {
                    actionsManager.cancelAction()
                }
                Button("Rename") {
                    actionsManager.confirmRename()
                }
            } message: {
                Text("Enter a new name for the document")
            }
            .alert("Delete Document", isPresented: $actionsManager.showingDeleteAlert) {
                Button("Cancel", role: .cancel) {
                    actionsManager.cancelAction()
                }
                Button("Delete", role: .destructive) {
                    actionsManager.confirmDelete()
                }
            } message: {
                if let document = actionsManager.selectedDocument {
                    Text("Are you sure you want to delete '\(document.name)'? This action cannot be undone.")
                }
            }
            .confirmationDialog(
                actionsManager.selectedDocument?.name ?? "Document Actions",
                isPresented: $actionsManager.showingActionSheet,
                titleVisibility: .visible
            ) {
                if let document = actionsManager.selectedDocument {
                    actionSheetButtons(for: document)
                }
            }
    }
    
    // MARK: - Context Menu
    @ViewBuilder
    func contextMenu(for document: DocumentDTO) -> some View {
        Button(action: { actionsManager.handleAction(.preview, for: document) }) {
            Label("Preview", systemImage: "eye")
        }
        
        Button(action: { actionsManager.handleAction(.edit, for: document) }) {
            Label("Edit", systemImage: "square.and.pencil")
        }
        
        Divider()
        
        Button(action: { actionsManager.handleAction(.rename, for: document) }) {
            Label("Rename", systemImage: "pencil")
        }
        
        Button(action: { actionsManager.handleAction(.share, for: document) }) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        
        Divider()
        
        Button(action: { actionsManager.handleAction(.toggleFavorite, for: document) }) {
            Label(
                document.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                systemImage: document.isFavorite ? "heart.slash" : "heart"
            )
        }
        
        Divider()
        
        Button(role: .destructive, action: { actionsManager.handleAction(.delete, for: document) }) {
            Label("Delete", systemImage: "trash")
        }
    }
    
    // MARK: - Action Sheet Buttons
    @ViewBuilder
    private func actionSheetButtons(for document: DocumentDTO) -> some View {
        Button("Preview") {
            actionsManager.handleAction(.preview, for: document)
        }
        
        Button("Edit") {
            actionsManager.handleAction(.edit, for: document)
        }
        
        Button("Rename") {
            actionsManager.handleAction(.rename, for: document)
        }
        
        Button("Share") {
            actionsManager.handleAction(.share, for: document)
        }
        
        Button(document.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
            actionsManager.handleAction(.toggleFavorite, for: document)
        }
        
        Button("Delete", role: .destructive) {
            actionsManager.handleAction(.delete, for: document)
        }
        
        Button("Cancel", role: .cancel) {
            actionsManager.cancelAction()
        }
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}