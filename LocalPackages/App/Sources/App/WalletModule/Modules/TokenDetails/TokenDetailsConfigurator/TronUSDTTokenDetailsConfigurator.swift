import KeeperCore
import TKLocalize
import TKUIKit
import TronSwift
import UIKit

final class TronUSDTTokenDetailsConfigurator: TokenDetailsConfigurator {
    var didUpdate: (() -> Void)?
    var didTapBanner: ((TronUsdtFeesSnapshot) -> Void)?
    var didTapTransfersAvailable: ((TronUsdtFeesSnapshot) -> Void)?

    private let wallet: Wallet
    private let mapper: TokenDetailsMapper
    private let configuration: Configuration
    private let feesSnapshotService: TronUsdtFeesService
    private let buySellMethodsService: BuySellMethodsService
    private let amountFormatter: AmountFormatter

    private enum State {
        case idle
        case loading
        case loaded(swapURL: URL?)
    }

    @Atomic private var state: State = .idle {
        didSet {
            didUpdate?()
        }
    }

    init(
        wallet: Wallet,
        mapper: TokenDetailsMapper,
        configuration: Configuration,
        feesSnapshotService: TronUsdtFeesService,
        amountFormatter: AmountFormatter,
        buySellMethodsService: BuySellMethodsService
    ) {
        self.wallet = wallet
        self.mapper = mapper
        self.configuration = configuration
        self.feesSnapshotService = feesSnapshotService
        self.amountFormatter = amountFormatter
        self.buySellMethodsService = buySellMethodsService

        feesSnapshotService.addUpdateObserver(self) { observer, updatedWallet in
            guard updatedWallet == observer.wallet else { return }
            observer.didUpdate?()
        }
    }

    func viewDidLoad() {
        state = .loading
        load()
    }

    func reload() {
        load()
    }

    private func load() {
        Task { @MainActor in
            do {
                async let swapUrl = loadSwapURL()
                async let refresh: Void = feesSnapshotService.refresh(wallet: wallet)

                let swapURL = try await swapUrl
                _ = await refresh
                state = .loaded(swapURL: swapURL)
            } catch {
                state = .idle
            }
        }
    }

    private func loadSwapURL() async throws -> URL? {
        let methods = try await buySellMethodsService.loadFiatMethods(countryCode: nil)

        if Task.isCancelled { return nil }

        return methods.buy
            .flatMap(\.items)
            .first(where: { $0.id == "letsexchange_buy_swap" })
            .flatMap { URL(string: $0.actionButton.url) }
    }

    func getTokenModel(balance: ProcessedBalance?, isSecureMode: Bool) -> TokenDetailsModel {
        let usdtBalance = balance?.tronUSDTItem
        let amount = usdtBalance?.amount ?? 0

        var buttons = [
            TokenDetailsModel.Button(
                iconButton: .send(.tron(.usdt)),
                isEnable: wallet.isSendAvailable && amount > 0
            ),
            TokenDetailsModel.Button(
                iconButton: .receive(.tron(.usdt)),
                isEnable: true
            ),
        ]

        if
            !configuration.flag(\.isSwapDisable, network: wallet.network),
            case let .loaded(swapURL) = state, swapURL != nil
        {
            buttons.append(TokenDetailsModel.Button(
                iconButton: .swap(.tron(.usdt)),
                isEnable: true
            ))
        }

        let tokenAmount: String
        let convertedAmount: String?
        if isSecureMode {
            tokenAmount = .secureModeValueShort
            convertedAmount = .secureModeValueShort
        } else {
            let amount = mapper.mapBalance(
                amount: amount,
                converted: usdtBalance?.converted ?? 0,
                fractionDigits: TronSwift.USDT.fractionDigits,
                symbol: TronSwift.USDT.symbol,
                currency: balance?.currency ?? .USD
            )
            tokenAmount = amount.tokenAmount
            convertedAmount = amount.convertedAmount
        }

        let feesSnapshot = makeFeesSnapshot(balance: balance)

        let bannerItems: [TokenDetailsBannerItem] = feesSnapshot
            .map { snapshot in
                guard !snapshot.hasEnoughForAtLeastOneTransfer else {
                    return []
                }
                if snapshot.isTRXOnlyRegion {
                    return [
                        TokenDetailsTRC20FeesBannerView.Configuration(
                            title: TKLocales.TronUsdtFees.TokenDetails.Banners.TrxInsufficient.title,
                            caption: TKLocales.TronUsdtFees.TokenDetails.Banners.TrxInsufficient.caption(
                                amountFormatter.format(
                                    amount: snapshot.requiredTRX,
                                    fractionDigits: TRX.fractionDigits,
                                    accessory: .none
                                ),
                                amountFormatter.format(
                                    amount: snapshot.trxBalance,
                                    fractionDigits: TRX.fractionDigits,
                                    accessory: .none
                                )
                            ),
                            buttonTitle: TKLocales.TronUsdtFees.Common.Buttons.getTrx,
                            style: .trx,
                            action: { [weak self] in
                                self?.didTapBanner?(snapshot)
                            }
                        ),
                    ]
                } else {
                    return [
                        TokenDetailsTRC20FeesBannerView.Configuration(
                            title: TKLocales.TronUsdtFees.TokenDetails.Banners.FeeOptionsInsufficient.title,
                            caption: TKLocales.TronUsdtFees.TokenDetails.Banners.FeeOptionsInsufficient.caption,
                            buttonTitle: TKLocales.TronUsdtFees.Common.Buttons.allFeeOptions,
                            style: .battery,
                            action: { [weak self] in
                                self?.didTapBanner?(snapshot)
                            }
                        ),
                    ]
                }
            } ?? []

        let transferAvailability: TokenDetailsModel.TransferAvailability? = feesSnapshot
            .flatMap { feesSnapshot in
                guard feesSnapshot.hasEnoughForAtLeastOneTransfer else {
                    return nil
                }
                return TokenDetailsModel.TransferAvailability(
                    text: TKLocales.TronUsdtFees.TokenDetails.transferAvailability(
                        feesSnapshot.totalTransfersAvailable
                    ),
                    action: { [weak self] in
                        self?.didTapTransfersAvailable?(feesSnapshot)
                    }
                )
            }

        return TokenDetailsModel(
            title: "Tether USD",
            caption: TokenDetailsModel.Caption(
                text: TronSwift.USDT.tag.withTextStyle(.body2, color: .Text.secondary, alignment: .center),
                action: nil
            ),
            image: .image(.App.Currency.Size96.usdt),
            network: .trc20,
            tokenAmount: tokenAmount,
            convertedAmount: convertedAmount,
            transferAvailability: transferAvailability,
            buttons: buttons,
            bannerItems: bannerItems
        )
    }

    func getDetailsURL() -> URL? {
        let string = "\(String.tronscan)/\(TronSwift.USDT.address.base58)"
        guard let url = URL(string: string) else { return nil }
        return url
    }

    func insufficientTrxSheetConfiguration(
        for snapshot: TronUsdtFeesSnapshot,
        onGetTrx: @escaping () -> Void
    ) -> InfoPopupBottomSheetViewController.Configuration {
        let getTrxButton = {
            var button = TKButton.Configuration.actionButtonConfiguration(
                category: .secondary,
                size: .large
            )
            button.content = .init(title: .plainString(TKLocales.TronUsdtFees.Common.Buttons.getTrx))
            button.action = onGetTrx
            return button
        }()
        return InfoPopupBottomSheetViewController.Configuration(
            image: .TKUIKit.Icons.Size84.exclamationmarkCircle,
            imageTintColor: .Icon.secondary,
            title: TKLocales.TronUsdtFees.InsufficientPopup.title,
            caption: TKLocales.TronUsdtFees.InsufficientPopup.caption(
                amountFormatter.format(
                    amount: snapshot.requiredTRX,
                    fractionDigits: TRX.fractionDigits,
                    accessory: .none
                ),
                amountFormatter.format(
                    amount: snapshot.trxBalance,
                    fractionDigits: TRX.fractionDigits,
                    accessory: .none
                )
            ),
            bodyContent: nil,
            buttons: [getTrxButton]
        )
    }

    private func makeFeesSnapshot(balance: ProcessedBalance?) -> TronUsdtFeesSnapshot? {
        feesSnapshotService.snapshot(wallet: wallet, balance: balance)
    }
}
