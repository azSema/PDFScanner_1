import SwiftUI
import PhotosUI

struct EditorView: View {
    
    let documentId: UUID
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var pdfStorage: PDFStorage
    @StateObject private var editService = EditService()
    
    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            if editService.pdfDocument != nil {
                VStack(spacing: 0) {
                    // PDF Editor View
                    GeometryReader { geometry in
                        PDFEditorView(editService: editService)
                            .onReceive(editService.$insertionPoint) { point in
                                // Handle image insertion when point is set
                                if editService.showingImagePicker && point != .zero {
                                    // Store geometry size for coordinate conversion
                                    editService.insertionGeometry = geometry.size
                                }
                            }
                    }
                    
                    // Highlight Panel (appears above toolbar when active)
                    if editService.showingHighlightPanel {
                        HighlightPanel(editService: editService)
                            .padding(.horizontal, 16)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // Editor Toolbar
                    if editService.isToolbarVisible {
                        EditorToolbar(editService: editService)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            
                    }
                }
                .edgesIgnoringSafeArea(.bottom)
            } else {
                // Loading or error state
                VStack(spacing: 16) {
                    if editService.isProcessing {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.appPrimary)
                        
                        Text("Loading document...")
                            .font(.medium(16))
                            .foregroundColor(.appSecondary)
                    } else {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.appSecondary.opacity(0.5))
                        
                        Text("Document not found")
                            .font(.medium(18))
                            .foregroundColor(.appText)
                        
                        Text("The selected document could not be loaded")
                            .font(.regular(14))
                            .foregroundColor(.appSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    if editService.hasUnsavedChanges {
                        // Show unsaved changes alert
                        showUnsavedChangesAlert()
                    } else {
                        router.pop()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.medium(16))
                        Text("Back")
                            .font(.medium(16))
                    }
                    .foregroundColor(.appPrimary)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // Hide/Show toolbar button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            editService.isToolbarVisible.toggle()
                        }
                    }) {
                        Image(systemName: editService.isToolbarVisible ? "eye.slash" : "eye")
                            .font(.medium(16))
                            .foregroundColor(.appText)
                    }
                    
                    // Save button
                    if editService.hasUnsavedChanges {
                        Button("Save") {
                            Task {
                                do {
                                    try await editService.saveChanges()
                                } catch {
                                    // Handle save error
                                    print("Save error: \(error)")
                                }
                            }
                        }
                        .font(.medium(16))
                        .foregroundColor(.appPrimary)
                        .disabled(editService.isProcessing)
                    }
                }
            }
        }
        .onAppear {
            editService.configure(documentId: documentId, pdfStorage: pdfStorage)
        }
        .photosPicker(
            isPresented: $editService.showingImagePicker,
            selection: .constant([]),
            maxSelectionCount: 1,
            matching: .images
        )
        .sheet(isPresented: $editService.showingSignatureCreator) {
            SignatureCreatorView { signature in
                editService.saveSignature(signature)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: editService.showingHighlightPanel)
        .animation(.easeInOut(duration: 0.3), value: editService.isToolbarVisible)
    }
    
    private func showUnsavedChangesAlert() {
        // TODO: Implement unsaved changes alert
        // For now, just pop back
        router.pop()
    }
}

// MARK: - Signature Creator View (Placeholder)

struct SignatureCreatorView: View {
    let onSave: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Text("Signature Creator")
                .font(.bold(20))
                .foregroundColor(.appText)
            
            Text("Signature creation UI will be implemented here")
                .font(.regular(16))
                .foregroundColor(.appSecondary)
                .multilineTextAlignment(.center)
                .padding()
            
            Spacer()
        }
        .padding()
        .navigationTitle("Create Signature")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    // TODO: Save signature
                    dismiss()
                }
                .disabled(true)
            }
        }
    }
}

#Preview {
    EditorView(documentId: UUID())
        .environmentObject(Router())
        .environmentObject(PDFStorage())
}
