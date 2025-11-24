import SwiftUI

func playHaptic(_ feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle) {
    UIImpactFeedbackGenerator(style: feedbackStyle).impactOccurred()
}

extension View {
    
    func pdfDocumentFrame(pageRect: CGRect,
                          rotation: Int,
                          maxRatio: CGFloat = 0) -> some View {
        let aspectRatio = (rotation == 90 || rotation == 270) ?
        pageRect.height / pageRect.width :
        pageRect.width / pageRect.height
        return self.frame(width: UIScreen.main.bounds.width - 32,
                          height: (UIScreen.main.bounds.width - 32) / max(aspectRatio, maxRatio))
    }
    
    func hideKeyboard() {
          UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
      }
    
    func dismissSheet(isPresented: Binding<Bool>) -> some View {
        self.onDisappear {
            isPresented.wrappedValue = false
        }
    }
    
    @ViewBuilder
    func conditionalScrollView(isFocused: Bool) -> some View {
        if isFocused {
            ScrollView(showsIndicators: false) {
                self
            }
        } else {
            self
        }
    }
    
    func snapshot() -> UIImage {
        let controller = UIHostingController(rootView: self)
        let view = controller.view
        
        let targetSize = controller.view.intrinsicContentSize
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .clear
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        
        return renderer.image { _ in
            view?.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
    
    func onRotate(perform action: @escaping (UIDeviceOrientation) -> Void) -> some View {
        self.modifier(RotationModifier(action: action))
    }
    
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
    
    func disableScrollBounce() -> some View {
        self.modifier(ScrollDebounceModifier())
    }
    
}

struct ScrollDebounceModifier: ViewModifier {
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                UIScrollView.appearance().bounces = false
            }
            .onDisappear {
                UIScrollView.appearance().bounces = true
            }
    }
    
}


struct RotationModifier: ViewModifier {
    let action: (UIDeviceOrientation) -> Void

    func body(content: Content) -> some View {
        content
            .onAppear()
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                action(UIDevice.current.orientation)
            }
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
