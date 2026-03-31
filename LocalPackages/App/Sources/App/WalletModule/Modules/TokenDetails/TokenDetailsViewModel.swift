import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

protocol TokenDetailsModuleOutput: AnyObject {
    var didTapSend: ((KeeperCore.Token) -> Void)? { get set }
    var didTapReceive: ((KeeperCore.Token) -> Void)? { get set }
    var didTapBuyOrSell: (() -> Void)? { get set }
    var didTapSwap: ((KeeperCore.Token) -> Void)? { get set }
    var didOpenURL: ((URL) -> Void)? { get set }
}

protocol TokenDetailsViewModel: AnyObject {
    var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)? { get set }
    var didUpdateInformationView: ((TokenDetailsInformationView.Model) -> Void)? { get set }
    var didUpdateButtonsView: ((TokenDetailsHeaderButtonsView.Model) -> Void)? { get set }
    var didUpdateChartViewController: ((UIViewController) -> Void)? { get set }
    var didUpdateBannerItems: (([TokenDetailsBannerItem]) -> Void)? { get set }

    func viewDidLoad()
    func didTapOpenDetails()
    func reload()
}

struct TokenDetailsModel {
    struct Button {
        let iconButton: IconButton
        let isEnable: Bool
    }

    struct TransferAvailability {
        let text: String
        let action: (() -> Void)?
    }

    struct Caption {
        let text: NSAttributedString
        let icon: TKPlainButton.Model.Icon?
        let action: (() -> Void)?

        init(
            text: NSAttributedString,
            icon: TKPlainButton.Model.Icon? = nil,
            action: (() -> Void)? = nil
        ) {
            self.text = text
            self.icon = icon
            self.action = action
        }
    }

    enum Network {
        case ton
        case trc20
        case none
    }

    var title: String
    var caption: Caption?
    var image: TKImage
    var network: Network
    var tokenAmount: String
    var convertedAmount: String?
    var transferAvailability: TransferAvailability? = nil
    var buttons: [Button]
    var bannerItems: [TokenDetailsBannerItem]
}

final class TokenDetailsViewModelImplementation: TokenDetailsViewModel, TokenDetailsModuleOutput {
    // MARK: - TokenDetailsModuleOutput

    var didTapSend: ((KeeperCore.Token) -> Void)?
    var didTapReceive: ((KeeperCore.Token) -> Void)?
    var didTapBuyOrSell: (() -> Void)?
    var didTapSwap: ((KeeperCore.Token) -> Void)?
    var didOpenURL: ((URL) -> Void)?

    // MARK: - TokenDetailsViewModel

    var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)?
    var didUpdateInformationView: ((TokenDetailsInformationView.Model) -> Void)?
    var didUpdateButtonsView: ((TokenDetailsHeaderButtonsView.Model) -> Void)?
    var didUpdateChartViewController: ((UIViewController) -> Void)?
    var didUpdateBannerItems: (([any TokenDetailsBannerItem]) -> Void)?

    func viewDidLoad() {
        setupObservations()
        setInitialState()
        setupChart()
        configurator.viewDidLoad()
    }

    func didTapOpenDetails() {
        guard let url = configurator.getDetailsURL() else { return }
        didOpenURL?(url)
    }

    func reload() {
        balanceLoader.loadWalletBalance(wallet: wallet)
        configurator.reload()
    }

    // MARK: - State

    private let syncQueue = DispatchQueue(label: "TokenDetailsViewModelImplementationQueue")

    // MARK: - Image Loading

    private let imageLoader = ImageLoader()

    // MARK: - Dependencies

    private let wallet: Wallet
    private let balanceLoader: BalanceLoader
    private let balanceStore: ProcessedBalanceStore
    private let appSettingsStore: AppSettingsStore
    private var configurator: TokenDetailsConfigurator
    private let chartViewControllerProvider: (() -> UIViewController?)?

    // MARK: - Init

    init(
        wallet: Wallet,
        balanceLoader: BalanceLoader,
        balanceStore: ProcessedBalanceStore,
        appSettingsStore: AppSettingsStore,
        configurator: TokenDetailsConfigurator,
        chartViewControllerProvider: (() -> UIViewController?)?
    ) {
        self.wallet = wallet
        self.balanceLoader = balanceLoader
        self.balanceStore = balanceStore
        self.appSettingsStore = appSettingsStore
        self.configurator = configurator
        self.chartViewControllerProvider = chartViewControllerProvider
    }
}

private extension TokenDetailsViewModelImplementation {
    func setInitialState() {
        syncQueue.sync {
            let balance = balanceStore.getState()[wallet]?.balance
            let model = configurator.getTokenModel(balance: balance, isSecureMode: appSettingsStore.getState().isSecureMode)
            DispatchQueue.main.async {
                self.didUpdateModel(model)
            }
        }
    }

    func setupObservations() {
        configurator.didUpdate = { [weak self, wallet] in
            guard let self else { return }
            self.syncQueue.async {
                let balance = self.balanceStore.getState()[wallet]?.balance
                let model = self.configurator.getTokenModel(balance: balance, isSecureMode: self.appSettingsStore.getState().isSecureMode)
                DispatchQueue.main.async {
                    self.didUpdateModel(model)
                }
            }
        }

        balanceStore.addObserver(self) { observer, event in
            switch event {
            case let .didUpdateProccessedBalance(wallet):
                guard wallet == observer.wallet else { return }
                observer.syncQueue.async {
                    let balance = observer.balanceStore.getState()[wallet]?.balance
                    let model = observer.configurator.getTokenModel(balance: balance, isSecureMode: observer.appSettingsStore.getState().isSecureMode)
                    DispatchQueue.main.async {
                        self.didUpdateModel(model)
                    }
                }
            }
        }
    }

    func didUpdateModel(_ model: TokenDetailsModel) {
        setupTitleView(model: model)
        setupInformationView(model: model)
        setupButtonsView(model: model)
        setupBanners(model: model)
    }

    func setupTitleView(model: TokenDetailsModel) {
        didUpdateTitleView?(
            TKUINavigationBarTitleView.Model(
                title: model.title,
                caption: {
                    guard let caption = model.caption else { return nil }
                    return TKPlainButton.Model(
                        title: caption.text,
                        icon: model.caption?.icon,
                        action: caption.action
                    )
                }()
            )
        )
    }

    func setupButtonsView(model: TokenDetailsModel) {
        let mapper = IconButtonModelMapper()
        let buttons = model.buttons.map { buttonModel in
            TokenDetailsHeaderButtonsView.Model.Button(
                configuration: mapper.mapButton(model: buttonModel.iconButton),
                isEnabled: buttonModel.isEnable,
                action: { [weak self] in
                    switch buttonModel.iconButton {
                    case let .send(token):
                        self?.didTapSend?(token)
                    case let .receive(token):
                        self?.didTapReceive?(token)
                    case .buySell:
                        self?.didTapBuyOrSell?()
                    case let .swap(token):
                        self?.didTapSwap?(token)
                    default:
                        break
                    }
                }
            )
        }
        let model = TokenDetailsHeaderButtonsView.Model(buttons: buttons)
        didUpdateButtonsView?(model)
    }

    func setupInformationView(model: TokenDetailsModel) {
        let badge: TKListItemIconView.Configuration.Badge? = {
            switch model.network {
            case .none:
                return nil
            case .ton:
                return TKListItemIconView.Configuration.Badge(
                    configuration: TKListItemBadgeView.Configuration(
                        item: .image(.image(.App.Currency.Vector.ton)),
                        size: .large,
                        backgroundColor: .Background.page
                    ),
                    position: .bottomRight
                )
            case .trc20:
                return TKListItemIconView.Configuration.Badge(
                    configuration: TKListItemBadgeView.Configuration(
                        item: .image(.image(.App.Currency.Vector.trc20)),
                        size: .large,
                        backgroundColor: .Background.page
                    ),
                    position: .bottomRight
                )
            }
        }()

        let imageConfiguration = TKListItemIconView.Configuration(
            content: .image(
                TKImageView.Model(
                    image: model.image,
                    tintColor: .clear,
                    size: .size(CGSize(width: 64, height: 64)),
                    corners: .circle
                )
            ),
            alignment: .center,
            size: CGSize(width: 64, height: 64),
            badge: badge
        )

        didUpdateInformationView?(
            TokenDetailsInformationView.Model(
                imageConfiguration: imageConfiguration,
                tokenAmount: model.tokenAmount,
                convertedAmount: model.convertedAmount,
                transferAvailabilityText: model.transferAvailability?.text,
                transferAvailabilityAction: model.transferAvailability?.action
            )
        )
    }

    func setupBanners(model: TokenDetailsModel) {
        didUpdateBannerItems?(model.bannerItems)
    }

    func setupChart() {
        guard let chartViewController = chartViewControllerProvider?() else { return }
        didUpdateChartViewController?(chartViewController)
    }
}
