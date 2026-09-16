import Foundation
import TKLocalize
import TKUIKit
import UIKit

protocol PaymentQRCodeModuleOutput: AnyObject {
    var didTapClose: (() -> Void)? { get set }
}

protocol PaymentQRCodeViewModelProtocol: AnyObject {
    var didUpdateModel: ((ReceiveTabView.Model) -> Void)? { get set }
    var didGenerateQRCode: ((QrCodeMatrix?) -> Void)? { get set }
    var didTapShare: ((String) -> Void)? { get set }
    var didTapCopy: ((String) -> Void)? { get set }

    func viewDidLoad()
    func didTapCloseButton()
}

final class PaymentQRCodeViewModel: PaymentQRCodeViewModelProtocol, PaymentQRCodeModuleOutput {
    var didUpdateModel: ((ReceiveTabView.Model) -> Void)?
    var didGenerateQRCode: ((QrCodeMatrix?) -> Void)?
    var didTapShare: ((String) -> Void)?
    var didTapCopy: ((String) -> Void)?
    var didTapClose: (() -> Void)?

    private let data: PaymentQRCodeData
    private let qrCodeGenerationController: QrCodeMatrixGenerationController

    init(
        data: PaymentQRCodeData,
        qrCodeGenerator: QrCodeMatrixGenerator
    ) {
        self.data = data
        self.qrCodeGenerationController = QrCodeMatrixGenerationController(
            qrCodeGenerator: qrCodeGenerator,
            centerCutoutSize: Constants.qrCodeCenterCutoutSize
        )
    }

    func viewDidLoad() {
        updateModel()
        generateQRCode()
    }

    func generateQRCode() {
        qrCodeGenerationController.generate(
            payload: data.address
        ) { [weak self] matrix in
            self?.didGenerateQRCode?(matrix)
        }
    }

    func didTapCloseButton() {
        didTapClose?()
    }
}

private extension PaymentQRCodeViewModel {
    enum Constants {
        static let qrCodeCenterCutoutSize = CGSize(width: 72, height: 72)
    }

    func updateModel() {
        let model = ReceiveTabView.Model(
            titleDescriptionModel: .init(
                title: TKLocales.Ramp.Deposit.PaymentQrCode.title,
                bottomDescription: TKLocales.Ramp.Deposit.PaymentQrCode.subtitle
            ),
            buttonsModel: makeButtonsConfiguration(),
            address: data.address,
            addressButtonAction: { [weak self] in
                guard let self else { return }
                self.didTapCopy?(self.data.address)
            },
            avatarImageSource: .url(data.iconURL),
            tag: nil
        )
        didUpdateModel?(model)
    }

    func makeButtonsConfiguration() -> ReceiveButtonsView.Model {
        ReceiveButtonsView.Model(
            copyButtonModel: TKUIActionButton.Model(
                title: TKLocales.Actions.copy,
                icon: TKUIButtonTitleIconContentView.Model.Icon(
                    icon: .TKUIKit.Icons.Size16.copy,
                    position: .left
                )
            ),
            copyButtonAction: { [weak self] in
                guard let self else { return }
                self.didTapCopy?(self.data.address)
            },
            shareButtonConfiguration: TKButton.Configuration(
                content: TKButton.Configuration.Content(icon: .TKUIKit.Icons.Size16.share),
                contentPadding: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16),
                padding: .zero,
                iconTintColor: .Button.secondaryForeground,
                backgroundColors: [.normal: .Button.secondaryBackground, .highlighted: .Button.secondaryBackgroundHighlighted],
                cornerRadius: 24,
                action: { [weak self] in
                    guard let self else { return }
                    self.didTapShare?(self.data.address)
                }
            )
        )
    }
}
