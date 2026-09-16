import SwiftUI

public struct ServiceCardHighlightStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .tkTapAnimation(isPressed: configuration.isPressed)
    }
}
