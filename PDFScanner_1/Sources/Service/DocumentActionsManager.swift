import Foundation
import SwiftUI
import UIKit
import Combine

@MainActor
final class DocumentActionsManager: ObservableObject {
    
    weak var premium: PremiumManager?
    
    @Published var showingPreview = false
    @Published var showingRenameAlert = false
    @Published var showingDeleteAlert = false
    @Published var showingShareSheet = false
    @Published var showingActionSheet = false
    @Published var showingConvertResult = false
    
    @Published var selectedDocument: DocumentDTO?
    @Published var previewURL: URL?
    @Published var newDocumentName = ""
    @Published var shareItems: [Any] = []
    @Published var convertResultURLs: [URL] = []
    
    @AppStorage("convertCount") private var convertCount = 0
    @AppStorage("mergeCount") private var mergeCount = 0
    
    private var pdfStorage: PDFStorage?
    private var router: Router?
    
    func configure(with pdfStorage: PDFStorage, router: Router? = nil) {
        self.pdfStorage = pdfStorage
        self.router = router
    }
    
    // MARK: - Actions
    
    func showActionSheet(for document: DocumentDTO) {
        selectedDocument = document
        showingActionSheet = true
    }
    
    func handleAction(_ action: DocumentAction, for document: DocumentDTO) {
        selectedDocument = document
        
        switch action {
        case .preview:
            handlePreview(document)
        case .edit:
            guard let premium, premium.canEdit() else {
                premium?.isShowingPaywall.toggle()
                return
            }
            handleEdit(document)
        case .convert:
            guard let premium, premium.canConvert(currentConvertsNumber: convertCount) else {
                premium?.isShowingPaywall.toggle()
                return
            }
            handleConvert(document)
        case .rename:
            handleRename(document)
        case .share:
            handleShare(document)
        case .toggleFavorite:
            handleToggleFavorite(document)
        case .delete:
            handleDelete(document)
        }
    }
    
    // MARK: - Individual Actions
    
    private func handlePreview(_ document: DocumentDTO) {
        guard let url = document.url else { return }
        previewURL = url
        showingPreview = true
    }
    
    private func handleEdit(_ document: DocumentDTO) {
        guard let documentId = UUID(uuidString: document.id) else { return }
        router?.push(.main(.editor(documentId: documentId)))
    }
    
    private func handleConvert(_ document: DocumentDTO) {
        Task {
            do {
                let converter = Converter()
                guard let pdfURL = document.url else { return }
                let imageURLs = try await converter.convertPDFToJPG(pdfURL: pdfURL, dpi: 150.0)
                
                await MainActor.run {
                    self.convertResultURLs = imageURLs
                    self.showingConvertResult = true
                }
            } catch {
                print("Conversion failed: \(error)")
                // TODO: Show error alert
            }
        }
    }
    
    private func handleRename(_ document: DocumentDTO) {
        newDocumentName = document.name
        showingRenameAlert = true
    }
    
    private func handleShare(_ document: DocumentDTO) {
        guard let url = document.url else { return }
        shareItems = [url]
        showingShareSheet = true
    }
    
    private func handleToggleFavorite(_ document: DocumentDTO) {
        pdfStorage?.toggleFavorite(document)
    }
    
    private func handleDelete(_ document: DocumentDTO) {
        showingDeleteAlert = true
    }
    
    // MARK: - Confirmation Actions
    
    func confirmRename() {
        guard let document = selectedDocument,
              !newDocumentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        pdfStorage?.renameDocument(document, to: newDocumentName.trimmingCharacters(in: .whitespacesAndNewlines))
        showingRenameAlert = false
        selectedDocument = nil
        newDocumentName = ""
    }
    
    func confirmDelete() {
        guard let document = selectedDocument else { return }
        
        pdfStorage?.removeDocument(document)
        showingDeleteAlert = false
        selectedDocument = nil
    }
    
    func cancelAction() {
        showingRenameAlert = false
        showingDeleteAlert = false
        showingActionSheet = false
        showingConvertResult = false
        selectedDocument = nil
        newDocumentName = ""
        convertResultURLs = []
    }
}
