import SwiftUI
import Combine

final class PremiumManager: ObservableObject {
    @Published var isProcessing = false
    @Published var hasSubscription = false
    
    @Published var isShowingPaywall = false
    
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

extension PremiumManager {
    
    func canEdit() -> Bool {
        return hasSubscription
    }
    
    func canScan(currentScansNumber: Int) -> Bool {
        if hasSubscription {
            return true
        }
        let maxFreeScans = 3
        return currentScansNumber < maxFreeScans
    }
    
    func canMerge(currentMergesNumber: Int) -> Bool {
        if hasSubscription {
            return true
        }
        let maxFreeMerges = 2
        return currentMergesNumber < maxFreeMerges
    }
    
    func canConvert(currentConvertsNumber: Int) -> Bool {
        if hasSubscription {
            return true
        }
        let maxFreeConverts = 2
        return currentConvertsNumber < maxFreeConverts
    }
}

