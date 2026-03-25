import Foundation
import TKCore
import TKLocalize
import TKUIKit
import UIKit

protocol PaymentQRCodeModuleOutput: AnyObject {
    var didTapClose: (() -> Void)? { get set }
}

protocol PaymentQRCodeViewModelProtocol: AnyObject {
    var didUpdateModel: ((ReceiveTabView.Model) -> Void)? { get set }
    var didGenerateQRCode: ((UIImage?) -> Void)? { get set }
    var didTapShare: ((String) -> Void)? { get set }
    var didTapCopy: ((String) -> Void)? { get set }

    func viewDidLoad()
    func generateQRCode(size: CGSize)
    func didTapCloseButton()
}

final class PaymentQRCodeViewModel: PaymentQRCodeViewModelProtocol, PaymentQRCodeModuleOutput {
    var didUpdateModel: ((ReceiveTabView.Model) -> Void)?
    var didGenerateQRCode: ((UIImage?) -> Void)?
    var didTapShare: ((String) -> Void)?
    var didTapCopy: ((String) -> Void)?
    var didTapClose: (() -> Void)?

    private let data: PaymentQRCodeData
    private let qrCodeGenerator: QRCodeGenerator

    private var qrCodeGenerateTask: Task<Void, Never>?

    init(
        data: PaymentQRCodeData,
        qrCodeGenerator: QRCodeGenerator
    ) {
        self.data = data
        self.qrCodeGenerator = qrCodeGenerator
    }

    func viewDidLoad() {
        updateModel()
    }

    func generateQRCode(size: CGSize) {
        qrCodeGenerateTask?.cancel()
        qrCodeGenerateTask = Task {
            let image = await qrCodeGenerator.generate(string: data.address, size: size)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                didGenerateQRCode?(image)
            }
        }
    }

    func didTapCloseButton() {
        didTapClose?()
    }
}

private extension PaymentQRCodeViewModel {
    func updateModel() {
        let model = ReceiveTabView.Model(
            titleDescriptionModel: .init(
                title: TKLocales.Ramp.Deposit.paymentQRCodeTitle,
                bottomDescription: TKLocales.Ramp.Deposit.paymentQRCodeSubtitle
            ),
            buttonsModel: makeButtonsConfiguration(),
            address: data.address,
            addressButtonAction: { [weak self] in
                guard let self else { return }
                self.didTapCopy?(self.data.address)
            },
            iconConfiguration: makeIconConfiguration(),
            tag: nil
        )
        didUpdateModel?(model)
    }

    func makeIconConfiguration() -> TKListItemIconView.Configuration {
        guard let iconURL = data.iconURL else { return .default }

        let image = TKImageView.Model(
            image: .urlImage(iconURL),
            size: .size(CGSize(width: 44, height: 44)),
            corners: .circle
        )

        let badge: TKListItemIconView.Configuration.Badge?
        if let networkIconURL = data.networkIconURL {
            badge = TKListItemIconView.Configuration.Badge(
                configuration: TKListItemBadgeView.Configuration(
                    item: .image(.urlImage(networkIconURL)),
                    size: .medium,
                    backgroundColor: .Constant.white
                ),
                position: .bottomRight
            )
        } else {
            badge = nil
        }

        return TKListItemIconView.Configuration(
            content: .image(image),
            alignment: .center,
            size: CGSize(width: 44, height: 44),
            badge: badge
        )
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
