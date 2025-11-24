import Foundation
import SwiftUI
import UIKit
import Combine

@MainActor
final class DocumentActionsManager: ObservableObject {
    
    @Published var showingPreview = false
    @Published var showingRenameAlert = false
    @Published var showingDeleteAlert = false
    @Published var showingShareSheet = false
    @Published var showingActionSheet = false
    
    @Published var selectedDocument: DocumentDTO?
    @Published var previewURL: URL?
    @Published var newDocumentName = ""
    @Published var shareItems: [Any] = []
    
    private var pdfStorage: PDFStorage?
    
    func configure(with pdfStorage: PDFStorage) {
        self.pdfStorage = pdfStorage
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
            handleEdit(document)
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
        // TODO: Implement edit functionality
        print("Edit document: \(document.name)")
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
        selectedDocument = nil
        newDocumentName = ""
    }
}