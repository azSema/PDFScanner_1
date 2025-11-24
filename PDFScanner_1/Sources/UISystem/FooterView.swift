import SwiftUI

struct FooterView: View {
    
    @State private var isShowingPrivacy = false
    @State private var isShowingTerms = false
    
    let color: Color
    let font: Font
    let isUnderlined: Bool
    
    let onRestore: () -> ()
    
    init(color: Color = .black,
         font: Font = .regular(12),
         isUnderlined: Bool = false,
         onRestore: @escaping () -> Void) {
        self.color = color
        self.font = font
        self.isUnderlined = isUnderlined
        self.onRestore = onRestore
    }
    
    var body: some View {
        HStack(spacing: 8) {
            buttonItem(title: "Terms of Use", action: {
                isShowingTerms.toggle()
            })
            Divider()
                .frame(height: 12)

            buttonItem(title: "Privacy Policy", action: {
                isShowingPrivacy.toggle()
            })
            Divider()
                .frame(height: 12)
            buttonItem(title: "Restore", action: {
                onRestore()
            })
        }
        .sheet(isPresented: $isShowingTerms) {
            Text("Terms of Use")
        }
        .sheet(isPresented: $isShowingPrivacy) {
            Text("Privacy & Policy")
        }
    }
    
    private func buttonItem(title: String,
                            action: @escaping () -> ()) -> some View {
        Button {
            action()
        } label: {
            Text(title)
                .underline(isUnderlined)
                .font(font)
                .foregroundStyle(color)
        }
        
    }

}
