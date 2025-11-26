import UIKit

enum ScannerState {
    case idle
    case scanning
    case processing
    case completed(DocumentDTO)
    case error(Error)
}
