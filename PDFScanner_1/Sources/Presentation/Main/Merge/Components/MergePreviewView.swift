import SwiftUI
import PDFKit

struct MergePreviewView: View {
    
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var pdfStorage: PDFStorage
    
    let mergedPDFURL: URL
    let arrangedDocuments: [DocumentDTO]
    
    @State private var documentName: String = ""
    @State private var isShowingSaveSheet: Bool = false
    @State private var isSaving: Bool = false
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            if let pdfDocument = PDFDocument(url: mergedPDFURL) {
                // PDF Preview
                PDFViewWrapper(pdfDocument: pdfDocument)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Bottom Actions
                VStack(spacing: 16) {
                    // Document Info
                    VStack(spacing: 8) {
                        Text("Merged Document")
                            .font(.bold(18))
                            .foregroundColor(.appText)
                        
                        Text("\(arrangedDocuments.count) documents • \(pdfDocument.pageCount) pages")
                            .font(.medium(14))
                            .foregroundColor(.appSecondary)
                    }
                    .padding(.top, 16)
                    
                    // Action Buttons
                    HStack(spacing: 12) {
                        Button("Cancel") {
                            router.pop()
                        }
                        .font(.medium(16))
                        .foregroundColor(.appSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.appSurface)
                        .cornerRadius(12)
                        
                        Button("Save Document") {
                            documentName = generateDefaultName()
                            isShowingSaveSheet = true
                        }
                        .font(.medium(16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.appPrimary)
                        .cornerRadius(12)
                        .disabled(isSaving)
                    }
                }
                .padding(16)
                .background(Color.appBackground)
            } else {
                // Error State
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.appSecondary)
                    
                    Text("Failed to load merged document")
                        .font(.medium(16))
                        .foregroundColor(.appSecondary)
                    
                    Button("Go Back") {
                        router.pop()
                    }
                    .font(.medium(16))
                    .foregroundColor(.appPrimary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Merge Preview")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingSaveSheet) {
            DocumentNameInputView(
                documentName: $documentName,
                onSave: {
                    isShowingSaveSheet = false
                    saveDocument()
                },
                onCancel: {
                    isShowingSaveSheet = false
                }
            )
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Setup complete
        }
    }
    
    // MARK: - Actions
    
    private func saveDocument() {
        let trimmedName = documentName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return
        }
        
        isSaving = true
        
        Task {
            do {
                guard let pdfDocument = PDFDocument(url: mergedPDFURL) else {
                    throw MergeError.processingFailed
                }
                
                let document = DocumentDTO(
                    id: UUID().uuidString,
                    pdf: pdfDocument,
                    name: trimmedName,
                    type: .pdf,
                    date: Date(),
                    url: nil,
                    isFavorite: false
                )
                
                try await pdfStorage.saveDocument(document)
                
                await MainActor.run {
                    isSaving = false
                    DELogger.log(text: "✅ Merged document saved: \(document.name)")
                    
                    // Navigate back to dashboard
                    router.popToRoot()
                }
                
                // Clean up temp file
                try? FileManager.default.removeItem(at: mergedPDFURL)
                
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func generateDefaultName() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        return "Merged Document \(dateFormatter.string(from: Date()))"
    }
}

// MARK: - Document Name Input View

struct DocumentNameInputView: View {
    @Binding var documentName: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Drag handle area
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            
            VStack(spacing: 16) {
                Text("Save Document")
                    .font(.bold(18))
                    .foregroundColor(.appText)
                
                Text("Enter a name for your merged document")
                    .font(.regular(14))
                    .foregroundColor(.appSecondary)
                    .multilineTextAlignment(.center)
                
                TextField("Document Name", text: $documentName)
                    .font(.regular(16))
                    .padding(12)
                    .background(Color.appSurface)
                    .cornerRadius(8)
                    .focused($isTextFieldFocused)
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .font(.medium(16))
                    .foregroundColor(.appSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.appSurface)
                    .cornerRadius(8)
                    
                    Button("Save") {
                        onSave()
                    }
                    .font(.medium(16))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(documentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.appPrimary)
                    .cornerRadius(8)
                    .disabled(documentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.horizontal, 20)
            
            Spacer(minLength: 0)
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
}

// MARK: - PDF View Wrapper

struct PDFViewWrapper: UIViewRepresentable {
    let pdfDocument: PDFDocument
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = pdfDocument
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.backgroundColor = UIColor.systemBackground
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== pdfDocument {
            pdfView.document = pdfDocument
        }
    }
}

#Preview {
    MergePreviewView(
        mergedPDFURL: URL(fileURLWithPath: "/tmp/test.pdf"),
        arrangedDocuments: []
    )
    .environmentObject(Router())
    .environmentObject(PDFStorage())
}