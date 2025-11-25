import SwiftUI

struct RecentScansRow: View {
    let documents: [DocumentDTO]
    let onDocumentTap: (DocumentDTO) -> Void
    let actionsManager: DocumentActionsManager
    
    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(documents, id: \.id) { document in
                DocumentCard(
                    document: document,
                    onTap: {
                        HapticService.shared.impact(.light)
                        onDocumentTap(document)
                    },
                    actionsManager: actionsManager
                )
            }
        }
        .padding(.horizontal, 20)
    }
}
