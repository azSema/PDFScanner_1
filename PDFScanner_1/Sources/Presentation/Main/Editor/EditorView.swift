import SwiftUI
import PhotosUI
import PDFKit

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
                    // PDF Editor View with Signature Overlay
                    GeometryReader { geometry in
                        ZStack {
                            PDFEditorView(editService: editService)
                                .onReceive(editService.$insertionPoint) { point in
                                    // Handle image insertion when point is set
                                    if editService.showingImagePicker && point != .zero {
                                        // Store geometry size for coordinate conversion
                                        editService.insertionGeometry = geometry.size
                                    }
                                }
                            
                            // Signature overlay when active
                            if let signatureAnnotation = editService.activeSignatureOverlay {
                                SignatureOverlay(
                                    editService: editService,
                                    annotation: Binding<IdentifiablePDFAnnotation>(
                                        get: { editService.activeSignatureOverlay ?? signatureAnnotation },
                                        set: { editService.activeSignatureOverlay = $0 }
                                    ),
                                    geometry: geometry
                                )
                                .onTapGesture(count: 2) {
                                    // Double tap to finalize signature
                                    print("👆 Double tap - finalizing signature")
                                    editService.finalizeSignatureOverlay()
                                }
                                
                                // Signature overlay instruction
                                VStack {
                                    HStack {
                                        Spacer()
                                        VStack(spacing: 8) {
                                            Text("Position your signature")
                                                .font(.medium(14))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(Color.black.opacity(0.7))
                                                .cornerRadius(8)
                                            
                                            Button("Done") {
                                                editService.finalizeSignatureOverlay()
                                            }
                                            .font(.medium(14))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.appPrimary)
                                            .cornerRadius(8)
                                        }
                                        .padding(.top, 20)
                                        .padding(.trailing, 16)
                                        Spacer()
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                    .pdfDocumentFrame(
                        pageRect: editService.currentPage?.bounds(for: .mediaBox) ?? CGRect(x: 0, y: 0, width: 595, height: 842),
                        rotation: Int(editService.currentPage?.rotation ?? 0),
                        maxRatio: 0.7
                    )
                    
                    Spacer()
                    
                    // Highlight Panel (appears above toolbar when active)
                    if editService.showingHighlightPanel {
                        HighlightPanel(editService: editService)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // Editor Toolbar
                    if editService.isToolbarVisible {
                        EditorToolbar(editService: editService)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
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
            } onCancel: {
                editService.resetSignatureService()
                editService.showingSignatureCreator = false
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

#Preview {
    EditorView(documentId: UUID())
        .environmentObject(Router())
        .environmentObject(PDFStorage())
}
