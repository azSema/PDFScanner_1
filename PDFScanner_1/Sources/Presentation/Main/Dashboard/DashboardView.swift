import SwiftUI
import FloatingButton
import UniformTypeIdentifiers

struct DashboardView: View {
    
    @StateObject private var viewModel = DashboardViewModel()
    @EnvironmentObject private var router: Router
    
    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection
                    mainScanButton
                    documentsSection
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 16)
            }
            .refreshable {
                viewModel.refreshData()
            }
            
            floatingButtonMenu
        }
        .onAppear {
            viewModel.loadRecentDocuments()
        }
        .fileImporter(
            isPresented: $viewModel.isShowingFileImporter,
            allowedContentTypes: viewModel.allowedContentTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                viewModel.handleImportedFiles(urls)
            case .failure(let error):
                print("File import error: \(error.localizedDescription)")
            }
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

// MARK: - UI Sections

extension DashboardView {
    
    // MARK: - Header Section
    
    private var headerSection: some View {
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
                // Settings action
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundStyle(.appTextSecondary)
            }
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Main Scan Button
    
    private var mainScanButton: some View {
        VStack(spacing: 16) {
            Button(action: {
                playHaptic(.medium)
                viewModel.startScanning()
            }) {
                HStack(spacing: 16) {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 32, weight: .medium))
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
            
            Button(action: {
                playHaptic(.light)
                viewModel.showFileImporter()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                    
                    Text("Or add manually")
                        .font(.medium(16))
                        .foregroundStyle(.white)
                        .underline()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .padding(.bottom, 32)
    }
    
    // MARK: - Documents Section
    
    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.recentDocuments.isEmpty {
                AppEmptyView(
                    title: "No Documents Yet",
                    subtitle: "Start scanning documents to see them here. Tap the scan button above to get started.",
                    imageName: "doc.text"
                )
                .padding(.top, 20)
            } else {
                Text("Recent Scans")
                    .font(.semiBold(20))
                    .foregroundStyle(.appText)
                
                RecentScansRow(
                    documents: viewModel.recentDocuments,
                    onDocumentTap: { document in
                        let documentId = UUID(uuidString: document.id) ?? UUID()
                        router.push(.main(.documentDetail(documentId: documentId)))
                    }
                )
            }
        }
        .padding(.bottom, 24)
    }
}

// MARK: - Floating Button Menu

extension DashboardView {
    
    private var floatingButtonMenu: some View {
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
    
    private var mainFloatingButton: AnyView {
        AnyView(
            Button(action: {
                playHaptic(.light)
                withAnimation(.spring(duration: 0.3)) {
                    viewModel.isFloatingMenuOpen.toggle()
                }
            }) {
                Image(systemName: viewModel.isFloatingMenuOpen ? "xmark" : "plus")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(viewModel.isFloatingMenuOpen ? 180 : 0))
                    .animation(.easeInOut(duration: 0.2), value: viewModel.isFloatingMenuOpen)
            }
            .frame(width: 56, height: 56)
            .background(.appPrimary)
            .clipShape(Circle())
            .shadow(color: .appPrimary.opacity(0.3), radius: 8, x: 0, y: 4)
        )
    }
    
    private var menuButtons: [AnyView] {
        [
            createMenuButton(icon: "arrow.triangle.2.circlepath", action: { router.push(.main(.converter)) }),
            createMenuButton(icon: "pencil.and.outline", action: { router.push(.main(.editor(documentId: UUID()))) }),
            createMenuButton(icon: "doc.on.doc", action: { router.push(.main(.merge)) }),
            createMenuButton(icon: "clock.arrow.circlepath", action: { router.push(.main(.history)) })
        ]
    }
    
    private func createMenuButton(icon: String, action: @escaping () -> Void) -> AnyView {
        AnyView(
            Button(action: {
                playHaptic(.medium)
                action()
                withAnimation(.spring(duration: 0.3)) {
                    viewModel.isFloatingMenuOpen = false
                }
            }) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
            }
            .frame(width: 48, height: 48)
            .background(.appSecondary)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Scanner Support Views

extension DashboardView {
    
    private var unsupportedDeviceView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
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
    
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .appPrimary))
                
                Text("Processing Images...")
                    .font(.medium(16))
                    .foregroundStyle(.white)
            }
            .padding(32)
            .background(.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview {
    NavigationStack {
        DashboardView()
            .environmentObject(Router())
    }
}
