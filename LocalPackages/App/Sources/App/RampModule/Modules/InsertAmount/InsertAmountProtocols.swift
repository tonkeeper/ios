import Foundation
import KeeperCore
import TKUIKit

@MainActor
protocol InsertAmountModuleOutput: AnyObject {
    var didTapBack: (() -> Void)? { get set }
    var didTapClose: (() -> Void)? { get set }
    var didTapContinue: ((RampOnrampContinueContext, OnRampMerchantInfo, URL?) -> Void)? { get set }
    var didTapProvider: (([ProviderPickerItem], OnRampMerchantInfo) -> Void)? { get set }
}

@MainActor
protocol InsertAmountModuleInput: AnyObject {
    func setSelectedMerchant(_ merchant: OnRampMerchantInfo)
}

enum InsertAmountError {
    case belowMin(formattedMessage: String)
    case aboveMax(formattedMessage: String)
}

enum InsertAmountProviderViewState {
    case loading
    case data(TKListItemContentView.Configuration)
}

@MainActor
protocol InsertAmountViewModelProtocol: AnyObject {
    var didUpdateTitle: ((String) -> Void)? { get set }
    var didUpdateButton: ((TKButton.Configuration) -> Void)? { get set }
    var didUpdateProviderView: ((InsertAmountProviderViewState) -> Void)? { get set }
    var didUpdateProviderViewHidden: ((Bool) -> Void)? { get set }
    var didUpdateAmountError: ((String?) -> Void)? { get set }
    var didShowError: ((String) -> Void)? { get set }

    func viewDidLoad()
    func didTapBackButton()
    func didTapCloseButton()
    func didTapContinueButton()
    func didTapProviderView()
}
