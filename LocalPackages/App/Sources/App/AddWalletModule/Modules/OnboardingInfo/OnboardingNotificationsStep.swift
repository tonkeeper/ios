import AppUI
import TKCoordinator
import TKLocalize
import TKUIKit
import UIKit
import UserNotifications

/// The push permission step of an add-wallet flow: the grant is the preference
/// `PushNotificationManager` turns into a subscription for the wallet that lands right after, so
/// every flow has to offer it while it still owns the screen.
enum OnboardingNotificationsStep {
    /// A permission the system will not prompt for again has nothing left to ask: an authorized one
    /// already subscribes the new wallet, and a denied one can only be changed in system settings,
    /// where the balance setup step sends the user.
    static func isNeeded(authorizationStatus: UNAuthorizationStatus) -> Bool {
        authorizationStatus == .notDetermined
    }

    @MainActor
    static func push(
        router: NavigationControllerRouter,
        animated: Bool = true,
        onFinish: @escaping () -> Void
    ) {
        // Resolved before the asynchronous status check, and never asked as the flow's first
        // screen: a flow presents its navigation controller as soon as that screen is pushed, and
        // would otherwise present an empty one — a deeplink arrival also has no reason to open on
        // a permission prompt.
        guard !router.rootViewController.viewControllers.isEmpty else {
            onFinish()
            return
        }
        Task { @MainActor in
            let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            guard isNeeded(authorizationStatus: status) else {
                onFinish()
                return
            }
            pushScreen(router: router, animated: animated, onFinish: onFinish)
        }
    }

    @MainActor
    private static func pushScreen(
        router: NavigationControllerRouter,
        animated: Bool,
        onFinish: @escaping () -> Void
    ) {
        let state = OnboardingInfoScreenState(
            icon: .TKUIKit.Icons.Size128.notification,
            iconTintColor: .accentBlue,
            title: TKLocales.Onboarding.Notifications.title,
            subtitle: TKLocales.Onboarding.Notifications.caption,
            buttonTitle: TKLocales.Onboarding.Notifications.buttonTitle
        )
        let viewController = OnboardingInfoViewController(state: state)
        viewController.isInteractivePopDisabled = true
        viewController.didTapContinue = { [weak viewController] in
            guard viewController?.beginTransition(showsLoader: true) == true else { return }
            Task { [weak viewController] in
                _ = try? await UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .badge, .sound]
                )
                await MainActor.run { [weak viewController] in
                    viewController?.endTransition()
                    onFinish()
                }
            }
        }
        viewController.setupHeaderSkipButton(title: TKLocales.Onboarding.BackupIntro.later) { [weak viewController] in
            guard viewController?.beginTransition(showsLoader: false) == true else { return }
            viewController?.endTransition()
            onFinish()
        }

        router.push(viewController: viewController, animated: animated)
    }
}
