import SwiftUI
import PDFKit

struct PDFEditorView: UIViewRepresentable {
    
    @ObservedObject var editService: EditService
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        
        // Configure PDF view
        pdfView.backgroundColor = UIColor.systemBackground
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .horizontal
        pdfView.pageBreakMargins = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        
        // Set delegate for interactions
        pdfView.delegate = context.coordinator
        
        // Add gesture recognizers based on selected tool
        setupGestureRecognizers(for: pdfView, coordinator: context.coordinator)
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        // Update document
        if let document = editService.pdfDocument {
            pdfView.document = document
            
            // Go to current page
            if let page = document.page(at: editService.currentPageIndex) {
                pdfView.go(to: page)
            }
        }
        
        // Update gesture recognizers based on selected tool
        updateGestureRecognizers(for: pdfView, coordinator: context.coordinator)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func setupGestureRecognizers(for pdfView: PDFView, coordinator: Coordinator) {
        // Remove existing gestures
        pdfView.gestureRecognizers?.removeAll()
        
        // Add tap gesture for tool interactions
        let tapGesture = UITapGestureRecognizer(target: coordinator, action: #selector(coordinator.handleTap(_:)))
        tapGesture.numberOfTapsRequired = 1
        pdfView.addGestureRecognizer(tapGesture)
        
        // Store reference for updates
        coordinator.tapGesture = tapGesture
    }
    
    private func updateGestureRecognizers(for pdfView: PDFView, coordinator: Coordinator) {
        guard let tapGesture = coordinator.tapGesture else { return }
        
        // Enable/disable based on selected tool
        tapGesture.isEnabled = editService.selectedTool != nil
    }
    
    class Coordinator: NSObject, PDFViewDelegate {
        let parent: PDFEditorView
        var tapGesture: UITapGestureRecognizer?
        
        init(_ parent: PDFEditorView) {
            self.parent = parent
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let pdfView = gesture.view as? PDFView else { return }
            
            let point = gesture.location(in: pdfView)
            let bounds = pdfView.bounds
            
            // Handle tap based on selected tool
            switch parent.editService.selectedTool {
            case .highlight:
                parent.editService.applyHighlight(at: point, in: bounds)
                
            case .addImage:
                if parent.editService.showingImageInsertMode {
                    // Store insertion point and show image picker
                    parent.editService.insertionPoint = point
                    parent.editService.showingImagePicker = true
                }
                
            case .signature:
                if parent.editService.showingSignatureInsertMode {
                    parent.editService.insertSignature(at: point)
                }
                
            default:
                break
            }
        }
        
        // MARK: - PDFViewDelegate
        
        func pdfViewWillClick(onLink sender: PDFView, with url: URL) {
            // Handle link clicks if needed
        }
        
        func pdfViewParentViewController(for sender: PDFView) -> UIViewController? {
            // Return parent view controller if needed for presentations
            return nil
        }
    }
}