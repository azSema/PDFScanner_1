import SwiftUI

struct BackImage: View {
    
    @State private var orientation = UIDevice.current.orientation
    let baseName: String
        
    init(baseName: String) {
        self.baseName = baseName
    }
    
    var body: some View {
        Image(fullName)
            .resizable()
            .ignoresSafeArea()
            .frame(maxWidth: UIScreen.main.bounds.width, maxHeight: .infinity, alignment: .top)
            .onRotate(perform: { orientation = $0 })
    }
    
    private var fullName: String {
        switch deviceType {
        case .ipad:
            if orientation.isLandscape {
                return baseName + ".hor"
            } else {
                return baseName
            }
        case .iphoneLarge:
            return baseName
        case .iphoneSE:
            return baseName + ".se"
        }
    }
}
