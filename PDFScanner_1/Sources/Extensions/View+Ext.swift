import SwiftUI

extension View {
    
    /// Задает размер для PDF-страницы с учетом ориентации и пропорций.
    func pdfDocumentFrame(
        pageRect: CGRect,
        rotation: Int,
        maxRatio: CGFloat = 0
    ) -> some View {
        let aspectRatio = (rotation == 90 || rotation == 270)
        ? pageRect.height / pageRect.width
        : pageRect.width / pageRect.height
        
        return self.frame(
            width: UIScreen.main.bounds.width - 32,
            height: (UIScreen.main.bounds.width - 32) / max(aspectRatio, maxRatio)
        )
    }
    
    /// Выполняет действие при изменении ориентации устройства.
    func onRotate(perform action: @escaping (UIDeviceOrientation) -> Void) -> some View {
        self.modifier(RotationModifier(action: action))
    }
}

/// Модификатор View, отслеживающий изменение ориентации устройства.
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
