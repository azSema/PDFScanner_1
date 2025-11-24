import SwiftUI

var deviceType: DeviceType {
    let idiom = UIDevice.current.userInterfaceIdiom
    if idiom == .pad { return .ipad }
    
    switch UIScreen.main.nativeBounds.height {
    case 1136, 1334, 1920, 1792, 2208, 2340: return .iphoneSE
    case 2436, 2688, 2532, 2556, 2778, 2796: return .iphoneLarge
    default: return .iphoneLarge
    }
}

enum DeviceType {
    case iphoneSE
    case iphoneLarge
    case ipad
}
