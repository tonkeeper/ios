import Foundation
import TKCore
import UIKit

struct PaymentQRCodeData {
    let address: String
    let iconURL: URL?
    let networkIconURL: URL?
}

enum PaymentQRCodeAssembly {
    static func module(
        data: PaymentQRCodeData
    ) -> MVVMModule<PaymentQRCodeViewController, PaymentQRCodeModuleOutput, Void> {
        let viewModel = PaymentQRCodeViewModel(
            data: data,
            qrCodeGenerator: QRCodeGeneratorImplementation()
        )
        let viewController = PaymentQRCodeViewController(viewModel: viewModel)
        return MVVMModule(view: viewController, output: viewModel, input: ())
    }
}
