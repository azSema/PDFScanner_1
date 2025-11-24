import SwiftUI
import PDFKit

struct EditorToolbar: View {
    
    @ObservedObject var editService: EditService
    
    var body: some View {
        HStack(spacing: 16) {
            ForEach(EditorTool.allCases, id: \.self) { tool in
                ToolButton(
                    tool: tool,
                    isSelected: editService.selectedTool == tool,
                    onTap: {
                        editService.selectTool(tool)
                    }
                )
            }
            
            Spacer()
            
            // Page navigation
            if let document = editService.pdfDocument {
                HStack(spacing: 12) {
                    Button(action: { editService.goToPreviousPage() }) {
                        Image(systemName: "chevron.left")
                            .font(.medium(16))
                            .foregroundColor(.appText)
                    }
                    .disabled(editService.currentPageIndex == 0)
                    
                    Text("\(editService.currentPageIndex + 1) / \(document.pageCount)")
                        .font(.medium(14))
                        .foregroundColor(.appSecondary)
                    
                    Button(action: { editService.goToNextPage() }) {
                        Image(systemName: "chevron.right")
                            .font(.medium(16))
                            .foregroundColor(.appText)
                    }
                    .disabled(editService.currentPageIndex >= document.pageCount - 1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .padding(.bottom, 20)
        .background(Color.appSurface)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct ToolButton: View {
    
    let tool: EditorTool
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: tool.systemImage)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .white : .appText)
                
                Text(tool.title)
                    .font(.regular(10))
                    .foregroundColor(isSelected ? .white : .appSecondary)
            }
            .frame(width: 60, height: 50)
            .background(isSelected ? Color.appPrimary : Color.clear)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Highlight Panel

struct HighlightPanel: View {
    
    @ObservedObject var editService: EditService
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Highlight Settings")
                    .font(.medium(16))
                    .foregroundColor(.appText)
                
                Spacer()
                
                Button("Done") {
                    editService.showingHighlightPanel = false
                    editService.selectedTool = nil
                }
                .font(.medium(14))
                .foregroundColor(.appPrimary)
            }
            
            // Color selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.medium(14))
                    .foregroundColor(.appText)
                
                HStack(spacing: 12) {
                    ForEach(HighlightColor.allCases, id: \.self) { color in
                        Button(action: {
                            editService.updateHighlightColor(color)
                        }) {
                            Circle()
                                .fill(Color(color.color))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            editService.selectedHighlightColor == color ? 
                                            Color.appText : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                        }
                    }
                }
            }
            
            // Opacity slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Opacity")
                        .font(.medium(14))
                        .foregroundColor(.appText)
                    
                    Spacer()
                    
                    Text("\(Int(editService.highlightOpacity * 100))%")
                        .font(.regular(12))
                        .foregroundColor(.appSecondary)
                }
                
                Slider(
                    value: Binding(
                        get: { editService.highlightOpacity },
                        set: { editService.updateHighlightOpacity($0) }
                    ),
                    in: 0.1...0.8
                )
                .tint(.appPrimary)
            }
        }
        .padding(16)
        .background(Color.appSurface)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: -2)
    }
}

#Preview {
    VStack {
        Spacer()
        
        EditorToolbar(editService: EditService())
            .padding()
        
        HighlightPanel(editService: EditService())
            .padding()
    }
    .background(Color.appBackground)
}
