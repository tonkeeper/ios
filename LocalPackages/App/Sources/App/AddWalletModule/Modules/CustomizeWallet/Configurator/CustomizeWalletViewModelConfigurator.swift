import TKUIKit
import UIKit

enum CustomizeWalletViewModelContinueButtonMode {
    case visible(title: String, action: () -> Void)
    case hidden
}

protocol CustomizeWalletViewModelConfigurator: AnyObject {
    var didCustomizeWallet: (() -> Void)? { get set }

    var continueButtonMode: CustomizeWalletViewModelContinueButtonMode { get }

    func didSelectColor()
    func didEditName()
}

extension CustomizeWalletViewModelConfigurator {
    func didSelectColor() {}
    func didEditName() {}
}
