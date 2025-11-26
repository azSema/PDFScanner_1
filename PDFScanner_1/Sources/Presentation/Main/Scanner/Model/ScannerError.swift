import Foundation

enum ScannerError: LocalizedError {
    case deviceNotSupported
    case processingFailed
    case savingFailed
    
    var errorDescription: String? {
        switch self {
        case .deviceNotSupported: "Document scanning is not supported on this device"
        case .processingFailed: "Failed to process scanned images"
        case .savingFailed: "Failed to save scanned document"
        }
    }
}
