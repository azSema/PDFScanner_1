import SwiftUI
import FloatingButton

/// Главный экран с недавними документами и быстрыми действиями
struct DashboardView: View {
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var pdfStorage: PDFStorage
    
    @StateObject private var viewModel = DashboardViewModel()
    @StateObject private var actionsManager = DocumentActionsManager()
    
    var body: some View {
        ZStack {
            backgroundColor
            
            VStack {
                headerSection
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        mainScanButton
                        documentsSection
                    }
                }
            }
            
            floatingButtonMenu
        }
        .onAppear {
            actionsManager.configure(with: pdfStorage, router: router)
            viewModel.configure(pdfStorage: pdfStorage)
        }
        .background {
            DocumentActionsView(actionsManager: actionsManager)
        }
        .fileImporter(
            isPresented: $viewModel.isShowingFileImporter,
            allowedContentTypes: viewModel.allowedContentTypes,
            allowsMultipleSelection: true
        ) { result in
            viewModel.processImportResult(result)
        }
        .sheet(isPresented: $viewModel.isShowingScanner) {
            if viewModel.isScannerSupported {
                DocumentCameraScannerView(
                    onScanCompleted: viewModel.handleScanCompleted,
                    onScanCancelled: viewModel.handleScanCancelled,
                    onScanError: viewModel.handleScanError
                )
                .ignoresSafeArea()
            } else {
                unsupportedDeviceView
            }
        }
        .overlay {
            if viewModel.isProcessingScanner {
                processingOverlay
            }
        }
    }
}

// дальше UI-секции без изменений

// MARK: - UI Sections

private extension DashboardView {
    
    // MARK: Background Color
    
    var backgroundColor: some View {
        Color.appBackground
            .ignoresSafeArea()
    }
    
    // MARK: Header Section
    
    var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("PDF Scanner")
                    .font(.bold(28))
                    .foregroundStyle(.appText)
                
                Text("Scan, Edit & Convert")
                    .font(.medium(16))
                    .foregroundStyle(.appTextSecondary)
            }
            
            Spacer()
            
            Button {
                // TODO: Реализовать флоу настроек
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundStyle(.appTextSecondary)
            }
        }
        .padding(20)
    }
    
    // MARK: Main Scan Button
    
    var mainScanButton: some View {
        VStack(spacing: 16) {
            Button {
                HapticService.shared.impact(.medium)
                viewModel.startScanning()
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.medium(32))
                        .foregroundStyle(.white)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Start Scanning")
                            .font(.bold(22))
                            .foregroundStyle(.white)
                        
                        Text("Scan documents instantly")
                            .font(.medium(14))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
                .padding(20)
                .background(.appPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .appPrimary.opacity(0.3), radius: 12, x: 0, y: 8)
            }
            
            Button {
                HapticService.shared.impact(.light)
                viewModel.isShowingFileImporter = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                    Text("Or add manually")
                        .underline()
                }
                .font(.medium(16))
                .foregroundStyle(.appText)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .padding(.bottom, 32)
        .padding(.horizontal, 16)
    }
    
    // MARK: Documents Section
    @ViewBuilder
    var documentsSection: some View {
        if pdfStorage.documents.isEmpty {
            AppEmptyView(
                title: "No Documents Yet",
                subtitle: "Start scanning documents to see them here. Tap the scan button above to get started."
            )
        } else {
            VStack(alignment: .leading, spacing: 16) {
                Text("Recent Scans")
                    .font(.semiBold(20))
                    .foregroundStyle(.appText)
                    .padding(.horizontal, 20)
                
                RecentScansRow(
                    documents: pdfStorage.documents,
                    onDocumentTap: { document in
                        actionsManager.showActionSheet(for: document)
                    },
                    actionsManager: actionsManager
                )
            }
        }
    }
}

// MARK: - Floating Button Menu

private extension DashboardView {
    var floatingButtonMenu: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                FloatingButton(
                    mainButtonView: mainFloatingButton,
                    buttons: menuButtons,
                    isOpen: $viewModel.isFloatingMenuOpen
                )
                .circle()
                .startAngle(.pi)
                .endAngle(3 * .pi / 2)
                .radius(110)
                .layoutDirection(.clockwise)
                .animation(.spring(duration: 0.4))
                .padding(.trailing, 16)
                .padding(.bottom, 32)
            }
        }
    }
    
    var mainFloatingButton: some View {
        Button {
            HapticService.shared.impact(.light)
            viewModel.isFloatingMenuOpen.toggle()
        } label: {
            Image(systemName: viewModel.isFloatingMenuOpen ? "xmark" : "plus")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
        .frame(width: 56, height: 56)
        .background(.appPrimary)
        .clipShape(.circle)
        .shadow(color: .appPrimary.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    var menuButtons: [some View] {
        [
            createMenuButton(icon: "arrow.triangle.2.circlepath") {
                router.push(.main(.converter))
            },
            createMenuButton(icon: "pencil.and.outline") {
                router.push(.main(.documentSelection(destination: .editor)))
            },
            createMenuButton(icon: "doc.on.doc") {
                router.push(.main(.merge))
            },
            createMenuButton(icon: "clock.arrow.circlepath") {
                router.push(.main(.history))
            }
        ]
    }
    
    func createMenuButton(icon: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticService.shared.impact(.medium)
            action()
            withAnimation(.spring(duration: 0.3)) {
                viewModel.isFloatingMenuOpen = false
            }
        } label: {
            Image(systemName: icon)
                .font(.medium(20))
                .foregroundStyle(.white)
        }
        .frame(width: 48, height: 48)
        .background(.appSecondary)
        .clipShape(.circle)
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Scanner Support Views

extension DashboardView {
    var unsupportedDeviceView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.regular(60))
                .foregroundStyle(.appWarning)
            
            Text("Scanner Not Available")
                .font(.bold(20))
                .foregroundStyle(.appText)
            
            Text("Document scanning is not supported on this device")
                .font(.regular(16))
                .foregroundStyle(.appTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .background(.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 32)
    }
    
    var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .appPrimary))
                .padding(32)
                .background(.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
