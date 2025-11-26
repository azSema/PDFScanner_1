import SwiftUI

struct MergeView: View {
    
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var pdfStorage: PDFStorage
    @EnvironmentObject private var premium: PremiumManager
    @StateObject private var viewModel = MergeViewModel()
    
    @AppStorage("mergeCount") private var mergeCount = 0
    
    var body: some View {
        Group {
            switch viewModel.currentState {
            case .selectDocuments:
                documentSelectionView
            case .arrangeOrder:
                orderArrangementView
            case .processing:
                processingView
            default:
                emptyView
            }
        }
        .navigationTitle("Merge Documents")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                trailingButton
            }
        }
        .onAppear {
            guard premium.canMerge(currentMergesNumber: mergeCount) else {
                premium.isShowingPaywall.toggle()
                return
            }
            viewModel.router = router
            viewModel.startMerge()
        }
    }
    
    // MARK: - Document Selection View
    private var documentSelectionView: some View {
        VStack(spacing: 0) {
            if pdfStorage.isLoading {
                loadingView
            } else if pdfStorage.documents.isEmpty {
                emptyView
            } else {
                VStack(spacing: 16) {
                    headerView
                    documentsList
                }
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("Select documents to merge")
                .font(.medium(16))
                .foregroundColor(.appSecondary)
                .multilineTextAlignment(.center)
            
            Text("Choose 2 or more documents")
                .font(.regular(14))
                .foregroundColor(.appSecondary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
    
    private var documentsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(pdfStorage.documents, id: \.id) { document in
                    DocumentSelectionCell(
                        document: document,
                        isSelected: viewModel.selectedDocuments.contains(document.id),
                        onSelectionToggle: {
                            viewModel.toggleDocumentSelection(for: document.id)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Order Arrangement View
    private var orderArrangementView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("Arrange merge order")
                    .font(.medium(16))
                    .foregroundColor(.appSecondary)
                
                Text("Drag documents to reorder them")
                    .font(.regular(14))
                    .foregroundColor(.appSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(viewModel.arrangedDocuments.enumerated()), id: \.element.id) { index, document in
                        DraggableDocumentCell(
                            document: document,
                            position: index + 1,
                            totalCount: viewModel.arrangedDocuments.count,
                            draggedItem: $viewModel.draggedItem,
                            dragOffset: $viewModel.dragOffset,
                            onMove: { fromIndex, toIndex in
                                viewModel.moveDocument(from: fromIndex, to: toIndex)
                            }
                        )
                        .zIndex(viewModel.draggedItem?.id == document.id ? 1 : 0)
                        .id("\(document.id)-\(index)")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
        }
    }
    
    // MARK: - Processing View
    private var processingView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
                .tint(.appPrimary)
            
            Text("Merging documents...")
                .font(.medium(16))
                .foregroundColor(.appSecondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Loading & Empty Views
    private var loadingView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
                .tint(.appPrimary)
            
            Text("Loading documents...")
                .font(.medium(16))
                .foregroundColor(.appSecondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "doc.text")
                .font(.system(size: 64))
                .foregroundColor(.appSecondary)
            
            VStack(spacing: 8) {
                Text("No Documents Found")
                    .font(.bold(24))
                    .foregroundColor(.appText)
                
                Text("Scan documents first to merge them")
                    .font(.medium(16))
                    .foregroundColor(.appSecondary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Trailing Button
    @ViewBuilder
    private var trailingButton: some View {
        switch viewModel.currentState {
        case .selectDocuments:
            Button("Continue") {
                viewModel.proceedToArrangeOrder(with: pdfStorage.documents)
            }
            .font(.medium(16))
            .foregroundColor(viewModel.canProceedToArrange ? .appPrimary : .appSecondary)
            .disabled(!viewModel.canProceedToArrange)
            
        case .arrangeOrder:
            Button("Merge") {
                mergeCount += 1
                viewModel.startMergeProcess()
            }
            .font(.medium(16))
            .foregroundColor(.appPrimary)
            
        case .processing:
            EmptyView()
            
        default:
            EmptyView()
        }
    }
}

// MARK: - Document Selection Cell
struct DocumentSelectionCell: View {
    let document: DocumentDTO
    let isSelected: Bool
    let onSelectionToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelectionToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .appPrimary : .appSecondary)
                    .font(.system(size: 22))
            }
            .buttonStyle(PlainButtonStyle())
            
            Image(uiImage: document.thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 50, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.appBorder, lineWidth: 1)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(document.name)
                    .font(.medium(16))
                    .foregroundColor(.appText)
                    .lineLimit(2)
                
                Text("\(document.type.rawValue.uppercased()) • \(formattedDate)")
                    .font(.regular(14))
                    .foregroundColor(.appSecondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.appSurface)
        .cornerRadius(12)
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: document.date)
    }
}

// MARK: - Document Order Cell
struct DocumentOrderCell: View {
    let document: DocumentDTO
    let position: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(position)")
                .font(.bold(16))
                .foregroundColor(.appPrimary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.appPrimary.opacity(0.1)))
            
            Image(uiImage: document.thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 50, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.appBorder, lineWidth: 1)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(document.name)
                    .font(.medium(16))
                    .foregroundColor(.appText)
                    .lineLimit(2)
                
                Text("\(document.type.rawValue.uppercased())")
                    .font(.regular(14))
                    .foregroundColor(.appSecondary)
            }
            
            Spacer()
            
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.appSecondary)
                .font(.system(size: 16))
        }
        .padding(16)
        .background(Color.appSurface)
        .cornerRadius(12)
    }
}

// MARK: - Draggable Document Cell
struct DraggableDocumentCell: View {
    let document: DocumentDTO
    let position: Int
    let totalCount: Int
    @Binding var draggedItem: DocumentDTO?
    @Binding var dragOffset: CGSize
    let onMove: (Int, Int) -> Void
    
    @State private var isDragging = false
    
    var body: some View {
        print("🔧 DraggableDocumentCell for: \(document.name), position: \(position), isDragging: \(isDragging)")
        return DocumentOrderCell(document: document, position: position)
            .scaleEffect(isDragging ? 1.05 : 1.0)
            .opacity(isDragging ? 0.8 : 1.0)
            .offset(draggedItem?.id == document.id ? dragOffset : .zero)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDragging)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isDragging {
                            print("🎯 Drag started for: \(document.name) (position \(position))")
                            isDragging = true
                            draggedItem = document
                            // Haptic feedback when drag starts
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                        }
                        dragOffset = value.translation
                        print("📍 Dragging: \(document.name), offset: \(dragOffset)")
                    }
                    .onEnded { value in
                        print("🏁 Drag ended for: \(document.name)")
                        print("📐 Final translation: \(value.translation)")
                        
                        isDragging = false
                        draggedItem = nil
                        dragOffset = .zero
                        
                        // Calculate if we should move the item
                        let dragDistance = value.translation.height
                        let cellHeight: CGFloat = 80 // Approximate cell height
                        let numberOfPositions = Int(round(dragDistance / cellHeight))
                        
                        print("📊 Drag analysis:")
                        print("  - Distance: \(dragDistance)")
                        print("  - Cell height: \(cellHeight)")
                        print("  - Positions to move: \(numberOfPositions)")
                        print("  - Current index: \(position - 1)")
                        print("  - Total count: \(totalCount)")
                        
                        if numberOfPositions != 0 {
                            let currentIndex = position - 1
                            let newIndex = max(0, min(currentIndex + numberOfPositions, totalCount - 1))
                            print("🎯 Calculated new index: \(newIndex)")
                            if newIndex != currentIndex {
                                print("✅ Will move from \(currentIndex) to \(newIndex)")
                                onMove(currentIndex, newIndex)
                                // Haptic feedback when item is moved
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            } else {
                                print("❌ No move: same index")
                            }
                        } else {
                            print("❌ No move: numberOfPositions = 0")
                        }
                    }
            )
    }
}

#Preview {
    MergeView()
        .environmentObject(Router())
        .environmentObject(PDFStorage())
}
