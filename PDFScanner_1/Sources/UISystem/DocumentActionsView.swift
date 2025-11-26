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
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("Done") {
                                        actionsManager.showingPreview = false
                                    }
                                }
                            }
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
            .sheet(isPresented: $actionsManager.showingConvertResult) {
                if !actionsManager.convertResultURLs.isEmpty {
                    ConvertResultActionsView(
                        resultURLs: actionsManager.convertResultURLs,
                        documentName: actionsManager.selectedDocument?.name ?? "Document",
                        onDismiss: {
                            actionsManager.cancelAction()
                        }
                    )
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
        
        Button(action: { actionsManager.handleAction(.convert, for: document) }) {
            Label("Convert to Images", systemImage: "arrow.triangle.2.circlepath")
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
        
        Button("Convert to Images") {
            actionsManager.handleAction(.convert, for: document)
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

// MARK: - Convert Result View

struct ConvertResultActionsView: View {
    let resultURLs: [URL]
    let documentName: String
    let onDismiss: () -> Void
    
    @State private var selectedImageIndex = 0
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if !resultURLs.isEmpty {
                    // Image viewer
                    TabView(selection: $selectedImageIndex) {
                        ForEach(Array(resultURLs.enumerated()), id: \.offset) { index, url in
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                ProgressView()
                            }
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Action bar
                    VStack(spacing: 16) {
                        Text("Page \(selectedImageIndex + 1) of \(resultURLs.count)")
                            .font(.medium(16))
                            .foregroundColor(.appSecondary)
                        
                        Button("Share All Images") {
                            showingShareSheet = true
                        }
                        .font(.medium(16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.appPrimary)
                        .cornerRadius(12)
                    }
                    .padding(16)
                    .background(Color.appSurface)
                } else {
                    Text("No images generated")
                        .font(.medium(16))
                        .foregroundColor(.appSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("\(documentName) - Converted")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .foregroundColor(.appPrimary)
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ActivityViewController(activityItems: resultURLs)
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
