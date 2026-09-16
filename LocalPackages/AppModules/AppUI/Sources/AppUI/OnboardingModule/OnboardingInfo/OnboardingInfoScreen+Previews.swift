import SwiftUI
import TKUIKit

@available(iOS 17.0, *)
#Preview("Backup intro") {
    OnboardingInfoScreen(
        state: .preview,
        onBack: {},
        skip: OnboardingInfoScreen.SkipAction(title: "Later", action: {}),
        onContinue: {}
    )
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Notifications") {
    OnboardingInfoScreen(
        state: .previewNotifications,
        skip: OnboardingInfoScreen.SkipAction(title: "Later", action: {}),
        onContinue: {}
    )
    .tkPreviewTheme(.deepBlue)
}

private extension OnboardingInfoScreenState {
    static let preview = OnboardingInfoScreenState(
        icon: .TKUIKit.Icons.Size128.textbook,
        iconTintColor: .accentBlue,
        title: "Back up your recovery phrase",
        subtitle: "Without this phrase you may lose access to your funds if you delete the app or change device.",
        buttonTitle: "Continue"
    )

    static let previewNotifications = OnboardingInfoScreenState(
        icon: .TKUIKit.Icons.Size128.notification,
        iconTintColor: .accentBlue,
        title: "Enable notifications",
        subtitle: "Get instantly notified when you receive crypto on your wallet.",
        buttonTitle: "Enable notifications"
    )
}
