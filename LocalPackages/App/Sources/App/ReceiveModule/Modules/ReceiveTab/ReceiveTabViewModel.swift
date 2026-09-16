import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import TonSwift
import TronSwift
import UIKit

protocol ReceiveTabModuleOutput: AnyObject {}

protocol ReceiveTabViewModel: AnyObject {
    var didUpdateModel: ((ReceiveTabView.Model) -> Void)? { get set }
    var didGenerateQRCode: ((QrCodeMatrix?) -> Void)? { get set }
    var didTapShare: ((String?) -> Void)? { get set }

    func viewDidLoad()
}

final class ReceiveTabViewModelImplementation: ReceiveTabViewModel, ReceiveTabModuleOutput {
    // MARK: - ReceiveTabModuleOutput

    // MARK: - ReceiveTabViewModel

    var didUpdateModel: ((ReceiveTabView.Model) -> Void)?
    var didGenerateQRCode: ((QrCodeMatrix?) -> Void)?
    var didTapShare: ((String?) -> Void)?

    func viewDidLoad() {
        update()
    }

    func generateQRCode() {
        let qrCodeString = makeQRCodePayload()
        qrCodeGenerationController.generate(
            payload: qrCodeString
        ) { [weak self] matrix in
            self?.didGenerateQRCode?(matrix)
        }
    }

    // MARK: - Dependencies

    private let token: ReceiveLegacyToken
    private let wallet: Wallet
    private let deeplinkGenerator: DeeplinkGenerator
    private let qrCodeGenerationController: QrCodeMatrixGenerationController

    init(
        token: ReceiveLegacyToken,
        wallet: Wallet,
        deeplinkGenerator: DeeplinkGenerator,
        qrCodeGenerator: QrCodeMatrixGenerator
    ) {
        self.token = token
        self.wallet = wallet
        self.deeplinkGenerator = deeplinkGenerator
        self.qrCodeGenerationController = QrCodeMatrixGenerationController(
            qrCodeGenerator: qrCodeGenerator,
            centerCutoutSize: Constants.qrCodeCenterCutoutSize
        )
    }
}

private extension ReceiveTabViewModelImplementation {
    enum Constants {
        static let qrCodeCenterCutoutSize = CGSize(width: 72, height: 72)
    }

    func makeQRCodePayload() -> String {
        switch token {
        case let .ton(token):
            let jettonAddress: TonSwift.Address?
            switch token {
            case .ton:
                jettonAddress = nil
            case let .jetton(jettonItem):
                jettonAddress = jettonItem.jettonInfo.address
            }

            do {
                return try deeplinkGenerator.generateTransferDeeplink(
                    with: wallet.friendlyAddress.toString(),
                    jettonAddress: jettonAddress
                )
            } catch {
                return ""
            }
        case .tron:
            return wallet.tron?.address.base58 ?? ""
        }
    }

    func createModel(
        avatarImageSource: AssetAvatarViewImageSource,
        description: String,
        walletAddress: String?
    ) -> ReceiveTabView.Model {
        let titleDescriptionModel = TKTitleDescriptionView.Model(
            title: TKLocales.Receive.yourAddressTitle,
            bottomDescription: description
        )

        let buttonsModel = ReceiveButtonsView.Model(
            copyButtonModel: TKUIActionButton.Model(
                title: TKLocales.Actions.copy,
                icon: TKUIButtonTitleIconContentView.Model.Icon(
                    icon: .TKUIKit.Icons.Size16.copy,
                    position: .left
                )
            ),
            copyButtonAction: {
                [weak self] in
                self?.copyButtonAction()
            },
            shareButtonConfiguration: TKButton.Configuration(
                content: TKButton.Configuration.Content(icon: .TKUIKit.Icons.Size16.share),
                contentPadding: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16),
                padding: .zero,
                iconTintColor: .Button.secondaryForeground,
                backgroundColors: [.normal: .Button.secondaryBackground, .highlighted: .Button.secondaryBackgroundHighlighted],
                cornerRadius: 24,
                action: { [weak self] in
                    guard let address = self?.getAddress() else { return }
                    self?.didTapShare?(address)
                }
            )
        )

        return ReceiveTabView.Model(
            titleDescriptionModel: titleDescriptionModel,
            buttonsModel: buttonsModel,
            address: walletAddress,
            addressButtonAction: { [weak self] in
                self?.copyButtonAction()
            },
            avatarImageSource: avatarImageSource,
            tag: wallet.receiveTagSwiftUIConfiguration()
        )
    }

    func copyButtonAction() {
        guard let address = getAddress() else { return }
        Pasteboard.copy(value: address, toast: wallet.copyToastConfiguration())
    }

    func getAddress() -> String? {
        switch token {
        case .ton:
            try? wallet.friendlyAddress.toString()
        case .tron:
            wallet.tron?.address.base58
        }
    }

    func update() {
        let avatarImageSource: AssetAvatarViewImageSource
        let description: String
        let walletAddress: String?

        switch token {
        case let .ton(token):
            walletAddress = try? wallet.friendlyAddress.toString()
            let descriptionTokenName: String
            switch token {
            case .ton:
                descriptionTokenName = "\(TonInfo.name)"
                avatarImageSource = .image(.TKUIKit.Icons.Size44.tonChain)
            case let .jetton(jettonItem):
                descriptionTokenName = jettonItem.jettonInfo.symbol ?? jettonItem.jettonInfo.name

                avatarImageSource = .url(
                    jettonItem.jettonInfo.imageURL,
                    chainIcon: jettonItem.jettonInfo.isTonUSDT && wallet.tron != nil
                        ? .TKUIKit.Icons.Size20.tonChain
                        : nil
                )
            }

            description = TKLocales.Receive.description(descriptionTokenName)
        case let .tron(tronToken):
            switch tronToken {
            case .usdt:
                avatarImageSource = .image(
                    .TKUIKit.Icons.Size44.currencyUsdt,
                    chainIcon: .TKUIKit.Icons.Size44.currencyTrc20
                )
                description = TKLocales.Receive.Trc20.description
                walletAddress = wallet.tron?.address.base58
            case .trx:
                avatarImageSource = .image(.TKUIKit.Icons.Size44.currencyTrc20)
                description = TKLocales.Receive.Trx.description
                walletAddress = wallet.tron?.address.base58
            }
        }

        let model = createModel(
            avatarImageSource: avatarImageSource,
            description: description,
            walletAddress: walletAddress
        )
        didUpdateModel?(model)
        generateQRCode()
    }
}
