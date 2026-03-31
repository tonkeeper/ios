import BigInt
import KeeperCore
import Mapping
import TKLocalize
import TKUIKit
import UIComponents
import UIKit

public struct SignRawConfirmationModel {
    struct Risk {
        let total: String
        let title: String
        let caption: String
        let isRisk: Bool
    }

    let contentModel: AccountEventCellContentView.Model
    let risk: Risk?
}

struct SignRawConfirmationMapper {
    private let nftService: NFTService
    private let tonRatesStore: TonRatesStore
    private let currencyStore: CurrencyStore
    private let totalBalanceStore: TotalBalanceStore
    private let nftManagmentStore: WalletNFTsManagementStore
    private let accountEventMapper: AccountEventMapper
    private let accountEventModelMapper: Mapping.AccountEventModelMapper
    private let amountFormatter: AmountFormatter

    init(
        nftService: NFTService,
        tonRatesStore: TonRatesStore,
        currencyStore: CurrencyStore,
        totalBalanceStore: TotalBalanceStore,
        nftManagmentStore: WalletNFTsManagementStore,
        accountEventMapper: AccountEventMapper,
        accountEventModelMapper: Mapping.AccountEventModelMapper,
        amountFormatter: AmountFormatter
    ) {
        self.nftService = nftService
        self.tonRatesStore = tonRatesStore
        self.currencyStore = currencyStore
        self.totalBalanceStore = totalBalanceStore
        self.nftManagmentStore = nftManagmentStore
        self.accountEventMapper = accountEventMapper
        self.accountEventModelMapper = accountEventModelMapper
        self.amountFormatter = amountFormatter
    }

    func mapEmulationResult(emulation: SignRawEmulation, wallet: Wallet) -> SignRawConfirmationModel {
        SignRawConfirmationModel(
            contentModel: mapSuccessEmulationResult(signRawEmulation: emulation, wallet: wallet),
            risk: mapRisk(emulation: emulation, wallet: wallet)
        )
    }

    func mapSuccessEmulationResult(signRawEmulation: SignRawEmulation, wallet: Wallet) -> AccountEventCellContentView.Model {
        let currency = currencyStore.getState()
        let tonRate = tonRatesStore.state.tonRates.first(where: { $0.currency == currency })

        let descriptionProvider = SignRawConfirmationAccountEventRightTopDescriptionProvider(
            rates: tonRate,
            currency: currency,
            formatter: amountFormatter
        )

        let eventModel = accountEventMapper.mapEvent(
            signRawEmulation.event,
            nftManagmentStore: nftManagmentStore,
            eventDate: Date(),
            accountEventRightTopDescriptionProvider: descriptionProvider,
            network: wallet.network,
            nftProvider: { address in
                try? self.nftService.getNFT(address: address, network: wallet.network)
            },
            decryptedCommentProvider: { _ in nil }
        )

        let feeFormatted = "\(String.Symbol.almostEqual)\(String.Symbol.shortSpace)"
            + amountFormatter.format(
                amount: BigUInt(signRawEmulation.fee),
                fractionDigits: TonInfo.fractionDigits,
                accessory: .currency(Currency.TON),
                isNegative: false,
                style: .compact
            )
        var feeConverted: String?
        if let tonRate {
            let converted = RateConverter().convert(
                amount: BigUInt(signRawEmulation.fee),
                amountFractionLength: TonInfo.fractionDigits,
                rate: tonRate
            )
            feeConverted = amountFormatter.format(
                amount: converted.amount,
                fractionDigits: converted.fractionLength,
                accessory: .currency(currency)
            )
        }

        return accountEventModelMapper.mapSignRawEventContentConfiguration(
            eventModel,
            fee: feeFormatted,
            feeConverted: feeConverted,
            feeDescription: signRawEmulation.transferType.isBattery ? TKLocales.TransactionConfirmation.battery : nil
        )
    }

    func mapRisk(emulation: SignRawEmulation, wallet: Wallet) -> SignRawConfirmationModel.Risk? {
        guard
            let totalBalanceState = totalBalanceStore.state[wallet],
            let totalBalance = totalBalanceState.totalBalance,
            let total = emulation.risk.totalEquivalent.flatMap(Decimal.init(floatLiteral:))
        else {
            return nil
        }

        let totalString = amountFormatter.format(
            decimal: total,
            accessory: .currency(currencyStore.state),
            style: .compact
        )

        let riskThreshold = totalBalance.amount * emulation.risk.totalAmountTreshold
        let isRisk = total >= riskThreshold

        let title: String
        let caption: String
        switch emulation.risk.nftsCount {
        case 1:
            title = TKLocales.ConfirmSend.Risk.totalNft(totalString, emulation.risk.nftsCount)
            caption = TKLocales.ConfirmSend.Risk.nftCaption
        case let count where count > 1:
            title = TKLocales.ConfirmSend.Risk.totalNftMultiple(totalString, emulation.risk.nftsCount)
            caption = TKLocales.ConfirmSend.Risk.nftMultipleCaption
        default:
            title = TKLocales.ConfirmSend.Risk.total(totalString)
            caption = TKLocales.ConfirmSend.Risk.captionWithoutNft
        }

        return SignRawConfirmationModel.Risk(
            total: totalString,
            title: title,
            caption: caption,
            isRisk: isRisk
        )
    }
}
