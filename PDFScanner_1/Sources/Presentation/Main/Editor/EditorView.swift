import SwiftUI
import PhotosUI
import PDFKit
import UniformTypeIdentifiers

/// Экран редактирования PDF-документа с поддержкой аннотаций, подписей и изображений
struct EditorView: View {
    let documentId: UUID
    
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var pdfStorage: PDFStorage
    @StateObject private var editService = EditService()
    
    @State private var selectedPhotosPickerItems: [PhotosPickerItem] = []
    
    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            if editService.pdfDocument != nil {
                documentEditorView
            } else {
                loadingOrErrorView
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            toolbarContent
        }
        .onAppear {
            editService.configure(documentId: documentId, pdfStorage: pdfStorage)
        }
        .background {
            modifiers
        }
    }
}

// MARK: - Main Content Views

private extension EditorView {
    
    /// Основной view редактора с PDF и overlay'ями
    var documentEditorView: some View {
        VStack(spacing: 0) {
            if editService.isToolbarVisible {
                pageIndicatorView
            }
            
            Spacer()
            
            pdfEditorWithOverlays
            
            Spacer()
            
            if editService.showingHighlightPanel {
                HighlightPanel(editService: editService)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            if editService.isToolbarVisible {
                EditorToolbar(editService: editService)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    /// PDF редактор с overlay'ями для подписей и изображений
    var pdfEditorWithOverlays: some View {
        GeometryReader { geometry in
            ZStack {
                PDFEditorView(editService: editService)
                    .onReceive(editService.$insertionPoint) { point in
                        handleInsertionPoint(point, geometry: geometry)
                    }
                
                if let signatureAnnotation = editService.activeSignatureOverlay {
                    signatureOverlayView(annotation: signatureAnnotation, geometry: geometry)
                }
                
                if let imageAnnotation = editService.activeImageOverlay {
                    imageOverlayView(annotation: imageAnnotation, geometry: geometry)
                }
            }
        }
        .pdfDocumentFrame(
            pageRect: editService.currentPage?.bounds(for: .mediaBox) ?? CGRect(x: 0, y: 0, width: 595, height: 842),
            rotation: Int(editService.currentPage?.rotation ?? 0),
            maxRatio: 0.7
        )
    }
    
    /// View состояния загрузки или ошибки
    var loadingOrErrorView: some View {
        VStack(spacing: 16) {
            if editService.isProcessing {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.appPrimary)
                
                Text("Loading document...")
                    .font(.medium(16))
                    .foregroundColor(.appSecondary)
            } else {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.appSecondary.opacity(0.5))
                
                Text("Document not found")
                    .font(.medium(18))
                    .foregroundColor(.appText)
                
                Text("The selected document could not be loaded")
                    .font(.regular(14))
                    .foregroundColor(.appSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    /// Индикатор текущей страницы
    var pageIndicatorView: some View {
        HStack {
            Spacer()
            PageIndicator(editService: editService)
            Spacer()
        }
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Overlay Views

private extension EditorView {
    
    /// Overlay для подписи с инструкциями
    func signatureOverlayView(
        annotation: IdentifiablePDFAnnotation,
        geometry: GeometryProxy
    ) -> some View {
        ZStack {
            SignatureOverlay(
                editService: editService,
                annotation: Binding<IdentifiablePDFAnnotation>(
                    get: { editService.activeSignatureOverlay ?? annotation },
                    set: { editService.activeSignatureOverlay = $0 }
                ),
                geometry: geometry
            )
            .onTapGesture(count: 2) {
                DELogger.log(text: "Double tap - finalizing signature")
                editService.finalizeSignatureOverlay()
            }
            
            overlayInstructionView(
                title: "Position your signature",
                onDone: editService.finalizeSignatureOverlay
            )
        }
    }
    
    /// Overlay для изображения с инструкциями
    func imageOverlayView(
        annotation: IdentifiablePDFAnnotation,
        geometry: GeometryProxy
    ) -> some View {
        ZStack {
            ImageOverlay(
                editService: editService,
                annotation: Binding<IdentifiablePDFAnnotation>(
                    get: { editService.activeImageOverlay ?? annotation },
                    set: { editService.activeImageOverlay = $0 }
                ),
                geometry: geometry
            )
            .onTapGesture(count: 2) {
                DELogger.log(text: "Double tap - finalizing image")
                editService.finalizeImageOverlay()
            }
            
            overlayInstructionView(
                title: "Position your image",
                onDone: editService.finalizeImageOverlay
            )
        }
    }
    
    /// Переиспользуемый компонент инструкций для overlay
    func overlayInstructionView(title: String, onDone: @escaping () -> Void) -> some View {
        VStack {
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    Text(title)
                        .font(.medium(14))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                    
                    Button("Done", action: onDone)
                        .font(.medium(14))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.appPrimary)
                        .cornerRadius(8)
                }
                .padding(.top, 20)
                .padding(.trailing, 16)
                Spacer()
            }
            Spacer()
        }
    }
}

// MARK: - Toolbar

private extension EditorView {
    
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            backButton
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            trailingToolbarButtons
        }
    }
    
    var backButton: some View {
        Button {
            handleBackButtonTap()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.medium(16))
                Text("Back")
                    .font(.medium(16))
            }
            .foregroundColor(.appPrimary)
        }
    }
    
    var trailingToolbarButtons: some View {
        HStack(spacing: 12) {
            toggleToolbarButton
            
            if editService.hasUnsavedChanges {
                saveButton
            }
        }
    }
    
    var toggleToolbarButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                editService.isToolbarVisible.toggle()
            }
        } label: {
            Image(systemName: editService.isToolbarVisible ? "eye.slash" : "eye")
                .font(.medium(16))
                .foregroundColor(.appText)
        }
    }
    
    var saveButton: some View {
        Button("Save") {
            Task {
                await handleSave()
            }
        }
        .font(.medium(16))
        .foregroundColor(.appPrimary)
        .disabled(editService.isProcessing)
    }
}

// MARK: - View Modifiers

private extension EditorView {
    
    var modifiers: some View {
        EmptyView()
            .photosPicker(
                isPresented: $editService.showingImagePicker,
                selection: $selectedPhotosPickerItems,
                maxSelectionCount: 1,
                matching: .images
            )
            .onChange(of: selectedPhotosPickerItems) { newItems in
                handlePhotosPickerSelection(newItems)
            }
            .sheet(isPresented: $editService.showingSignatureCreator) {
                SignatureCreatorView(
                    onSave: { signature in
                        editService.saveSignature(signature)
                    },
                    onCancel: {
                        editService.resetSignatureService()
                        editService.showingSignatureCreator = false
                    }
                )
            }
            .fileImporter(
                isPresented: $editService.showingFileImporter,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .animation(.easeInOut(duration: 0.3), value: editService.showingHighlightPanel)
            .animation(.easeInOut(duration: 0.3), value: editService.isToolbarVisible)
    }
}

// MARK: - Actions

private extension EditorView {
    
    /// Обработка точки вставки для изображений
    func handleInsertionPoint(_ point: CGPoint, geometry: GeometryProxy) {
        if editService.showingImageInsertMode && point != .zero {
            editService.insertionGeometry = geometry.size
            editService.updateImageOverlayPosition(to: point, geometrySize: geometry.size)
        }
    }
    
    /// Обработка выбора изображений из PhotosPicker
    func handlePhotosPickerSelection(_ items: [PhotosPickerItem]) {
        guard let item = items.first else { return }
        
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    editService.createImageOverlay(with: image)
                    editService.showingImagePicker = false
                    editService.showingImageInsertMode = true
                    selectedPhotosPickerItems = []
                }
            }
        }
    }
    
    /// Обработка импорта PDF файлов
    func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                
                if let data = try? Data(contentsOf: url) {
                    editService.addPageToDocument(from: data)
                }
            }
            
        case .failure(let error):
            DELogger.log(text: "File import error: \(error.localizedDescription)")
        }
    }
    
    /// Обработка нажатия кнопки "Назад"
    func handleBackButtonTap() {
        if editService.hasUnsavedChanges {
            showUnsavedChangesAlert()
        } else {
            router.pop()
        }
    }
    
    /// Сохранение изменений
    func handleSave() async {
        do {
            try await editService.saveChanges()
            DELogger.log(text: "Document saved successfully")
        } catch {
            DELogger.log(text: "Save error: \(error.localizedDescription)")
        }
    }
    
    /// Показ алерта о несохраненных изменениях
    func showUnsavedChangesAlert() {
        // TODO: Реализовать алерт с подтверждением
        // Пока просто возвращаемся назад
        router.pop()
    }
}
