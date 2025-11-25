import SwiftUI

protocol AppDestination: Hashable {
    associatedtype Screen: View
    
    @ViewBuilder func makeView() -> Screen
}
