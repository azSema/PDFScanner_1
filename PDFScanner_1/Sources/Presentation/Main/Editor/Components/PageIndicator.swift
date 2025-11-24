import SwiftUI
import PDFKit

struct PageIndicator: View {
    @ObservedObject var editService: EditService
    
    var body: some View {
        HStack {
            // Page info
            if let document = editService.pdfDocument {
                HStack(spacing: 8) {
                    Text("Page")
                        .font(.regular(12))
                        .foregroundColor(.appSecondary)
                    
                    Text("\(editService.currentPageIndex + 1) / \(document.pageCount)")
                        .font(.medium(14))
                        .foregroundColor(.appText)
                    
                    // Add page button when on last page
                    if editService.currentPageIndex == document.pageCount - 1 {
                        Divider()
                            .frame(height: 16)
                        
                        Button(action: {
                            editService.addPageFromFiles() // Directly open file importer
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .medium))
                                Text("Add PDF")
                                    .font(.medium(12))
                            }
                            .foregroundColor(.appPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.appPrimary.opacity(0.1))
                            .cornerRadius(16)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.appSurface.opacity(0.9))
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
        }
    }
}

#Preview {
    let editService = EditService()
    VStack {
        PageIndicator(editService: editService)
        Spacer()
    }
    .background(Color.appBackground)
}