import BigInt
import Foundation
import KeeperCore
import TKLocalize
import TKUIKit

final class EthenaDetailsConfigurator: TokenDetailsConfigurator {
    var didSelectJetton: ((JettonItem) -> Void)?
    var didOpenURL: ((URL) -> Void)?
    var didOpenDapp: ((URL, String?) -> Void)?
    var didSelectStakingEthena: (() -> Void)?

    var didUpdate: (() -> Void)?

    enum State {
        case idle
        case loading
        case loaded(EthenaStakingResponse)

        var ethenaStakingResponse: EthenaStakingResponse? {
            guard case let .loaded(response) = self else {
                return nil
            }
            return response
        }
    }

    @Atomic private var state: State = .idle {
        didSet {
            didUpdate?()
        }
    }

    private let wallet: Wallet
    private let mapper: TokenDetailsMapper
    private let configuration: Configuration
    private let ethenaStakingLoader: EthenaStakingLoader
    private let balanceItemMapper: BalanceItemMapper
    private let amountFormatter: AmountFormatter

    init(
        wallet: Wallet,
        mapper: TokenDetailsMapper,
        configuration: Configuration,
        ethenaStakingLoader: EthenaStakingLoader,
        balanceItemMapper: BalanceItemMapper,
        amountFormatter: AmountFormatter
    ) {
        self.wallet = wallet
        self.mapper = mapper
        self.configuration = configuration
        self.ethenaStakingLoader = ethenaStakingLoader
        self.balanceItemMapper = balanceItemMapper
        self.amountFormatter = amountFormatter
    }

    func viewDidLoad() {
        state = .loading
        Task { @MainActor in
            do {
                let response = try await ethenaStakingLoader.getResponse(reload: true)
                state = .loaded(response)
            } catch {
                state = .idle
            }
        }
    }

    func reload() {
        Task { @MainActor in
            do {
                let response = try await ethenaStakingLoader.getResponse(reload: true)
                state = .loaded(response)
            } catch {
                state = .idle
            }
        }
    }

    func getTokenModel(balance: ProcessedBalance?, isSecureMode: Bool) -> TokenDetailsModel {
        let balance = balance?.ethenaItem

        let usdeJettonItem: JettonItem = balance?.usdeJettonItem ?? .usde

        var buttons = [
            TokenDetailsModel.Button(
                iconButton: .send(.ton(.jetton(usdeJettonItem))),
                isEnable: balance?.usde?.amount.isZero == false
            ),
            TokenDetailsModel.Button(
                iconButton: .receive(.ton(.jetton(usdeJettonItem))),
                isEnable: true
            ),
        ]

        if isSwapAvailable && isUSDeAvailable {
            buttons.append(
                TokenDetailsModel.Button(
                    iconButton: .swap(.ton(.jetton(usdeJettonItem))),
                    isEnable: wallet.isSwapEnable
                )
            )
        }

        let tokenAmount: String
        var convertedAmount: String?
        if isSecureMode {
            tokenAmount = .secureModeValueShort
            convertedAmount = .secureModeValueShort
        } else {
            (tokenAmount, convertedAmount) = mapper.mapEphenaBalance(balance: balance)
        }

        let bannerItems = getBannerItems(balance: balance)

        return TokenDetailsModel(
            title: USDe.symbol,
            caption: nil,
            image: .image(.App.Currency.Size64.usde),
            network: .none,
            tokenAmount: tokenAmount,
            convertedAmount: convertedAmount,
            buttons: buttons,
            bannerItems: bannerItems
        )
    }

    func getDetailsURL() -> URL? {
        guard let string = try? "\(String.tonviewer)/\(wallet.friendlyAddress.toString())/jetton/\(JettonMasterAddress.USDe.toString())",
              let url = URL(string: string) else { return nil }
        return url
    }

    private func getBannerItems(balance: ProcessedBalanceEthenaItem?) -> [TokenDetailsBannerItem] {
        var banners = [TokenDetailsBannerItem]()
        if let balanceBannerItem = getBalanceBannerItem(balance: balance) {
            banners.append(balanceBannerItem)
        }

        if let providersBannerItem = getStakingProvidersBannerItem() {
            banners.append(providersBannerItem)
        }

        if let aboutBannerItem = getAboutBannerItem() {
            banners.append(aboutBannerItem)
        }

        return banners
    }

    private func getBalanceBannerItem(balance: ProcessedBalanceEthenaItem?) -> TokenDetailsBannerItem? {
        guard let balance else { return nil }

        let usdeBalanceConfiguration: TKListItemButton.Configuration = TKListItemButton.Configuration(
            listItemConfiguration: mapUSDeListItemConfiguration(balance: balance),
            isEnable: true,
            tapClosure: { [weak self] in
                self?.didSelectJetton?(balance.usdeJettonItem)
            }
        )

        var stakingBalanceConfiguration: TKListItemButton.Configuration?
        if isUSDeAvailable || balance.stakedUsde?.amount.isZero == false {
            stakingBalanceConfiguration = TKListItemButton.Configuration(
                listItemConfiguration: mapEthenaStakingListItemConfiguration(balance: balance),
                isEnable: true,
                tapClosure: { [weak self] in
                    self?.didSelectStakingEthena?()
                }
            )
        }

        return TokenDetailsEthenaBalanceView.Configuration(
            usdeBalanceConfiguration: usdeBalanceConfiguration,
            stakingBalanceConfiguration: stakingBalanceConfiguration
        )
    }

    private func getStakingProvidersBannerItem() -> TokenDetailsBannerItem? {
        guard isUSDeAvailable else { return nil }
        guard let ethenaStakingResponse = state.ethenaStakingResponse,
              !ethenaStakingResponse.methods.isEmpty else { return nil }

        return TokenDetailsEthenaStakingProvidersView.Configuration(
            providersConfigurations: ethenaStakingResponse.methods.map {
                mapStakingMethodConfiguration(method: $0)
            }
        )
    }

    private func getAboutBannerItem() -> TokenDetailsBannerItem? {
        guard isUSDeAvailable else { return nil }
        guard let ethenaStakingResponse = state.ethenaStakingResponse else { return nil }

        return TokenDetailsEthenaAboutView.Configuration(
            description: ethenaStakingResponse.about.description + " \(TKLocales.Ethena.aboutEthena)",
            actionItems: [TKActionLabel.ActionItem(
                text: TKLocales.Ethena.aboutEthena,
                action: { [weak self] in
                    guard let url = URL(string: ethenaStakingResponse.about.aboutUrl) else { return }
                    self?.didOpenURL?(url)
                }
            )]
        )
    }

    private func mapUSDeListItemConfiguration(balance: ProcessedBalanceEthenaItem) -> TKListItemContentView.Configuration {
        let item = balance.usde
        let title = item?.jetton.jettonInfo.symbol ?? USDe.symbol
        let currency = item?.currency ?? balance.currency
        let subtitle = balanceItemMapper.createPriceSubtitle(
            price: item?.price ?? 0,
            currency: currency,
            diff: item?.diff,
            isUnverified: false
        )

        let formatConvertedAmount = { [amountFormatter] in
            amountFormatter.format(
                decimal: item?.converted ?? 0,
                accessory: .currency(currency),
                style: .compact
            )
        }

        let formatAmount = { [amountFormatter] in
            amountFormatter.format(
                amount: item?.amount ?? 0,
                fractionDigits: item?.fractionalDigits ?? USDe.fractionDigits
            )
        }

        let value = formatConvertedAmount().withTextStyle(
            .label1,
            color: .Text.primary,
            alignment: .right,
            lineBreakMode: .byTruncatingTail
        )

        let valueCaption = formatAmount().withTextStyle(
            .body2,
            color: .Text.secondary,
            alignment: .right,
            lineBreakMode: .byTruncatingTail
        )

        return TKListItemContentView.Configuration(
            iconViewConfiguration: .ethenaConfiguration(),
            textContentViewConfiguration: TKListItemTextContentView
                .Configuration(
                    titleViewConfiguration: TKListItemTitleView.Configuration(title: title),
                    captionViewsConfigurations: [TKListItemTextView.Configuration(text: subtitle)],
                    valueViewConfiguration: TKListItemTextView.Configuration(text: value),
                    valueCaptionViewConfiguration: TKListItemTextView.Configuration(text: valueCaption)
                )
        )
    }

    private func mapEthenaStakingListItemConfiguration(balance: ProcessedBalanceEthenaItem) -> TKListItemContentView.Configuration {
        let item = balance.stakedUsde
        let title = StakedUSDe.name
        let currency = balance.currency

        let subtitle: String? = {
            if let response = state.ethenaStakingResponse, isUSDeAvailable {
                return response.about.tsusdeStakeDescription
            } else {
                return "Ethena"
            }
        }()

        var captionViewsConfigurations = [TKListItemTextView.Configuration]()
        if let subtitle {
            captionViewsConfigurations.append(
                TKListItemTextView.Configuration(
                    text: subtitle.withTextStyle(.body2, color: .Text.secondary)
                )
            )
        }

        let formatConvertedAmount = { [amountFormatter] in
            amountFormatter.format(
                decimal: balance.stakedConverted,
                accessory: .currency(currency),
                style: .compact
            )
        }

        let formatAmount = { [amountFormatter] in
            amountFormatter.format(
                amount: balance.stakedAmount,
                fractionDigits: item?.fractionalDigits ?? USDe.fractionDigits
            )
        }

        let value = formatConvertedAmount().withTextStyle(
            .label1,
            color: .Text.primary,
            alignment: .right,
            lineBreakMode: .byTruncatingTail
        )

        let valueCaption = formatAmount().withTextStyle(
            .body2,
            color: .Text.secondary,
            alignment: .right,
            lineBreakMode: .byTruncatingTail
        )

        return TKListItemContentView.Configuration(
            iconViewConfiguration: TKListItemIconView.Configuration(
                content: .image(TKImageView.Model(
                    image: .image(.App.Currency.Size44.usde),
                    size: .size(CGSize(width: 44, height: 44)),
                    corners: .circle
                )),
                alignment: .center,
                cornerRadius: 22,
                backgroundColor: .Background.contentTint,
                size: CGSize(width: 44, height: 44),
                badge: TKListItemIconView.Configuration.Badge(
                    configuration: TKListItemBadgeView.Configuration(
                        item: .image(.image(.App.Currency.Vector.ethena)),
                        size: .small
                    ),
                    position: .bottomRight
                )
            ),
            textContentViewConfiguration: TKListItemTextContentView
                .Configuration(
                    titleViewConfiguration: TKListItemTitleView.Configuration(title: title),
                    captionViewsConfigurations: captionViewsConfigurations,
                    valueViewConfiguration: TKListItemTextView.Configuration(text: value),
                    valueCaptionViewConfiguration: TKListItemTextView.Configuration(text: valueCaption)
                )
        )
    }

    private func mapStakingMethodConfiguration(method: EthenaStakingMethod) -> TKListItemButton.Configuration {
        let action = { [weak self] in
            guard let url = URL(string: method.depositUrl) else { return }
            self?.didOpenDapp?(url, method.name)
        }

        return TKListItemButton.Configuration(
            listItemConfiguration: TKListItemContentView.Configuration(
                iconViewConfiguration: TKListItemIconView.Configuration(
                    content: .image(TKImageView.Model(
                        image: .urlImage(method.image),
                        size: .size(CGSize(width: 44, height: 44)),
                        corners: .cornerRadius(cornerRadius: 12)
                    )),
                    alignment: .center,
                    cornerRadius: 12,
                    backgroundColor: .Background.contentTint,
                    size: CGSize(width: 44, height: 44)
                ),
                textContentViewConfiguration: TKListItemTextContentView
                    .Configuration(
                        titleViewConfiguration: TKListItemTitleView.Configuration(title: TKLocales.Ethena.depositAndStake),
                        captionViewsConfigurations: [
                            TKListItemTextView.Configuration(
                                text: "\(TKLocales.Ethena.operatedBy(method.name))".withTextStyle(
                                    .body2,
                                    color: .Text.secondary
                                )
                            ),
                        ]
                    )
            ),
            accessory:
            .button(TKListItemButtonAccessoryView.Configuration(title: TKLocales.Actions.open, category: .tertiary, action: {
                action()
            })),
            isEnable: true,
            tapClosure: {
                action()
            }
        )
    }

    private var isUSDeAvailable: Bool {
        !configuration.flag(\.usdeDisabled, network: wallet.network)
    }

    private var isSwapAvailable: Bool {
        !configuration.flag(\.isSwapDisable, network: wallet.network)
    }
}
