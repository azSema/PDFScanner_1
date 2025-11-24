import Foundation
import UIKit
import Combine

struct SavedSignature: Identifiable, Codable {
    var id = UUID()
    let name: String
    let imageName: String  // Filename in documents directory
    let createdDate: Date
    let color: String      // Hex color
    
    init(name: String, imageName: String, color: String) {
        self.id = UUID()
        self.name = name
        self.imageName = imageName
        self.createdDate = Date()
        self.color = color
    }
}

@MainActor
final class SignatureStorage: ObservableObject {
    
    @Published var savedSignatures: [SavedSignature] = []
    
    private let userDefaults = UserDefaults.standard
    private let signaturesKey = "SavedSignatures"
    
    init() {
        loadSignatures()
    }
    
    // MARK: - Persistence
    
    func saveSignature(_ signature: UIImage, name: String, color: String) -> SavedSignature? {
        guard let data = signature.pngData(),
              let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let filename = "signature_\(UUID().uuidString).png"
        let fileURL = documentsDir.appendingPathComponent(filename)
        
        do {
            try data.write(to: fileURL)
            
            let savedSignature = SavedSignature(name: name, imageName: filename, color: color)
            savedSignatures.append(savedSignature)
            saveSignaturesToUserDefaults()
            
            return savedSignature
            
        } catch {
            print("Failed to save signature: \(error)")
            return nil
        }
    }
    
    func loadSignatureImage(_ signature: SavedSignature) -> UIImage? {
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let fileURL = documentsDir.appendingPathComponent(signature.imageName)
        return UIImage(contentsOfFile: fileURL.path)
    }
    
    func deleteSignature(_ signature: SavedSignature) {
        // Remove from array
        savedSignatures.removeAll { $0.id == signature.id }
        
        // Delete file
        if let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = documentsDir.appendingPathComponent(signature.imageName)
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        // Update UserDefaults
        saveSignaturesToUserDefaults()
    }
    
    // MARK: - Private Methods
    
    private func loadSignatures() {
        if let data = userDefaults.data(forKey: signaturesKey),
           let signatures = try? JSONDecoder().decode([SavedSignature].self, from: data) {
            savedSignatures = signatures
        }
    }
    
    private func saveSignaturesToUserDefaults() {
        if let data = try? JSONEncoder().encode(savedSignatures) {
            userDefaults.set(data, forKey: signaturesKey)
        }
    }
}