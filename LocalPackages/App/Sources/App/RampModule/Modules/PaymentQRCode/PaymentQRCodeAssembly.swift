import Foundation
import KeeperCore
import TKCore
import TKUIKit
import UIKit

struct PaymentQRCodeData {
    let address: String
    let iconURL: URL?
}

enum PaymentQRCodeAssembly {
    static func module(
        data: PaymentQRCodeData,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) -> MVVMModule<PaymentQRCodeViewController, PaymentQRCodeModuleOutput, Void> {
        let viewModel = PaymentQRCodeViewModel(
            data: data,
            qrCodeGenerator: keeperCoreMainAssembly.coreAssembly
                .qrCodeGenerator(persistent: true)
        )
        let viewController = PaymentQRCodeViewController(viewModel: viewModel)
        return MVVMModule(view: viewController, output: viewModel, input: ())
    }
}
