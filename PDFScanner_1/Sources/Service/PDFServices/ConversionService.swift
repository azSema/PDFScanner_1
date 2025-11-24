import Foundation
import UIKit
import PDFKit
import Combine

// MARK: - Conversion Types & Errors

enum ConversionType: CaseIterable {
    case pdfToImages
    
    var title: String {
        switch self {
        case .pdfToImages: return "PDF to Images"
        }
    }
    
    var icon: String {
        switch self {
        case .pdfToImages: return "photo.on.rectangle"
        }
    }
    
    var description: String {
        switch self {
        case .pdfToImages: return "Extract PDF pages as optimized JPG images"
        }
    }
}

enum ConversionState {
    case idle
    case selectingDocument
    case processing
    case completed([URL])
    case failed(Error)
}

enum ConversionError: Error, LocalizedError {
    case invalidInput
    case failedToConvert
    case noDocumentSelected
    case unsupportedFormat
    
    var errorDescription: String? {
        switch self {
        case .invalidInput: return "Invalid PDF document"
        case .failedToConvert: return "Failed to convert PDF pages"
        case .noDocumentSelected: return "No document selected"
        case .unsupportedFormat: return "Unsupported file format"
        }
    }
}

// MARK: - Conversion Service

@MainActor
final class ConversionService: ObservableObject {
    
    @Published var state: ConversionState = .idle
    @Published var selectedDocument: DocumentDTO?
    
    var isProcessing: Bool {
        if case .processing = state { return true }
        return false
    }
    
    var canStartConversion: Bool {
        return selectedDocument != nil
    }
    
    // MARK: - Public Methods
    
    func selectDocument(_ document: DocumentDTO) {
        selectedDocument = document
        state = .processing
        Task {
            await convertPDFToImages()
        }
    }
    
    func reset() {
        state = .idle
        selectedDocument = nil
    }
    
    // MARK: - Private Methods
    
    private func convertPDFToImages() async {
        guard let document = selectedDocument,
              let pdfURL = document.url else {
            state = .failed(ConversionError.noDocumentSelected)
            return
        }
        
        do {
            let converter = Converter()
            let imageURLs = try await converter.convertPDFToJPG(pdfURL: pdfURL, dpi: 300.0)
            state = .completed(imageURLs)
        } catch {
            state = .failed(error)
        }
    }
}

// MARK: - Converter Implementation

final class Converter {
    
    // MARK: - PDF to JPG
    func convertPDFToJPG(pdfURL: URL, dpi: CGFloat = 150.0) async throws -> [URL] {
        try await performAsync {
            guard let pdfDoc = PDFDocument(url: pdfURL) else {
                throw ConversionError.invalidInput
            }
            
            var outputURLs = [URL]()
            
            for i in 0..<pdfDoc.pageCount {
                // Use autoreleasepool to release memory immediately after each page
                try autoreleasepool {
                    guard let page = pdfDoc.page(at: i) else { return }
                    
                    let pageRect = page.bounds(for: .mediaBox)
                    let scale = dpi / 72.0
                    
                    // Limit maximum size to prevent memory issues
                    let maxDimension: CGFloat = 2048
                    let actualScale = min(scale, min(maxDimension / pageRect.width, maxDimension / pageRect.height))
                    
                    let size = CGSize(
                        width: pageRect.width * actualScale,
                        height: pageRect.height * actualScale
                    )
                    
                    UIGraphicsBeginImageContextWithOptions(size, false, 0)
                    defer { UIGraphicsEndImageContext() }
                    
                    guard let context = UIGraphicsGetCurrentContext() else { return }
                    
                    context.saveGState()
                    context.translateBy(x: 0.0, y: size.height)
                    context.scaleBy(x: 1.0, y: -1.0)
                    context.scaleBy(x: actualScale, y: actualScale)
                    page.draw(with: .mediaBox, to: context)
                    context.restoreGState()
                    
                    if let image = UIGraphicsGetImageFromCurrentImageContext(),
                       let imageData = image.jpegData(compressionQuality: 0.7) {
                        let filename = "page_\(i + 1)_\(UUID().uuidString.prefix(8)).jpg"
                        let outputURL = self.tempFileURL(filename: filename)
                        try imageData.write(to: outputURL)
                        outputURLs.append(outputURL)
                    }
                }
            }
            
            return outputURLs
        }
    }
    
    // MARK: - Helpers
    private func tempFileURL(filename: String) -> URL {
        // Use Documents directory instead of tmp for better iOS sharing compatibility
        let documentsPath = FileManager.default.urls(for: .documentDirectory, 
                                                    in: .userDomainMask)[0]
        let tempDir = documentsPath.appendingPathComponent("ConvertedImages", isDirectory: true)
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: tempDir, 
                                                withIntermediateDirectories: true, 
                                                attributes: nil)
        
        return tempDir.appendingPathComponent(filename)
    }
    
    private func performAsync<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try work()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}