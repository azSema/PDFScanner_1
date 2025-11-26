import SwiftUI
import Lottie

enum AnimationItem: String, CaseIterable {
    
    case ocrScan = "Document OCR Scan"
    
    case onb1Ipad = "onb 1 ipad"
    case onb2Ipad = "onb 2 ipad"
    
    case onb1Iphone = "onb 1 iphone"
    case onb2Iphone = "onb 2 iphone"
    
    case pdfFIle = "PDF file"
    case signature = "signature"

    var fileName: String {
        return rawValue
    }
}

struct AnimationView: UIViewRepresentable {
    let item: AnimationItem
    let contentMode: UIView.ContentMode
    
    init(item: AnimationItem, contentMode: UIView.ContentMode = .scaleAspectFit) {
        self.item = item
        self.contentMode = contentMode
    }

    let animationView = LottieAnimationView()
    
    func makeUIView(context: Context) -> some UIView {
        let view = UIView(frame: .zero)
        
        animationView.animation = LottieAnimation.named(item.fileName)
        animationView.contentMode = contentMode
        animationView.loopMode = .loop
        animationView.play()
        
        view.addSubview(animationView)
        
        animationView.translatesAutoresizingMaskIntoConstraints = false
        animationView.heightAnchor.constraint(equalTo: view.heightAnchor).isActive = true
        animationView.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
        
        return view
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {}
}
