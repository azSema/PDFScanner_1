import SwiftUI

struct DocumentSelectionView: View {
    let destination: DocumentDestination
    var onDocumentSelected: ((DocumentDTO) -> Void)? = nil
    
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var pdfStorage: PDFStorage
    @EnvironmentObject private var premium: PremiumManager
    
    @StateObject private var actionsManager = DocumentActionsManager()
    
    @State private var selectedDocuments: Set<String> = []
    
    var body: some View {
        VStack(spacing: 0) {
            if pdfStorage.isLoading {
                loadingView
            } else if pdfStorage.documents.isEmpty {
                emptyView
            } else {
                documentsList
            }
        }
        .navigationTitle(destination.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            
            if destination.allowsMultipleSelection && !selectedDocuments.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Continue") {
                        handleContinue()
                    }
                    .foregroundColor(.appPrimary)
                }
            }
        }
        .onAppear {
            actionsManager.configure(with: pdfStorage, router: router)
            actionsManager.premium = premium
        }
        .background {
            DocumentActionsView(actionsManager: actionsManager)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
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
        .background(Color.appBackground)
    }
    
    private var emptyView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "doc.text")
                .font(.system(size: 64))
                .foregroundColor(.appSecondary)
            
            VStack(spacing: 8) {
                Text("No Documents Found")
                    .font(.bold(24))
                    .foregroundColor(.appText)
                
                Text("Scan your first document to get started")
                    .font(.medium(16))
                    .foregroundColor(.appSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Start Scanning") {
                router.pop()
                router.push(.main(.scanner))
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 16)
            
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
    
    private var documentsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(pdfStorage.documents) { document in
                    DocumentCell(
                        document: document,
                        isSelected: selectedDocuments.contains(document.id),
                        allowsSelection: destination.allowsMultipleSelection,
                        onTap: {
                            if destination.allowsMultipleSelection {
                                if selectedDocuments.contains(document.id) {
                                    selectedDocuments.remove(document.id)
                                } else {
                                    selectedDocuments.insert(document.id)
                                }
                            } else {
                                // Single selection - handle immediately
                                if let onDocumentSelected = onDocumentSelected {
                                    onDocumentSelected(document)
                                } else {
                                    selectedDocuments.insert(document.id)
                                    handleContinue()
                                }
                            }
                        },
                        onSelectionToggle: destination.allowsMultipleSelection ? {
                            if selectedDocuments.contains(document.id) {
                                selectedDocuments.remove(document.id)
                            } else {
                                selectedDocuments.insert(document.id)
                            }
                        } : nil,
                        actionsManager: actionsManager
                    )
                }
            }
            .padding(16)
        }
        .background(Color.appSurface)
    }
    
    private func handleDocumentTap(_ document: DocumentDTO) {
        if destination.allowsMultipleSelection {
            toggleSelection(for: document)
        } else {
            // Single selection - navigate immediately
            navigateToDestination(with: [document])
        }
    }
    
    private func toggleSelection(for document: DocumentDTO) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if selectedDocuments.contains(document.id) {
                selectedDocuments.remove(document.id)
            } else {
                if destination.allowsMultipleSelection {
                    selectedDocuments.insert(document.id)
                } else {
                    selectedDocuments = [document.id]
                }
            }
        }
    }
    
    private func handleContinue() {
        let selectedDocs = pdfStorage.documents.filter { selectedDocuments.contains($0.id) }
        navigateToDestination(with: selectedDocs)
    }
    
    private func navigateToDestination(with documents: [DocumentDTO]) {
        guard let firstDocument = documents.first else { return }
        
        router.pop() // Remove selection view
        
        switch destination {
        case .history:
            // History doesn't need selection - just show the list
            break
            
        case .editor:
            router.push(.main(.editor(documentId: UUID(uuidString: firstDocument.id) ?? UUID())))
            
        case .converter:
            // Converter handled by callback
            if let onDocumentSelected = onDocumentSelected {
                onDocumentSelected(firstDocument)
            } else {
                router.push(.main(.converter))
            }
            
        case .merge:
            router.push(.main(.merge))
            // TODO: Pass selected documents to merge
        }
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.semibold(18))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.appPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

#Preview {
    DocumentSelectionView(destination: .merge)
        .environmentObject(Router())
}
