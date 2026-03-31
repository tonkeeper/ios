import Foundation
import KeeperCore
import TKCore
import TKFeatureFlags
import TKLocalize
import TKUIKit
import TonSwift
import TronSwift
import UIKit

protocol ReceiveTabModuleOutput: AnyObject {}

protocol ReceiveTabViewModel: AnyObject {
    var didUpdateModel: ((ReceiveTabView.Model) -> Void)? { get set }
    var didGenerateQRCode: ((UIImage?) -> Void)? { get set }
    var didTapShare: ((String?) -> Void)? { get set }
    var didTapCopy: ((String?) -> Void)? { get set }
    var didUpdateSegmentedControl: ((BuySellListSegmentedControl.Model?) -> Void)? { get set }

    var showToast: ((ToastPresenter.Configuration) -> Void)? { get set }

    func viewDidLoad()
    func generateQRCode(size: CGSize)
}

enum ReceiveItem {
    case tonToken(TonToken)
    case tron
}

final class ReceiveTabViewModelImplementation: ReceiveTabViewModel, ReceiveTabModuleOutput {
    // MARK: - ReceiveTabModuleOutput

    // MARK: - ReceiveTabViewModel

    var didUpdateModel: ((ReceiveTabView.Model) -> Void)?
    var didGenerateQRCode: ((UIImage?) -> Void)?
    var didTapShare: ((String?) -> Void)?
    var didTapCopy: ((String?) -> Void)?
    var didUpdateSegmentedControl: ((BuySellListSegmentedControl.Model?) -> Void)?

    var showToast: ((ToastPresenter.Configuration) -> Void)?

    func viewDidLoad() {
        walletsStore.addObserver(self) { observer, event in
            switch event {
            case let .didUpdateWalletTron(wallet):
                DispatchQueue.main.async {
                    guard wallet == observer.wallet else { return }
                    observer.wallet = wallet
                    observer.update()
                }
            default: break
            }
        }

        update()
    }

    func generateQRCode(size: CGSize) {
        qrCodeGenerateTask?.cancel()
        qrCodeGenerateTask = Task {
            let qrCodeString: String
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
                    qrCodeString = try deeplinkGenerator.generateTransferDeeplink(
                        with: wallet.friendlyAddress.toString(),
                        jettonAddress: jettonAddress
                    )
                } catch {
                    qrCodeString = ""
                }
            case .tron:
                do {
                    qrCodeString = try deeplinkGenerator.generateTransferDeeplink(
                        with: wallet.tron?.address.base58 ?? ""
                    )
                } catch {
                    qrCodeString = ""
                }
            }

            let image = await qrCodeGenerator.generate(
                string: qrCodeString,
                size: size
            )
            guard !Task.isCancelled else { return }
            await MainActor.run {
                didGenerateQRCode?(image)
            }
        }
    }

    private var qrCodeGenerateTask: Task<Void, Never>?

    // MARK: - Dependencies

    private let token: Token
    private var wallet: Wallet
    private let walletsStore: WalletsStore
    private let deeplinkGenerator: DeeplinkGenerator
    private let qrCodeGenerator: QRCodeGenerator
    private let configuration: Configuration

    init(
        token: Token,
        wallet: Wallet,
        walletsStore: WalletsStore,
        deeplinkGenerator: DeeplinkGenerator,
        qrCodeGenerator: QRCodeGenerator,
        configuration: Configuration
    ) {
        self.token = token
        self.wallet = wallet
        self.walletsStore = walletsStore
        self.deeplinkGenerator = deeplinkGenerator
        self.qrCodeGenerator = qrCodeGenerator
        self.configuration = configuration
    }
}

private extension ReceiveTabViewModelImplementation {
    func createModel(
        icon: TKListItemIconView.Configuration,
        tokenName: String,
        description: String,
        walletAddress: String?
    ) -> ReceiveTabView.Model {
        let title = configuration.featureEnabled(.newRampFlow)
            ? TKLocales.Receive.yourAddress
            : TKLocales.Receive.title(tokenName)
        let titleDescriptionModel = TKTitleDescriptionView.Model(
            title: title,
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
            iconConfiguration: icon,
            tag: wallet.receiveTagConfiguration()
        )
    }

    func copyButtonAction() {
        guard let address = getAddress() else { return }
        didTapCopy?(address)
        showToast?(wallet.copyToastConfiguration())
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
        let icon: TKListItemIconView.Configuration
        let tokenName: String
        let description: String
        let walletAddress: String?

        switch token {
        case let .ton(token):
            walletAddress = try? wallet.friendlyAddress.toString()
            let descriptionTokenName: String
            switch token {
            case .ton:
                tokenName = TonInfo.name
                descriptionTokenName = "\(TonInfo.name)"
                icon = TKListItemIconView.Configuration(
                    content: .image(
                        .init(
                            image: .image(.App.Currency.Vector.ton),
                            size: .size(CGSize(width: 44, height: 44)),
                            corners: .circle
                        )
                    ),
                    alignment: .center,
                    size: CGSize(width: 44, height: 44),
                    badge: nil
                )
            case let .jetton(jettonItem):
                tokenName = jettonItem.jettonInfo.name
                descriptionTokenName = jettonItem.jettonInfo.symbol ?? jettonItem.jettonInfo.name

                var badge: TKListItemIconView.Configuration.Badge?
                if jettonItem.jettonInfo.isTonUSDT, wallet.isTronTurnOn {
                    badge = TKListItemIconView.Configuration.Badge(
                        configuration: TKListItemBadgeView.Configuration(
                            item: .image(.image(.App.Currency.Vector.ton)),
                            size: .medium,
                            backgroundColor: .Constant.white
                        ),
                        position: .bottomRight
                    )
                }

                icon = TKListItemIconView.Configuration(
                    content: .image(
                        .init(
                            image: .urlImage(jettonItem.jettonInfo.imageURL),
                            size: .size(CGSize(width: 44, height: 44)),
                            corners: .circle
                        )
                    ),
                    alignment: .center,
                    size: CGSize(width: 44, height: 44),
                    badge: badge
                )
            }

            description = TKLocales.Receive.description(descriptionTokenName)
        case let .tron(tronToken):
            switch tronToken {
            case .usdt:
                icon = TKListItemIconView.Configuration(
                    content: .image(
                        .init(
                            image: .image(.App.Currency.Size44.usdt),
                            size: .size(CGSize(width: 44, height: 44)),
                            corners: .circle
                        )
                    ),
                    alignment: .center,
                    size: CGSize(width: 44, height: 44),
                    badge: TKListItemIconView.Configuration.Badge(
                        configuration: TKListItemBadgeView.Configuration(
                            item: .image(.image(.App.Currency.Vector.trc20)),
                            size: .medium,
                            backgroundColor: .Constant.white
                        ),
                        position: .bottomRight
                    )
                )
                tokenName = USDT.name
                description = TKLocales.Receive.Trc20.description
                walletAddress = wallet.tron?.address.base58
            case .trx:
                icon = TKListItemIconView.Configuration(
                    content: .image(
                        .init(
                            image: .image(.App.Currency.Vector.trc20),
                            size: .size(CGSize(width: 44, height: 44)),
                            corners: .circle
                        )
                    ),
                    alignment: .center,
                    size: CGSize(width: 44, height: 44),
                    badge: nil
                )
                tokenName = TRX.name
                description = TKLocales.Receive.Trx.description
                walletAddress = wallet.tron?.address.base58
            }
        }

        let model = createModel(
            icon: icon,
            tokenName: tokenName,
            description: description,
            walletAddress: walletAddress
        )
        didUpdateModel?(model)
    }
}
