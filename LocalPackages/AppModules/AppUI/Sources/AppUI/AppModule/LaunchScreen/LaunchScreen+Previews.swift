import SwiftUI
import TKUIKit

#Preview("Deep Blue") {
    LaunchScreen()
        .tkPreviewTheme(.deepBlue)
}

// Renders identically to the one above: the screen pins its own theme, matching the launch
// storyboard whatever the app is set to.
#Preview("Light theme, still deep blue") {
    LaunchScreen()
        .tkPreviewTheme(.light)
}
