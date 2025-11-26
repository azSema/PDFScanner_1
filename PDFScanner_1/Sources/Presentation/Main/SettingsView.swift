import SwiftUI
import MessageUI

struct SettingsView: View {
    
    // MARK: - Constants
    private let appID = "123456789" // TODO: Replace with real App Store ID
    private let supportEmail = "support@pdfscanner.app" // TODO: Replace with real email
    
    @State private var isShowingMailComposer = false
    @State private var isShowingPrivacyPolicy = false
    @State private var isShowingTermsOfUse = false
    @State private var isShowingEmailAlert = false
    @State private var canSendMail = false
    
    @EnvironmentObject var premium: PremiumManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // MARK: - App Icon and Title
                VStack(spacing: 12) {
                    Image(systemName: "doc.viewfinder.fill")
                        .font(.system(size: 60, weight: .medium))
                        .foregroundColor(.appPrimary)
                    
                    Text("PDF Scanner")
                        .font(.title)
                        .fontWeight(.semibold)
                    
                    Text("Version \(appVersion)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                if !premium.hasSubscription {
                    ProBanner()
                        .padding(.horizontal, -18)
                        .padding(.bottom, -16)
                }
                
                // MARK: - Settings List
                VStack(spacing: 1) {
                    
                    SettingsRow(
                        icon: "star.fill",
                        title: "Rate App",
                        iconColor: .orange
                    ) {
                        rateApp()
                    }
                    
                    SettingsRow(
                        icon: "square.and.arrow.up",
                        title: "Share App",
                        iconColor: .blue
                    ) {
                        shareApp()
                    }
                    
                    SettingsRow(
                        icon: "envelope.fill",
                        title: "Contact Us",
                        iconColor: .green
                    ) {
                        contactUs()
                    }
                    
                    SettingsRow(
                        icon: "doc.text.fill",
                        title: "Privacy Policy",
                        iconColor: .purple
                    ) {
                        isShowingPrivacyPolicy = true
                    }
                    
                    SettingsRow(
                        icon: "doc.plaintext.fill",
                        title: "Terms of Use",
                        iconColor: .red
                    ) {
                        isShowingTermsOfUse = true
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $isShowingPrivacyPolicy) {
            PolicyView(title: "Privacy Policy", content: privacyPolicyText)
        }
        .sheet(isPresented: $isShowingTermsOfUse) {
            PolicyView(title: "Terms of Use", content: termsOfUseText)
        }
        .sheet(isPresented: $isShowingMailComposer) {
            MailComposeView(
                subject: "PDF Scanner Support",
                recipients: [supportEmail],
                messageBody: "Hello PDF Scanner Team,\n\n"
            )
        }
        .alert("Email Not Available", isPresented: $isShowingEmailAlert) {
            Button("OK") { }
            Button("Copy Email") {
                UIPasteboard.general.string = supportEmail
            }
        } message: {
            Text("Please email us at \(supportEmail)")
        }
        .onAppear {
            canSendMail = MFMailComposeViewController.canSendMail()
        }
    }
    
    // MARK: - Actions
    
    private func rateApp() {
        if let url = URL(string: "https://apps.apple.com/app/id\(appID)?action=write-review") {
            UIApplication.shared.open(url)
        }
    }
    
    private func shareApp() {
        if let url = URL(string: "https://apps.apple.com/app/id\(appID)") {
            let activityViewController = UIActivityViewController(
                activityItems: [url],
                applicationActivities: nil
            )
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.present(activityViewController, animated: true)
            }
        }
    }
    
    private func contactUs() {
        if canSendMail {
            isShowingMailComposer = true
        } else {
            isShowingEmailAlert = true
        }
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    // MARK: - Text Content
    
    private var privacyPolicyText: String {
        """
        Privacy Policy
        
        Last updated: [Date]
        
        Your privacy is important to us. This privacy policy explains how our PDF Scanner app collects, uses, and protects your information.
        
        Information Collection:
        • We do not collect personal information
        • Documents are processed locally on your device
        • No data is transmitted to external servers
        
        Data Usage:
        • All PDF processing happens on your device
        • Documents remain private and secure
        • We do not access or store your documents
        
        Security:
        • Your documents are stored locally
        • No cloud synchronization without your consent
        • App uses standard iOS security protocols
        
        Contact:
        If you have questions about this privacy policy, please contact us at \(supportEmail)
        """
    }
    
    private var termsOfUseText: String {
        """
        Terms of Use
        
        Last updated: [Date]
        
        By using PDF Scanner, you agree to these terms.
        
        License:
        • Personal and commercial use permitted
        • Do not redistribute or modify the app
        • Respect intellectual property rights
        
        Usage:
        • Use the app responsibly and legally
        • Do not process illegal or harmful content
        • Respect others' privacy and rights
        
        Limitation of Liability:
        • The app is provided "as is"
        • We are not liable for data loss
        • Users are responsible for backing up documents
        
        Changes:
        We may update these terms. Continued use indicates acceptance of new terms.
        
        Contact:
        Questions about these terms? Contact us at \(supportEmail)
        """
    }
}

// MARK: - Supporting Views

struct SettingsRow: View {
    let icon: String
    let title: String
    let iconColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.clear)
        }
        .buttonStyle(.plain)
    }
}

struct PolicyView: View {
    let title: String
    let content: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text(content)
                    .font(.system(size: 14))
                    .padding(20)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct MailComposeView: UIViewControllerRepresentable {
    let subject: String
    let recipients: [String]
    let messageBody: String
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setSubject(subject)
        composer.setToRecipients(recipients)
        composer.setMessageBody(messageBody, isHTML: false)
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposeView
        
        init(_ parent: MailComposeView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.dismiss()
        }
    }
}

#Preview {
    NavigationView {
        SettingsView()
    }
}
