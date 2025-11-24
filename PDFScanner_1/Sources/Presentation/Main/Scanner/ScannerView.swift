import SwiftUI
import VisionKit

struct ScannerView: View {
    
    let mode: ScanMode
    @EnvironmentObject private var router: Router
    @StateObject private var viewModel: ScannerViewModel
    
    init(mode: ScanMode) {
        self.mode = mode
        self._viewModel = StateObject(wrappedValue: ScannerViewModel(mode: mode))
    }
    
    var body: some View {
        VStack(spacing: 24) {
            headerSection
            
            if viewModel.scannedImages.isEmpty {
                emptyStateSection
            } else {
                scannedImagesSection
            }
            
            Spacer()
            
            actionButtonsSection
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Scanner")
        .sheet(isPresented: $viewModel.isShowingScanner) {
            if VNDocumentCameraViewController.isSupported {
                DocumentCameraScannerView(
                    onScanCompleted: viewModel.handleScanCompleted,
                    onScanCancelled: viewModel.handleScanCancelled,
                    onScanError: viewModel.handleScanError
                )
            } else {
                unsupportedDeviceView
            }
        }
        .overlay {
            if viewModel.isProcessing {
                processingOverlay
            }
        }
        .onAppear {
            if VNDocumentCameraViewController.isSupported {
                viewModel.startScanning()
            }
        }
    }
}

// MARK: - UI Sections

extension ScannerView {
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Document Scanner")
                .font(.bold(28))
                .foregroundStyle(.appText)
            
            Text("Mode: \(mode.displayName)")
                .font(.medium(16))
                .foregroundStyle(.appTextSecondary)
        }
    }
    
    private var emptyStateSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 80))
                .foregroundStyle(.appPrimary)
            
            VStack(spacing: 8) {
                Text("Ready to Scan")
                    .font(.bold(24))
                    .foregroundStyle(.appText)
                
                Text("Position your document and tap the scan button")
                    .font(.regular(16))
                    .foregroundStyle(.appTextSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var scannedImagesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Scanned Pages")
                    .font(.bold(20))
                    .foregroundStyle(.appText)
                
                Spacer()
                
                Text("\(viewModel.scannedImages.count) pages")
                    .font(.medium(14))
                    .foregroundStyle(.appTextSecondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(viewModel.scannedImages.enumerated()), id: \.offset) { index, image in
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 160)
                            .background(.appSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(.appBorder, lineWidth: 1)
                            )
                            .overlay(
                                VStack {
                                    HStack {
                                        Spacer()
                                        Text("\(index + 1)")
                                            .font(.caption2)
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(.black.opacity(0.7))
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                    Spacer()
                                }
                                .padding(8)
                            )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            if !viewModel.scannedImages.isEmpty {
                HStack(spacing: 16) {
                    Button(action: {
                        viewModel.clearScannedImages()
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear")
                        }
                        .font(.medium(16))
                        .foregroundStyle(.appText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.appBorder, lineWidth: 1)
                        )
                    }
                    
                    Button(action: {
                        viewModel.startScanning()
                    }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add More")
                        }
                        .font(.medium(16))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.appPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                
                Button(action: {
                    // TODO: Save/Process scanned documents
                    router.popToRoot()
                }) {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Save Document")
                    }
                    .font(.bold(16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.appSuccess)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                Button(action: {
                    viewModel.startScanning()
                }) {
                    HStack {
                        Image(systemName: "doc.text.viewfinder")
                        Text("Start Scanning")
                    }
                    .font(.bold(16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.appPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            Button("Back to Dashboard") {
                router.popToRoot()
            }
            .font(.medium(14))
            .foregroundStyle(.appTextSecondary)
        }
    }
    
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

extension ScanMode {
    var displayName: String {
        switch self {
        case .single: return "Single Page"
        case .multi: return "Multi Page"
        case .batch: return "Batch Scan"
        }
    }
}

#Preview {
    NavigationStack {
        ScannerView(mode: .single)
            .environmentObject(Router())
    }
}