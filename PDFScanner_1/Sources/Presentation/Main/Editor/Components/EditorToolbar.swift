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
                    },
                    editService: editService
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
        .padding(.bottom, 8)
        .background(Color.appSurface)
        .shadow(color: Color.black.opacity(editService.showingHighlightPanel ? 0 : 0.1), radius: 4, x: 0, y: 2)
    }
}

struct ToolButton: View {
    
    let tool: EditorTool
    let isSelected: Bool
    let onTap: () -> Void
    @ObservedObject var editService: EditService
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    if tool == .highlight && editService.selectedHighlightColor.isClearMode && isSelected {
                        // Clear mode - show crossed out highlighter
                        ZStack {
                            Image(systemName: tool.systemImage)
                                .font(.system(size: 20))
                                .foregroundColor(isSelected ? .white.opacity(0.7) : .appText)
                            
                            // Diagonal line (slash)
                            Rectangle()
                                .fill(isSelected ? Color.white : Color.red)
                                .frame(width: 2, height: 24)
                                .rotationEffect(.degrees(45))
                        }
                    } else {
                        // Regular tool icon
                        Image(systemName: tool.systemImage)
                            .font(.system(size: 20))
                            .foregroundColor(isSelected ? .white : .appText)
                    }
                }
                
                Text(tool == .highlight && editService.selectedHighlightColor.isClearMode && isSelected ? "Clear" : tool.title)
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
                HStack {
                    Text("Color")
                        .font(.medium(14))
                        .foregroundColor(.appText)
                    
                    if editService.selectedHighlightColor.isClearMode {
                        Spacer()
                        Text("Clear Mode")
                            .font(.regular(12))
                            .foregroundColor(.red)
                    }
                }
                
                HStack(spacing: 12) {
                    ForEach(HighlightColor.allCases, id: \.self) { color in
                        Button(action: {
                            editService.updateHighlightColor(color)
                        }) {
                            ZStack {
                                if color.isClearMode {
                                    // Clear mode - show crossed out circle
                                    ZStack {
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 32, height: 32)
                                        
                                        // Diagonal line (slash)
                                        Rectangle()
                                            .fill(Color.red)
                                            .frame(width: 2, height: 36)
                                            .rotationEffect(.degrees(45))
                                        
                                        // Clear icon
                                        Image(systemName: "highlighter")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                    }
                                } else {
                                    // Regular color circle
                                    Circle()
                                        .fill(Color(color.color))
                                        .frame(width: 32, height: 32)
                                }
                                
                                // Selection border
                                Circle()
                                    .stroke(
                                        editService.selectedHighlightColor == color ?
                                        Color.appText : Color.clear,
                                        lineWidth: 2
                                    )
                                    .frame(width: 32, height: 32)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Clear mode instruction
                if editService.selectedHighlightColor.isClearMode {
                    Text("Select text to remove existing highlights")
                        .font(.regular(12))
                        .foregroundColor(.appSecondary)
                        .italic()
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
    }
    
}

#Preview {
    let editService = EditService()
    VStack {
        Spacer()
        
        EditorToolbar(editService: editService)
            .padding()
        
        HighlightPanel(editService: editService)
            .padding()
    }
    .background(Color.appBackground)
}
