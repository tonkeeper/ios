import SwiftUI
import TKUIKit

#Preview("Start") {
    OnboardingRootScreen(
        state: .preview,
        onCreate: {},
        onImport: {}
    )
    .tkPreviewTheme(.deepBlue)
}

private extension OnboardingRootScreenState {
    static let preview = OnboardingRootScreenState(
        title: "Keeper",
        caption: "Create a new wallet\u{00A0}or add an\u{00A0}existing one",
        createButtonTitle: "Create New Wallet",
        importButtonTitle: "Import Existing Wallet",
        termsCaption: "By continuing, you agree to our Terms of Use",
        termsLinkTitle: "Terms of Use",
        termsURL: URL(string: "https://tonkeeper.com/terms")
    )
}
