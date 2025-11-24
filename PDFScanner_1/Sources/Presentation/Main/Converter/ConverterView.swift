import SwiftUI
import PDFKit

struct ConverterView: View {
    
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var pdfStorage: PDFStorage
    @StateObject private var viewModel = ConversionViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isProcessing {
                processingView
            } else {
                mainContent
            }
        }
        .navigationTitle("PDF to Images")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.showingDocumentSelection) {
            DocumentSelectionView(destination: .converter) { document in
                viewModel.documentSelected(document)
            }
        }
        .sheet(isPresented: $viewModel.showingPreview) {
            ConversionResultView(
                resultURLs: viewModel.resultURLs,
                selectedDocument: viewModel.selectedDocument,
                onDismiss: {
                    viewModel.reset()
                }
            )
        }
        .alert("Conversion Error", isPresented: $viewModel.showingError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 32) {
                headerSection
                conversionCard
                recentDocumentsSection
                Spacer(minLength: 32)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 64))
                .foregroundColor(.appPrimary)

            Text("Convert PDF pages to optimized JPG images")
                .font(.medium(16))
                .foregroundColor(.appSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 32)
    }
    
    private var conversionCard: some View {
        VStack(spacing: 20) {
            Button("Select PDF Document") {
                viewModel.startConversion()
            }
            .font(.medium(18))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.appPrimary)
            .cornerRadius(16)
            .padding(.horizontal, 24)
            
            VStack(spacing: 8) {
                Text("Features:")
                    .font(.medium(16))
                    .foregroundColor(.appText)
                
                VStack(alignment: .leading, spacing: 4) {
                    FeatureRow(icon: "photo", text: "High-quality 150 DPI images")
                    FeatureRow(icon: "square.and.arrow.up", text: "Easy sharing options")
                    FeatureRow(icon: "doc.on.doc", text: "All pages converted individually")
                    FeatureRow(icon: "memorychip", text: "Memory optimized for large PDFs")
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.vertical, 24)
        .background(Color.appSurface)
        .cornerRadius(20)
        .padding(.horizontal, 24)
    }
    
    private var recentDocumentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Documents")
                    .font(.bold(20))
                    .foregroundColor(.appText)
                
                Spacer()
                
                if !pdfStorage.documents.isEmpty {
                    Button("View All") {
                        router.push(.main(.history))
                    }
                    .font(.medium(14))
                    .foregroundColor(.appPrimary)
                }
            }
            .padding(.horizontal, 24)
            
            if pdfStorage.documents.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.appSecondary.opacity(0.5))
                    
                    Text("No documents yet")
                        .font(.medium(16))
                        .foregroundColor(.appSecondary)
                    
                    Text("Scan or add PDF documents to get started")
                        .font(.regular(14))
                        .foregroundColor(.appSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(pdfStorage.documents.prefix(5)), id: \.id) { document in
                            QuickDocumentCard(document: document) {
                                viewModel.documentSelected(document)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }
    
    // MARK: - Processing View
    
    private var processingView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 72))
                    .foregroundColor(.appPrimary)
                
                Text("Converting PDF...")
                    .font(.bold(24))
                    .foregroundColor(.appText)
                
                Text("Extracting pages as optimized images")
                    .font(.medium(16))
                    .foregroundColor(.appSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.appPrimary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.appBackground)
    }
}

// MARK: - Supporting Views

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.appPrimary)
                .frame(width: 20)
            
            Text(text)
                .font(.regular(14))
                .foregroundColor(.appText)
            
            Spacer()
        }
    }
}

struct QuickDocumentCard: View {
    let document: DocumentDTO
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(uiImage: document.thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.appBorder, lineWidth: 1)
                    )
                
                Text(document.name)
                    .font(.regular(12))
                    .foregroundColor(.appText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 80)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Conversion Result View

struct ConversionResultView: View {
    let resultURLs: [URL]
    let selectedDocument: DocumentDTO?
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
            .navigationTitle("Converted Images")
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
            ShareSheet(items: resultURLs)
        }
    }
}

// MARK: - ShareSheet Helper

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

#Preview {
    ConverterView()
        .environmentObject(Router())
        .environmentObject(PDFStorage())
}
