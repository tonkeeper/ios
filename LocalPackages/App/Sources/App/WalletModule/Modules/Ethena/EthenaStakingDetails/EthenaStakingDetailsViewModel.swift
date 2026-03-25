import BigInt
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

protocol EthenaStakingDetailsModuleOutput: AnyObject {
    var didOpenURL: ((URL) -> Void)? { get set }
    var didOpenURLInApp: ((URL) -> Void)? { get set }
    var didOpenDapp: ((URL, String?) -> Void)? { get set }
    var openJettonDetails: ((_ wallet: Wallet, _ jettonItem: JettonItem) -> Void)? { get set }
    var didTapStake: ((_ wallet: Wallet, _ stakingPoolInfo: StackingPoolInfo) -> Void)? { get set }
    var didTapUnstake: ((_ wallet: Wallet, _ stakingPoolInfo: StackingPoolInfo) -> Void)? { get set }
    var didTapCollect: ((
        _ wallet: Wallet,
        _ stakingPoolInfo: StackingPoolInfo,
        _ accountStakingInfo: AccountStackingInfo
    ) -> Void)? { get set }
}

protocol EthenaStakingDetailsModuleInput: AnyObject {}

protocol EthenaStakingDetailsViewModel: AnyObject {
    var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)? { get set }
    var didUpdateInformationView: ((TokenDetailsInformationView.Model) -> Void)? { get set }
    var didUpdateDescription: ((NSAttributedString?) -> Void)? { get set }
    var didUpdateLinksViewModel: ((StakingDetailsLinksView.Model?) -> Void)? { get set }
    var didUpdateJettonItemView: ((TKListItemButton.Configuration?) -> Void)? { get set }
    var didUpdateJettonButtonDescription: ((NSAttributedString?, _ actionItems: [TKActionLabel.ActionItem]) -> Void)? { get set }
    var didUpdateButtonsView: ((TokenDetailsHeaderButtonsView.Model?) -> Void)? { get set }
    var didUpdateStakingInfoView: ((EthenaStakingDetailsInfoView.Configuration?) -> Void)? { get set }

    func viewDidLoad()
}

final class EthenaStakingDetailsViewModelImplementation: EthenaStakingDetailsViewModel, EthenaStakingDetailsModuleOutput {
    // MARK: - EthenaStakingDetailsModuleOutput

    var didOpenURL: ((URL) -> Void)?
    var didOpenURLInApp: ((URL) -> Void)?
    var didOpenDapp: ((URL, String?) -> Void)?
    var openJettonDetails: ((Wallet, JettonItem) -> Void)?
    var didTapStake: ((_ wallet: Wallet, _ stakingPoolInfo: StackingPoolInfo) -> Void)?
    var didTapUnstake: ((_ wallet: Wallet, _ stakingPoolInfo: StackingPoolInfo) -> Void)?
    var didTapCollect: ((
        _ wallet: Wallet,
        _ stakingPoolInfo: StackingPoolInfo,
        _ accountStakingInfo: AccountStackingInfo
    ) -> Void)?

    // MARK: - StakingViewModel

    var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)?
    var didUpdateInformationView: ((TokenDetailsInformationView.Model) -> Void)?
    var didUpdateListViewModel: ((StakingDetailsListView.Model) -> Void)?
    var didUpdateDescription: ((NSAttributedString?) -> Void)?
    var didUpdateLinksViewModel: ((StakingDetailsLinksView.Model?) -> Void)?
    var didUpdateJettonItemView: ((TKListItemButton.Configuration?) -> Void)?
    var didUpdateJettonButtonDescription: ((NSAttributedString?, _ actionItems: [TKActionLabel.ActionItem]) -> Void)?
    var didUpdateStakeStateView: ((TKListItemButton.Configuration?) -> Void)?
    var didUpdateButtonsView: ((TokenDetailsHeaderButtonsView.Model?) -> Void)?
    var didUpdateStakingInfoView: ((EthenaStakingDetailsInfoView.Configuration?) -> Void)?

    // MARK: - State

    private let queue = DispatchQueue(label: "EthenaStakingDetailsViewModelImplementationQueue")
    private var ethenaBalance: ProcessedBalanceEthenaItem?

    private lazy var ethenaStakingResponseTask: Task<EthenaStakingResponse?, Never> = Task {
        try? await ethenaStakingLoader.getResponse(reload: false)
    }

    // MARK: - Dependencies

    private let wallet: Wallet
    private let ethenaStakingLoader: EthenaStakingLoader
    private let listViewModelBuilder: StakingListViewModelBuilder
    private let linksViewModelBuilder: StakingLinksViewModelBuilder
    private let balanceItemMapper: BalanceItemMapper
    private let stakingPoolsStore: StakingPoolsStore
    private let balanceStore: ProcessedBalanceStore
    private let tonRatesStore: TonRatesStore
    private let currencyStore: CurrencyStore
    private let appSettingsStore: AppSettingsStore
    private let configuration: Configuration
    private let amountFormatter: AmountFormatter

    // MARK: - Init

    init(
        wallet: Wallet,
        ethenaStakingLoader: EthenaStakingLoader,
        listViewModelBuilder: StakingListViewModelBuilder,
        linksViewModelBuilder: StakingLinksViewModelBuilder,
        balanceItemMapper: BalanceItemMapper,
        stakingPoolsStore: StakingPoolsStore,
        balanceStore: ProcessedBalanceStore,
        tonRatesStore: TonRatesStore,
        currencyStore: CurrencyStore,
        appSettingsStore: AppSettingsStore,
        configuration: Configuration,
        amountFormatter: AmountFormatter
    ) {
        self.wallet = wallet
        self.ethenaStakingLoader = ethenaStakingLoader
        self.listViewModelBuilder = listViewModelBuilder
        self.linksViewModelBuilder = linksViewModelBuilder
        self.balanceItemMapper = balanceItemMapper
        self.stakingPoolsStore = stakingPoolsStore
        self.balanceStore = balanceStore
        self.tonRatesStore = tonRatesStore
        self.currencyStore = currencyStore
        self.appSettingsStore = appSettingsStore
        self.configuration = configuration
        self.amountFormatter = amountFormatter
    }

    func viewDidLoad() {
        didUpdateTitleView?(TKUINavigationBarTitleView.Model(title: "Staked USDe"))
        queue.sync {
            prepareInitialState()
            updateInformation()
            updateLinks()
            updateJettonItemView()
            updateButtons()
            updateStakingInfoView()
        }
    }
}

private extension EthenaStakingDetailsViewModelImplementation {
    func updateLinks() {
        guard isUSDeAvailable else { return }
        Task { @MainActor in
            if let response = await ethenaStakingResponseTask.value {
                let model = linksViewModelBuilder
                    .buildModelEthena(
                        links: response.methods.flatMap { $0.links },
                        openURLInApp: { [weak self] url in
                            self?.didOpenURLInApp?(url)
                        }
                    )
                self.didUpdateLinksViewModel?(model)
            }
        }
    }

    func prepareInitialState() {
        let balance = balanceStore.getState()[wallet]?.balance.ethenaItem
        self.ethenaBalance = balance
    }

    func updateInformation() {
        guard let ethenaBalance else {
            return
        }

        let isSecureMode = appSettingsStore.getState().isSecureMode

        let tokenAmount: String = {
            if isSecureMode {
                return .secureModeValueShort
            } else {
                return amountFormatter.format(
                    amount: ethenaBalance.stakedAmount,
                    fractionDigits: USDe.fractionDigits,
                    accessory: .symbol(USDe.symbol)
                )
            }
        }()

        let convertedAmount: String = {
            if isSecureMode {
                return .secureModeValueShort
            } else {
                return amountFormatter.format(
                    decimal: ethenaBalance.stakedConverted,
                    accessory: .currency(ethenaBalance.currency),
                    style: .compact
                )
            }
        }()

        let imageConfiguration = TKListItemIconView.Configuration(
            content: .image(
                TKImageView.Model(
                    image: .image(.App.Currency.Size64.usde),
                    size: .size(CGSize(width: 64, height: 64)),
                    corners: .circle
                )
            ),
            alignment: .center,
            size: CGSize(width: 64, height: 64),
            badge: TKListItemIconView.Configuration.Badge(
                configuration: TKListItemBadgeView.Configuration(
                    item: .image(.image(.App.Currency.Vector.ethena)),
                    size: .large
                ),
                position: .bottomRight
            )
        )

        let model = TokenDetailsInformationView.Model(
            imageConfiguration: imageConfiguration,
            tokenAmount: tokenAmount,
            convertedAmount: convertedAmount
        )

        DispatchQueue.main.async {
            self.didUpdateInformationView?(model)
        }
    }

    func updateJettonItemView() {
        guard let jetton = ethenaBalance?.stakedUsde else {
            didUpdateJettonItemView?(nil)
            return
        }

        let isSecureMode = appSettingsStore.getState().isSecureMode

        let configuration = balanceItemMapper.mapJettonItem(
            jetton,
            isSecure: isSecureMode,
            isNetworkBadgeVisible: false
        )
        didUpdateJettonItemView?(
            TKListItemButton.Configuration(
                listItemConfiguration: configuration,
                isEnable: true,
                tapClosure: { [weak self] in
                    guard let self else { return }
                    self.openJettonDetails?(self.wallet, jetton.jetton)
                }
            )
        )

        Task { @MainActor in
            if let response = await ethenaStakingResponseTask.value, isUSDeAvailable {
                let actionItems = [TKActionLabel.ActionItem(
                    text: TKLocales.Ethena.aboutEthena,
                    action: { [weak self] in
                        guard let url = URL(string: response.about.aboutUrl) else { return }
                        self?.didOpenURLInApp?(url)
                    }
                )]
                didUpdateJettonButtonDescription?(
                    (response.about.tsusdeDescription + " \(TKLocales.Ethena.aboutEthena)").withTextStyle(
                        .body3,
                        color: .Text.tertiary,
                        alignment: .left,
                        lineBreakMode: .byWordWrapping
                    ),
                    actionItems
                )
            } else {
                didUpdateJettonButtonDescription?(nil, [])
            }
        }
    }

    func updateButtons() {
        Task { @MainActor [weak self] in
            guard let self else { return }

            guard isUSDeAvailable else {
                didUpdateButtonsView?(nil)
                return
            }

            let defaultModel = TokenDetailsHeaderButtonsView.Model(
                buttons: [
                    TokenDetailsHeaderButtonsView.Model.Button(
                        configuration: TKUIIconButton.Model(
                            image: .TKUIKit.Icons.Size28.plusOutline,
                            title: .stakeTitle
                        ),
                        isEnabled: false,
                        action: {}
                    ),
                    TokenDetailsHeaderButtonsView.Model.Button(
                        configuration: TKUIIconButton.Model(
                            image: .TKUIKit.Icons.Size28.minusOutline,
                            title: .unstakeTitle
                        ),
                        isEnabled: false,
                        action: {}
                    ),
                ]
            )
            didUpdateButtonsView?(defaultModel)

            guard let response = await ethenaStakingResponseTask.value,
                  let method = response.methods.first,
                  let stakeUrl = URL(string: method.depositUrl),
                  let widthdrawUrl = URL(string: method.withdrawalUrl)
            else {
                return
            }

            let model = TokenDetailsHeaderButtonsView.Model(
                buttons: [
                    TokenDetailsHeaderButtonsView.Model.Button(
                        configuration: TKUIIconButton.Model(
                            image: .TKUIKit.Icons.Size28.plusOutline,
                            title: .stakeTitle
                        ),
                        isEnabled: wallet.isStakeEnable,
                        action: { [weak self] in
                            self?.didOpenDapp?(stakeUrl, method.name)
                        }
                    ),
                    TokenDetailsHeaderButtonsView.Model.Button(
                        configuration: TKUIIconButton.Model(
                            image: .TKUIKit.Icons.Size28.minusOutline,
                            title: .unstakeTitle
                        ),
                        isEnabled: wallet.isStakeEnable,
                        action: { [weak self] in
                            self?.didOpenDapp?(widthdrawUrl, method.name)
                        }
                    ),
                ]
            )
            didUpdateButtonsView?(model)
        }
    }

    func updateStakingInfoView() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard isUSDeAvailable else {
                self.didUpdateStakingInfoView?(nil)
                return
            }

            if let response = await ethenaStakingResponseTask.value,
               let method = response.methods.first
            {
                let configuration = EthenaStakingDetailsInfoView.Configuration(
                    apyTitle: method.apyTitle,
                    apyDescription: method.apyDescription,
                    apyValue: "\(method.apy)%",
                    boostTitle: method.apyBonusTitle,
                    boostDescription: method.apyBonusDescription,
                    faqButtonModel: TKPlainButton.Model(
                        title: "FAQ".withTextStyle(
                            .body2,
                            color: .Text.accent
                        ),
                        action: { [weak self] in
                            guard let faqURL = URL(string: response.about.faqUrl) else { return }
                            self?.didOpenURLInApp?(faqURL)
                        }
                    ),
                    checkEligibilityButtonModel: TKPlainButton.Model(
                        title: TKLocales.Ethena.checkEligibility.withTextStyle(
                            .body2,
                            color: .Text.accent
                        ),
                        action: { [weak self] in
                            guard let eligibleBonusUrl = URL(string: method.eligibleBonusUrl) else { return }
                            self?.didOpenURLInApp?(eligibleBonusUrl)
                        }
                    )
                )
                self.didUpdateStakingInfoView?(configuration)
            } else {
                self.didUpdateStakingInfoView?(nil)
            }
        }
    }

    private var isUSDeAvailable: Bool {
        !configuration.flag(\.usdeDisabled, network: wallet.network)
    }
}

private extension String {
    static let mostProfitableTag = TKLocales.maxApy
    static let apy = TKLocales.apy
    static let minimalDeposit = TKLocales.StakingBalanceDetails.minimalDeposit
    static let description = TKLocales.StakingBalanceDetails.description
    static let pendingStakeTitle = TKLocales.StakingBalanceDetails.pendingStake
    static let pendingUntakeTitle = TKLocales.StakingBalanceDetails.pendingUnstake
    static let unstakeReadyTitle = TKLocales.StakingBalanceDetails.unstakeReady
    static let afterTheEndOfTheCycle = TKLocales.StakingBalanceDetails.afterEndOfCycle
    static let tapToCollect = TKLocales.StakingBalanceDetails.tapToCollect
    static let stakeTitle = TKLocales.StakingBalanceDetails.stake
    static let unstakeTitle = TKLocales.StakingBalanceDetails.unstake
}

private extension CGSize {
    static let iconSize = CGSize(width: 44, height: 44)
    static let badgeIconSize = CGSize(width: 24, height: 24)
}
