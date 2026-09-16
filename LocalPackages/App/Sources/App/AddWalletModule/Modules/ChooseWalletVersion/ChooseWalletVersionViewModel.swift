import BigInt
import Combine
import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit

@MainActor
protocol ChooseWalletVersionModuleOutput: AnyObject {
    var didSelectWallet: ((ActiveWalletModel) -> Void)? { get set }
}

@MainActor
protocol ChooseWalletVersionModuleInput: AnyObject {
    func resetContinueImport()
    func clearContinueLoader()
}

struct ChooseWalletVersionWalletRow: Identifiable {
    let id: String
    let wallet: ActiveWalletModel
    let title: String
    let subtitle: String
    let tags: [TKTagSwiftUIViewConfig]
}

@MainActor
final class ChooseWalletVersionViewModel: ObservableObject, ChooseWalletVersionModuleOutput, ChooseWalletVersionModuleInput {
    @Published private(set) var rows: [ChooseWalletVersionWalletRow] = []
    @Published private(set) var selectedWalletID: String
    @Published private(set) var isContinueInProgress = false
    @Published private(set) var showsContinueLoader = false

    var didSelectWallet: ((ActiveWalletModel) -> Void)?

    private let wallets: [ActiveWalletModel]
    private let amountFormatter: AmountFormatter
    private let network: Network
    private let tonRate: Rates.Rate?
    private let currency: Currency

    init(
        wallets: [ActiveWalletModel],
        amountFormatter: AmountFormatter,
        network: Network,
        tonRate: Rates.Rate?,
        currency: Currency
    ) {
        let sortedWallets = wallets.sorted { $0.revision > $1.revision }
        self.wallets = sortedWallets
        self.amountFormatter = amountFormatter
        self.network = network
        self.tonRate = tonRate
        self.currency = currency
        self.selectedWalletID = sortedWallets.first(where: { $0.revision == .v5R1 })?.id
            ?? sortedWallets.first?.id
            ?? ""
        self.rows = sortedWallets.map { Self.makeRow(
            wallet: $0,
            amountFormatter: amountFormatter,
            network: network,
            tonRate: tonRate,
            currency: currency
        ) }
    }

    func selectWallet(id: String) {
        guard !isContinueInProgress, selectedWalletID != id else { return }
        selectedWalletID = id
    }

    func continueImport() {
        guard !isContinueInProgress,
              let wallet = wallets.first(where: { $0.id == selectedWalletID })
        else { return }
        isContinueInProgress = true
        showsContinueLoader = true
        didSelectWallet?(wallet)
    }

    func resetContinueImport() {
        isContinueInProgress = false
        showsContinueLoader = false
    }

    func clearContinueLoader() {
        showsContinueLoader = false
    }

    func isSelected(_ row: ChooseWalletVersionWalletRow) -> Bool {
        row.id == selectedWalletID
    }
}

private extension ChooseWalletVersionViewModel {
    static func makeRow(
        wallet: ActiveWalletModel,
        amountFormatter: AmountFormatter,
        network: Network,
        tonRate: Rates.Rate?,
        currency: Currency
    ) -> ChooseWalletVersionWalletRow {
        let title = wallet.address.toShortString(bounceable: false, isTestonly: network == .testnet)
        let balanceText = formatFiatBalance(
            wallet: wallet,
            amountFormatter: amountFormatter,
            tonRate: tonRate,
            currency: currency
        )
        let subtitle: String
        if wallet.nfts.isEmpty {
            subtitle = balanceText
        } else {
            subtitle = "\(balanceText) · \(TKLocales.ChooseWalletVersion.nftsCount(wallet.nfts.count))"
        }

        var tags = [TKTagSwiftUIViewConfig]()
        switch wallet.revision {
        case .v5R1:
            tags.append(.accentTag(
                text: "W5 · \(TKLocales.Ramp.InsertAmount.bestBadge)",
                accent: .accentGreen
            ))
        case .v4R2:
            tags.append(.tag(text: "V4R2"))
        default:
            break
        }

        return ChooseWalletVersionWalletRow(
            id: wallet.id,
            wallet: wallet,
            title: title,
            subtitle: subtitle,
            tags: tags
        )
    }

    static func formatFiatBalance(
        wallet: ActiveWalletModel,
        amountFormatter: AmountFormatter,
        tonRate: Rates.Rate?,
        currency: Currency
    ) -> String {
        guard let tonRate else {
            return amountFormatter.format(
                amount: BigUInt(integerLiteral: UInt64(max(wallet.balance.tonBalance.amount, 0))),
                fractionDigits: TonInfo.fractionDigits,
                accessory: .tokenSymbol(TonInfo.name)
            )
        }

        return amountFormatter.format(
            decimal: calculateFiatTotal(wallet: wallet, tonRate: tonRate, currency: currency),
            accessory: .fiat(currency),
            style: .fiatBalance
        )
    }

    static func calculateFiatTotal(
        wallet: ActiveWalletModel,
        tonRate: Rates.Rate?,
        currency: Currency
    ) -> Decimal {
        var total: Decimal = 0
        let rateConverter = RateConverter()

        if let tonRate {
            total += rateConverter.convertToDecimal(
                amount: BigUInt(integerLiteral: UInt64(max(wallet.balance.tonBalance.amount, 0))),
                amountFractionLength: TonInfo.fractionDigits,
                rate: tonRate
            )
        }

        for jettonBalance in wallet.balance.jettonsBalance {
            guard !jettonBalance.quantity.isZero,
                  jettonBalance.item.jettonInfo.verification != .blacklist,
                  let rate = jettonBalance.rates[currency]
            else {
                continue
            }
            total += rateConverter.convertToDecimal(
                amount: jettonBalance.quantity,
                amountFractionLength: jettonBalance.item.jettonInfo.fractionDigits,
                rate: rate
            )
        }

        return total
    }
}
