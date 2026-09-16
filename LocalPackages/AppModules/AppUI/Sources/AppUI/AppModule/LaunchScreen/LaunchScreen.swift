import SwiftUI
import TKUIKit

public struct LaunchScreen: View {
    public init() {}

    /// Pinned to deep blue whatever theme the app runs in: `LaunchScreen.storyboard` names the
    /// `DeepBlue` colour assets outright, and this screen takes over from it mid-launch.
    public var body: some View {
        BrandLogo()
            .offset(y: BrandLogo.centerOffset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.backgroundPage)
            .ignoresSafeArea()
            .environment(\.tkResolvedTheme, .deepBlue)
    }
}
