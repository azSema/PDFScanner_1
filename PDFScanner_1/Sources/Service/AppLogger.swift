import OSLog

final class DELogger {
    
    static func log(text: String) {
        logger.info("\(text)")
    }
    
    static private let logger = Logger(subsystem: "PDFScanner_1", category: "Actions")
    
}
