import SwiftUI

struct ContentView: View {
    
    @StateObject private var router: Router = .init()
    @StateObject private var premium: PremiumManager = .init()
    @StateObject private var pdfStorage: PDFStorage = .init()
    
    var body: some View {
        Group {
            if router.isOnboarding {
                OnboardingFlow()
            } else {
                MainFlow()
            }
        }
        .overlay(content: {
            if premium.isShowingPaywall {
                PaywallView()
            }
        })
        .overlay {
            if premium.isProcessing {
                AppLoaderView()
            }
        }
        .animation(.easeInOut, value: premium.isProcessing)
        .environmentObject(router)
        .environmentObject(premium)
        .environmentObject(pdfStorage)
    }
}
