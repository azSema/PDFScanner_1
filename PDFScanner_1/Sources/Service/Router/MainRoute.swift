import SwiftUI

enum MainRoute: AppDestination {
    case dashboard
    case scanner
    case documentSelection(destination: DocumentDestination)
    case converter
    case editor(documentId: UUID)
    case merge
    case mergePreview(url: URL, arrangedDocuments: [DocumentDTO])
    case history
    case documentDetail(documentId: UUID)
    
    @ViewBuilder
    func makeView() -> some View {
        switch self {
        case .dashboard:
            DashboardView()
        case .scanner:
            ScannerView()
        case .documentSelection(let destination):
            DocumentSelectionView(destination: destination)
        case .converter:
            ConverterView()
        case .editor(let documentId):
            EditorView(documentId: documentId)
        case .merge:
            MergeView()
        case .mergePreview(let url, let arrangedDocuments):
            MergePreviewView(mergedPDFURL: url, arrangedDocuments: arrangedDocuments)
        case .history:
            HistoryView()
        case .documentDetail(let documentId):
            DocumentDetailView(documentId: documentId)
        }
    }
}
