import KeeperCore
import TKFeatureFlags
import TKUIKit
import TronSwift
import UIKit

final class TronUSDTTokenDetailsConfigurator: TokenDetailsConfigurator {
    var didUpdate: (() -> Void)?
    var didTapChargeBattery: (() -> Void)?

    private let wallet: Wallet
    private let mapper: TokenDetailsMapper
    private let batteryCalculation: BatteryCalculation
    private let configuration: Configuration
    private let buySellMethodsService: BuySellMethodsService

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
        batteryCalculation: BatteryCalculation,
        configuration: Configuration,
        buySellMethodsService: BuySellMethodsService
    ) {
        self.wallet = wallet
        self.mapper = mapper
        self.batteryCalculation = batteryCalculation
        self.configuration = configuration
        self.buySellMethodsService = buySellMethodsService
    }

    func viewDidLoad() {
        state = .loading
        Task { @MainActor in
            do {
                state = try .loaded(swapURL: await loadSwapURL())
            } catch {
                state = .idle
            }
        }
    }

    func reload() {
        Task { @MainActor in
            do {
                state = try .loaded(swapURL: await loadSwapURL())
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
                iconButton: .send(.usdtTron),
                isEnable: wallet.isSendAvailable && amount > 0
            ),
            TokenDetailsModel.Button(
                iconButton: .receive(.usdtTron),
                isEnable: true
            ),
        ]

        if
            !configuration.flag(\.isSwapDisable, network: wallet.network),
            case let .loaded(swapURL) = state, swapURL != nil
        {
            buttons.append(TokenDetailsModel.Button(
                iconButton: .swap(.usdtTron),
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

        var bannerItems = [TokenDetailsBannerItem]()
        var batteryCharges = 0
        if let batteryBalance = balance?.batteryBalance, !batteryBalance.isBalanceZero,
           let charges = batteryCalculation.calculateCharges(tonAmount: batteryBalance.balanceDecimalNumber)
        {
            batteryCharges = charges
        }
        if batteryCharges < 300 {
            bannerItems.append(TokenDetailsTRC20BatteryBannerView.Configuration(chargeButtonAction: {
                self.didTapChargeBattery?()
            }))
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
            buttons: buttons,
            bannerItems: bannerItems
        )
    }

    func getDetailsURL() -> URL? {
        let string = "\(String.tronscan)/\(TronSwift.USDT.address.base58)"
        guard let url = URL(string: string) else { return nil }
        return url
    }
}
