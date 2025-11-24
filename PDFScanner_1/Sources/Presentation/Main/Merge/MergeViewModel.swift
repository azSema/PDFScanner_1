import SwiftUI
import Combine

@MainActor
final class MergeViewModel: ObservableObject {
    
    // Published properties for UI binding
    @Published var currentState: MergeState = .idle
    @Published var selectedDocuments: Set<String> = []
    @Published var arrangedDocuments: [DocumentDTO] = []
    @Published var isProcessing: Bool = false
    @Published var draggedItem: DocumentDTO?
    @Published var dragOffset: CGSize = .zero
    
    // Merge service integration
    let mergeService = MergeService()
    
    // Router for navigation
    weak var router: Router?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupMergeBindings()
    }
    
    // MARK: - Actions
    
    func startMerge() {
        mergeService.startMergeFlow()
    }
    
    func toggleDocumentSelection(for documentId: String) {
        mergeService.toggleDocumentSelection(for: documentId)
    }
    
    func proceedToArrangeOrder(with documents: [DocumentDTO]) {
        mergeService.proceedToArrangeOrder(with: documents)
    }
    
    func moveDocument(from fromIndex: Int, to toIndex: Int) {
        mergeService.moveDocument(from: fromIndex, to: toIndex)
    }
    
    func startMergeProcess() {
        mergeService.startMergeProcess()
    }
    
    func cancelMerge() {
        mergeService.cancelMerge()
    }
    
    // MARK: - Computed Properties
    
    var canProceedToArrange: Bool {
        mergeService.canProceedToArrange
    }
    
    var canStartMerge: Bool {
        mergeService.canStartMerge
    }
    
    var isInSelectDocuments: Bool {
        if case .selectDocuments = currentState {
            return true
        }
        return false
    }
    
    var isInArrangeOrder: Bool {
        if case .arrangeOrder = currentState {
            return true
        }
        return false
    }
    
    var isInProcessing: Bool {
        if case .processing = currentState {
            return true
        }
        return false
    }
    
    // MARK: - Private Setup
    
    private func setupMergeBindings() {
        // Sync merge state
        mergeService.$state
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentState)
        
        // Sync selected documents
        mergeService.$selectedDocuments
            .receive(on: DispatchQueue.main)
            .assign(to: &$selectedDocuments)
        
        // Sync arranged documents
        mergeService.$arrangedDocuments
            .receive(on: DispatchQueue.main)
            .assign(to: &$arrangedDocuments)
        
        // Sync processing state
        mergeService.$isProcessing
            .receive(on: DispatchQueue.main)
            .assign(to: &$isProcessing)
        
        // Sync drag state
        mergeService.$draggedItem
            .receive(on: DispatchQueue.main)
            .assign(to: &$draggedItem)
        
        mergeService.$dragOffset
            .receive(on: DispatchQueue.main)
            .assign(to: &$dragOffset)
        
        // Handle state changes
        mergeService.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleMergeStateChange(state)
            }
            .store(in: &cancellables)
    }
    
    private func handleMergeStateChange(_ state: MergeState) {
        switch state {
        case .preview(let url):
            // Navigate to preview screen
            router?.push(.main(.mergePreview(url: url, arrangedDocuments: arrangedDocuments)))
            DELogger.log(text: "Successfully navigated to merge preview")
            
        case .completed:
            // Handle successful merge completion
            DELogger.log(text: "Successfully completed merge process")
            // Navigate back to dashboard or show success message
            
        case .error(let error):
            // Handle merge error
            DELogger.log(text: "Merge error: \(error.localizedDescription)")
            // TODO: Show error alert to user
            
        default:
            break
        }
    }
}