import SwiftUI
import Combine

final class PremiumManager: ObservableObject {
    
    @Published var isProcessing = false
    
    @Published var hasSubscription = false
    
    func makePurchase() async {
        withAnimation { isProcessing = true }
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        await MainActor.run {
            withAnimation {
                isProcessing = false
                hasSubscription = true
            }
        }
    }
    
}

// MARK: - Features
extension PremiumManager {
    

    
}
