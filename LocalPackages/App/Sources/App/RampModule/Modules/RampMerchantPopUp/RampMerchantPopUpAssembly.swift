import Foundation
import KeeperCore
import TKCore
import UIKit

struct RampMerchantPopUpAssembly {
    private init() {}
    static func module(
        merchantInfo: OnRampMerchantInfo,
        actionURL: URL,
        appSettings: AppSettings,
        urlOpener: URLOpener
    ) -> MVVMModule<RampMerchantPopUpViewController, RampMerchantPopUpModuleOutput, Void> {
        let viewModel = RampMerchantPopUpViewModelImplementation(
            merchantInfo: merchantInfo,
            actionURL: actionURL,
            appSettings: appSettings,
            urlOpener: urlOpener
        )
        let viewController = RampMerchantPopUpViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: ())
    }
}
