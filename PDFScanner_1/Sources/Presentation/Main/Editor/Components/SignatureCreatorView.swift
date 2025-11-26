import SwiftUI

struct SignatureCreatorView: View {
    
    let onSave: (UIImage) -> Void
    let onCancel: () -> Void
    
    @StateObject private var signatureService = SignatureService()
    @StateObject private var signatureStorage = SignatureStorage()
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingNameAlert = false
    @State private var signatureName = ""
    @State private var selectedTab = 0
    @State private var saveAndUseMode = false  // true for "Save & Use", false for "Save only"
    @State private var showingSavedAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Mode", selection: $selectedTab) {
                Text("Draw").tag(0)
                Text("Saved").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Content based on selected tab
            if selectedTab == 0 {
                drawingTabContent
            } else {
                savedSignaturesTabContent
            }
        }
        .navigationTitle("Signature")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    onCancel()
                }
                .foregroundColor(.appPrimary)
            }
            
            if selectedTab == 0 {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Use Signature") {
                            useCurrentSignature()
                        }
                        .disabled(!signatureService.hasSignature)
                        
                        Button("Save & Use") {
                            saveAndUseMode = true
                            showingNameAlert = true
                        }
                        .disabled(!signatureService.hasSignature)
                        
                        Button("Clear") {
                            signatureService.clearSignature()
                        }
                        .disabled(!signatureService.hasSignature)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.appPrimary)
                    }
                }
            }
        }
        .alert("Save Signature", isPresented: $showingNameAlert) {
            TextField("Signature name", text: $signatureName)
            Button("Cancel", role: .cancel) {
                signatureName = ""
                saveAndUseMode = false
            }
            Button(saveAndUseMode ? "Save & Use" : "Save") {
                if saveAndUseMode {
                    saveAndUseSignature()
                } else {
                    saveSignatureOnly()
                }
                saveAndUseMode = false
            }
            .disabled(signatureName.trim().isEmpty)
        } message: {
            Text(saveAndUseMode ? "Enter a name for this signature and use it immediately" : "Enter a name to save this signature for later use")
        }
        .alert("Signature Saved", isPresented: $showingSavedAlert) {
            Button("OK") { }
        } message: {
            Text("Your signature has been saved successfully and can be found in the Saved tab.")
        }
    }
    
    // MARK: - Drawing Tab Content
    
    private var drawingTabContent: some View {
        VStack(spacing: 20) {
            // Header
            headerView
            
            // Signature drawing area
            SignatureDrawingView(signatureService: signatureService)
                .frame(height: signatureService.maxHeight)
            
            // Color picker
            colorPickerSection
            
            Spacer()
            
            // Action buttons
            drawingActionButtons
        }
        .padding()
    }
    
    // MARK: - Saved Signatures Tab Content
    
    private var savedSignaturesTabContent: some View {
        VStack(spacing: 16) {
            if signatureStorage.savedSignatures.isEmpty {
                emptySignaturesView
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(signatureStorage.savedSignatures) { signature in
                            SavedSignatureCell(
                                signature: signature,
                                signatureStorage: signatureStorage,
                                onUse: { image in
                                    onSave(image)
                                },
                                onDelete: { sig in
                                    signatureStorage.deleteSignature(sig)
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    private var emptySignaturesView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "signature")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Saved Signatures")
                .font(.medium(18))
                .foregroundColor(.appText)
            
            Text("Create signatures in the Draw tab and save them for quick reuse")
                .font(.regular(14))
                .foregroundColor(.appSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("Draw your signature")
                .font(.medium(16))
                .foregroundColor(.appText)
            
            Text("Use your finger to draw your signature in the area below")
                .font(.regular(14))
                .foregroundColor(.appSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Color Picker Section
    
    private var colorPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Signature Color")
                .font(.medium(14))
                .foregroundColor(.appText)
            
            HStack(spacing: 12) {
                ForEach(signatureService.availableColors, id: \.self) { color in
                    Button(action: {
                        signatureService.updateColor(color)
                    }) {
                        Circle()
                            .fill(color)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .stroke(
                                        signatureService.selectedColor == color ?
                                        Color.appText : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                    }
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Drawing Action Buttons
    
    private var drawingActionButtons: some View {
        VStack(spacing: 12) {
            // Use Signature button
            Button("Use Signature") {
                useCurrentSignature()
            }
            .font(.medium(16))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(signatureService.hasSignature ? Color.appPrimary : Color.gray)
            .cornerRadius(12)
            .disabled(!signatureService.hasSignature)
            
            // Save Signature button
            Button("Save Signature") {
                saveAndUseMode = false
                showingNameAlert = true
            }
            .font(.medium(16))
            .foregroundColor(signatureService.hasSignature ? Color.appPrimary : Color.gray)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(signatureService.hasSignature ? Color.appPrimary : Color.gray, lineWidth: 1)
            )
            .disabled(!signatureService.hasSignature)
        }
    }
    
    // MARK: - Methods
    
    private func useCurrentSignature() {
        if let signatureImage = signatureService.generateSignatureImage() {
            onSave(signatureImage)
        }
    }
    
    private func saveAndUseSignature() {
        guard !signatureName.trim().isEmpty,
              let signatureImage = signatureService.generateSignatureImage() else { return }
        
        let colorHex = signatureService.selectedColor.toHex()
        
        if signatureStorage.saveSignature(signatureImage, name: signatureName.trim(), color: colorHex) != nil {
            // Только используем если была нажата кнопка "Save & Use" из меню
            onSave(signatureImage)
        }
        
        signatureName = ""
    }
    
    private func saveSignatureOnly() {
        guard !signatureName.trim().isEmpty,
              let signatureImage = signatureService.generateSignatureImage() else { return }
        
        let colorHex = signatureService.selectedColor.toHex()
        
        if signatureStorage.saveSignature(signatureImage, name: signatureName.trim(), color: colorHex) != nil {
            // Только сохраняем, не используем
            signatureName = ""
            // Показываем подтверждение
            showingSavedAlert = true
            // Переключаемся на вкладку Saved чтобы показать сохраненную подпись
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                selectedTab = 1
            }
        }
    }
}

// MARK: - Saved Signature Cell

struct SavedSignatureCell: View {
    
    let signature: SavedSignature
    let signatureStorage: SignatureStorage
    let onUse: (UIImage) -> Void
    let onDelete: (SavedSignature) -> Void
    
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Signature preview
            if let image = signatureStorage.loadSignatureImage(signature) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 60)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.appBorder, lineWidth: 1)
                    )
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 60)
                    .cornerRadius(8)
                    .overlay(
                        Text("Failed to load")
                            .font(.regular(12))
                            .foregroundColor(.appSecondary)
                    )
            }
            
            // Signature info
            VStack(spacing: 4) {
                Text(signature.name)
                    .font(.medium(14))
                    .foregroundColor(.appText)
                    .lineLimit(1)
                
                Text(signature.createdDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.regular(12))
                    .foregroundColor(.appSecondary)
            }
            
            // Action buttons
            HStack(spacing: 8) {
                Button("Use") {
                    if let image = signatureStorage.loadSignatureImage(signature) {
                        onUse(image)
                    }
                }
                .font(.medium(12))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(Color.appPrimary)
                .cornerRadius(8)
                
                Button {
                    showingDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
                .frame(width: 32, height: 32)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(12)
        .background(Color.appSurface)
        .cornerRadius(12)
        .alert("Delete Signature", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete(signature)
            }
        } message: {
            Text("Are you sure you want to delete '\(signature.name)'? This action cannot be undone.")
        }
    }
}

// MARK: - Extensions

extension String {
    func trim() -> String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension Color {
    func toHex() -> String {
        let components = UIColor(self).cgColor.components ?? [0, 0, 0, 1]
        let r = components[0]
        let g = components[1]
        let b = components[2]
        
        return String(format: "#%02lX%02lX%02lX", 
                     lroundf(Float(r * 255)), 
                     lroundf(Float(g * 255)), 
                     lroundf(Float(b * 255)))
    }
}

// MARK: - Signature Drawing View

struct SignatureDrawingView: View {
    
    @ObservedObject var signatureService: SignatureService
    @State private var drawingBounds: CGRect = .zero
    
    var body: some View {
        ZStack {
            // Background
            Color.appSurface
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.appBorder, lineWidth: 1)
                )
            
            // Content
            if signatureService.hasSignature {
                // Drawn signature
                SignatureShape(drawingPath: signatureService.drawingPath)
                    .stroke(
                        signatureService.selectedColor,
                        style: StrokeStyle(
                            lineWidth: signatureService.lineWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
            } else {
                // Placeholder
                VStack(spacing: 8) {
                    Image(systemName: "signature")
                        .font(.system(size: 32))
                        .foregroundColor(.appSecondary.opacity(0.5))
                    
                    Text("Draw your signature here")
                        .font(.regular(16))
                        .foregroundColor(.appSecondary.opacity(0.7))
                }
            }
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        drawingBounds = geometry.frame(in: .local)
                    }
                    .onChange(of: geometry.frame(in: .local)) { bounds in
                        drawingBounds = bounds
                    }
            }
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    if signatureService.isDrawing {
                        signatureService.continueDrawing(to: value.location, in: drawingBounds)
                    } else {
                        signatureService.startDrawing(at: value.location, in: drawingBounds)
                    }
                }
                .onEnded { _ in
                    signatureService.endDrawing()
                }
        )
        .animation(.easeInOut(duration: 0.2), value: signatureService.hasSignature)
    }
}

// MARK: - Signature Shape

struct SignatureShape: Shape {
    let drawingPath: DrawingPath
    
    func path(in rect: CGRect) -> Path {
        drawingPath.swiftUIPath
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        SignatureCreatorView(
            onSave: { image in
                print("Signature saved with size: \(image.size)")
            },
            onCancel: {
                print("Signature creation cancelled")
            }
        )
    }
}