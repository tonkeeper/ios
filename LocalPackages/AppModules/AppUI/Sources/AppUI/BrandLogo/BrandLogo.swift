import SwiftUI
import TKUIKit

public struct BrandLogo: View {
    public init() {}

    public var body: some View {
        SwiftUI.Image.TKUIKit.Icons.Size108.logo
            .renderingMode(.template)
            .foregroundStyle(.iconPrimary)
    }
}

public extension BrandLogo {
    static let size: CGFloat = 108

    static let centerOffset: CGFloat = -13

    /// Should be equal (globally) across launch storyboard, launchscreen and onboarding root
    static func topInset(in proxy: GeometryProxy) -> CGFloat {
        let fullHeight = proxy.size.height
            + proxy.safeAreaInsets.top
            + proxy.safeAreaInsets.bottom
        let centerFromFullTop = fullHeight / 2 + centerOffset
        return centerFromFullTop - size / 2 - proxy.safeAreaInsets.top
    }
}
