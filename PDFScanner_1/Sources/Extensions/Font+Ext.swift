import SwiftUI

extension Font {
    
    static func regular(_ size: CGFloat) -> Font {
        return .system(size: size, weight: .regular)
    }
    
    static func medium(_ size: CGFloat) -> Font {
        return .system(size: size, weight: .medium)
    }
    
    static func semiBold(_ size: CGFloat) -> Font {
        return .system(size: size, weight: .semibold)
    }
    
    static func semibold(_ size: CGFloat) -> Font {
        return .system(size: size, weight: .semibold)
    }
    
    static func bold(_ size: CGFloat) -> Font {
        return .system(size: size, weight: .bold)
    }
    
    static func heavy(_ size: CGFloat) -> Font {
        return .system(size: size, weight: .heavy)
    }
    
}
