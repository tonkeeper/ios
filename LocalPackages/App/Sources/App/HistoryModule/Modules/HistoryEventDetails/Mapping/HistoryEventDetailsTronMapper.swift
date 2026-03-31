import BigInt
import KeeperCore
import TKLocalize
import TKUIKit
import TronSwift
import UIKit

final class HistoryEventDetailsTronMapper {
    private let wallet: Wallet
    private let amountFormatter: AmountFormatter
    private let tonRatesStore: TonRatesStore
    private let currencyStore: CurrencyStore
    private let network: Network
    private let configuration: Configuration

    private let rateConverter = RateConverter()
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "d MMM, HH:mm"
        return formatter
    }()

    init(
        wallet: Wallet,
        amountFormatter: AmountFormatter,
        tonRatesStore: TonRatesStore,
        currencyStore: CurrencyStore,
        network: Network,
        configuration: Configuration
    ) {
        self.wallet = wallet
        self.amountFormatter = amountFormatter
        self.tonRatesStore = tonRatesStore
        self.currencyStore = currencyStore
        self.network = network
        self.configuration = configuration
    }

    func mapEvent(event: TronTransaction) -> HistoryEventDetailsModel {
        let date = dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(event.timestamp)))

        let amountType: AccountEventActionAmountMapperActionType
        let dateFormatted: String
        var listItems = [HistoryEventDetailsModel.ListItem]()
        if event.toAccount == wallet.tron?.address {
            amountType = .income
            dateFormatted = TKLocales.EventDetails.receivedOn(date)
            listItems.append(
                .senderAddress(
                    value: event.fromAccount.base58,
                    copyValue: event.fromAccount.base58
                )
            )
        } else {
            amountType = .outcome
            dateFormatted = TKLocales.EventDetails.sentOn(date)
            listItems.append(
                .recipientAddress(
                    value: event.toAccount.base58,
                    copyValue: event.toAccount.base58
                )
            )
        }

        let title = amountFormatter.format(
            amount: event.amount,
            fractionDigits: TronSwift.USDT.fractionDigits,
            accessory: .symbol(TronSwift.USDT.symbol),
            isNegative: amountType == .outcome
        )

        if let batteryCharges = event.batteryCharges {
            listItems.append(.extra(value: "\(batteryCharges) battery charges", isRefund: false, converted: nil))
        }

        let detailsButton: HistoryEventDetailsModel.TransasctionDetailsButton = {
            let transaction = TKLocales.EventDetails.transaction.withTextStyle(.label2, color: .Text.primary)
            let hash = String(event.txID.prefix(8)).withTextStyle(.label2, color: .Text.secondary)
            let title = NSMutableAttributedString(attributedString: transaction)
            title.append(hash)

            let url = URL(string: "https://tronscan.org/#/transaction/\(event.txID)")!
            return HistoryEventDetailsModel.TransasctionDetailsButton(
                buttonTitle: title,
                url: url,
                browserTitle: "Tronscan",
                hash: event.txID
            )
        }()

        let fiatPrice: String? = {
            let currency = currencyStore.getState()
            guard let rate = tonRatesStore.getState().usdtRates.first(where: { $0.currency == currency }) else {
                return nil
            }
            let fiat = rateConverter.convert(
                amount: event.amount,
                amountFractionLength: TronSwift.USDT.fractionDigits,
                rate: rate
            )

            return amountFormatter.format(
                amount: fiat.amount,
                fractionDigits: fiat.fractionLength,
                accessory: .currency(currency)
            )
        }()

        return HistoryEventDetailsModel(
            headerImage: .transfer(
                TransactionConfirmationHeaderImageItem(
                    configuration: TransactionConfirmationHeaderImageItemView.Configuration(
                        image: .image(.App.Currency.Size96.usdt),
                        corners: .circle,
                        badge: TransactionConfirmationHeaderImageItemView.Configuration.Badge(
                            image: .image(.App.Currency.Vector.trc20)
                        )
                    ),
                    bottomSpace: 20
                )
            ),
            title: title,
            date: dateFormatted,
            fiatPrice: fiatPrice,
            warningText: event.isFailed ? TKLocales.State.failed : nil,
            isScam: false,
            management: nil,
            listItems: listItems,
            detailsButton: detailsButton
        )
    }
}
