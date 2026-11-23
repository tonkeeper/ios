import UIKit

@MainActor
enum WalletImportPairingNavigation {
    static func dismiss(_ navigationController: UINavigationController?, completion: @escaping () -> Void) {
        guard let navigationController,
              navigationController.presentingViewController != nil,
              !navigationController.isBeingDismissed
        else {
            completion()
            return
        }
        navigationController.dismiss(animated: true, completion: completion)
    }
}
