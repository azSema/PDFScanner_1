import SwiftUI
import PDFKit

struct PDFEditorView: UIViewRepresentable {
    
    @ObservedObject var editService: EditService
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.backgroundColor = .systemBackground
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .horizontal
        pdfView.pageBreakMargins = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        if let scrollView = pdfView.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView {
            scrollView.showsVerticalScrollIndicator = false
            scrollView.showsHorizontalScrollIndicator = false
        }

        pdfView.delegate = context.coordinator
        editService.setPDFViewReference(pdfView)
        setupGestureRecognizers(for: pdfView, coordinator: context.coordinator)
        setupNotifications(for: pdfView, coordinator: context.coordinator)
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
            
            // Log actual PDFView bounds for coordinate debugging
            print("📐 PDFView actual bounds: \(pdfView.bounds)")
            if let documentView = pdfView.documentView {
                print("📐 PDFView documentView bounds: \(documentView.bounds)")
            }
        }
        
        // Update gesture recognizers based on selected tool
        updateGestureRecognizers(for: pdfView, coordinator: context.coordinator)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func setupGestureRecognizers(for pdfView: PDFView, coordinator: Coordinator) {
        // Add tap gesture for tool interactions
        let tapGesture = UITapGestureRecognizer(target: coordinator, action: #selector(coordinator.handleTap(_:)))
        tapGesture.numberOfTapsRequired = 1
        pdfView.addGestureRecognizer(tapGesture)
        
        // Store reference for updates
        coordinator.tapGesture = tapGesture
    }
    
    private func setupNotifications(for pdfView: PDFView, coordinator: Coordinator) {
        // Selection changed notification for highlights
        NotificationCenter.default.addObserver(
            coordinator,
            selector: #selector(coordinator.handleSelectionChanged(notification:)),
            name: .PDFViewSelectionChanged,
            object: pdfView
        )
        
        // Annotation hit notification for notes
        NotificationCenter.default.addObserver(
            coordinator,
            selector: #selector(coordinator.handleAnnotationHit(notification:)),
            name: .PDFViewAnnotationHit,
            object: pdfView
        )
    }
    
    private func updateGestureRecognizers(for pdfView: PDFView, coordinator: Coordinator) {
        guard let tapGesture = coordinator.tapGesture else { return }
        
        // Enable/disable based on selected tool
        switch editService.selectedTool {
        case .highlight:
            // Для highlight отключаем tap gesture, чтобы не мешать выделению текста
            tapGesture.isEnabled = false
            // ВАЖНО: Убеждаемся, что PDFView позволяет выделение текста
            pdfView.isUserInteractionEnabled = true
            // Отключаем другие жесты, которые могут мешать выделению
            if let scrollView = pdfView.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView {
                scrollView.panGestureRecognizer.isEnabled = true
                scrollView.pinchGestureRecognizer?.isEnabled = true
            }
        case .addImage, .signature:
            tapGesture.isEnabled = true
        default:
            tapGesture.isEnabled = false
        }
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
            
            // Get geometry size for coordinate conversion
            let geometrySize = pdfView.bounds.size
            
            // Handle tap based on selected tool
            switch parent.editService.selectedTool {
            case .addImage:
                tapGesture?.isEnabled = true
                // Отключаем zoom/pan жесты PDFView, чтобы не мешали overlay
                if let scrollView = pdfView.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView {
                    scrollView.panGestureRecognizer.isEnabled = false
                    scrollView.pinchGestureRecognizer?.isEnabled = false
                }
                
            case .signature:
                if parent.editService.showingSignatureInsertMode {
                    parent.editService.insertSignature(at: point, geometrySize: geometrySize)
                }
                
            default:
                break
            }
        }
        
        @objc func handleSelectionChanged(notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let page = pdfView.currentPage,
                  let selection = pdfView.currentSelection,
                  let selectedText = selection.string else { return }
            
            // Handle text selection for highlights
            if parent.editService.selectedTool == .highlight {
                let bounds = selection.bounds(for: page)
                let geometrySize = pdfView.bounds.size
                
                // Use AnnotationsService to handle highlight
                parent.editService.handleTextSelection(
                    selectedText: selectedText,
                    bounds: bounds,
                    geometrySize: geometrySize
                )
                
                // Clear selection after processing
                pdfView.clearSelection()
            }
        }
        
        @objc func handleAnnotationHit(notification: Notification) {
            guard let userInfo = notification.userInfo,
                  let annotation = userInfo["PDFAnnotationHit"] as? PDFAnnotation,
                  let noteText = annotation.contents else { return }
            
            // Handle note annotation taps
            print("Note tapped: \(noteText)")
            // TODO: Show note editing interface
        }
        
        // MARK: - PDFViewDelegate
        
        func pdfViewWillClick(onLink sender: PDFView, with url: URL) {
            // Handle link clicks if needed
        }
        
        func pdfViewParentViewController(for sender: PDFView) -> UIViewController? {
            // Return parent view controller if needed for presentations
            return nil
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self, name: .PDFViewSelectionChanged, object: nil)
            NotificationCenter.default.removeObserver(self, name: .PDFViewAnnotationHit, object: nil)
        }
    }
}
