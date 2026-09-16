import BigInt
import KeeperCore
import TKLocalize
import TKUIKit
import TonSwift
import TronSwift
import UIKit

enum WalletMigrationConfirmationMapper {
    struct Result {
        let items: [TransactionCellContent]
        let totalSummary: String
    }

    static func map(
        prepareResult: WalletMigrationPrepareResult?,
        tonFeeMethod: WalletMigrationPrepareResult.FeeMethod? = nil,
        tronPrepareResult: WalletMigrationTronPrepareResult?,
        tronFeeMethod: WalletMigrationTronPrepareResult.FeeMethod? = nil,
        usdtRate: Rates.Rate? = nil,
        trxRate: Rates.Rate? = nil,
        amountFormatter: AmountFormatter,
        currency: Currency,
        isSecureMode: Bool,
        nftProvider: (TonSwift.Address) -> NFT?
    ) -> Result {
        var items = [TransactionCellContent]()
        let tonTransactions = prepareResult?.transactionsForPresentation(feeMethod: tonFeeMethod)
        let sourceAddress = parseAddress(prepareResult?.from)
        let destinationAddress = parseAddress(prepareResult?.to)

        if let prepareResult, let tonTransactions {
            let recipientAddress = shortAddress(prepareResult.to)
            for transaction in tonTransactions {
                for action in transaction.event.actions {
                    guard let item = mapAction(
                        action,
                        sourceAddress: sourceAddress,
                        destinationAddress: destinationAddress,
                        recipientAddress: recipientAddress,
                        isSecureMode: isSecureMode,
                        nftProvider: nftProvider
                    ) else {
                        continue
                    }
                    items.append(item)
                }
            }
        }

        if let tronPrepareResult {
            if tronPrepareResult.hasUSDT {
                items.append(
                    mapTronUSDT(
                        prepareResult: tronPrepareResult,
                        amountFormatter: amountFormatter,
                        isSecureMode: isSecureMode
                    )
                )
            }
            let displayedTrxAmount = tronPrepareResult.displayedTRXAmount(
                for: tronFeeMethod ?? tronPrepareResult.preferredFeeMethod ?? .trx(amountSun: 0)
            )
            if displayedTrxAmount > 0 {
                items.append(
                    mapTronTRX(
                        prepareResult: tronPrepareResult,
                        trxAmount: displayedTrxAmount,
                        amountFormatter: amountFormatter,
                        isSecureMode: isSecureMode
                    )
                )
            }
        }

        for index in items.indices {
            items[index].showsDivider = index < items.count - 1
        }

        return Result(
            items: items,
            totalSummary: makeTotalSummary(
                tonTransactions: tonTransactions,
                tronPrepareResult: tronPrepareResult,
                tronFeeMethod: tronFeeMethod,
                usdtRate: usdtRate,
                trxRate: trxRate,
                amountFormatter: amountFormatter,
                currency: currency,
                isSecureMode: isSecureMode
            )
        )
    }

    private static func mapTronUSDT(
        prepareResult: WalletMigrationTronPrepareResult,
        amountFormatter: AmountFormatter,
        isSecureMode: Bool
    ) -> TransactionCellContent {
        let amountTitle: String = {
            guard !isSecureMode else { return String.secureModeValueShort }
            return amountFormatter.format(
                amount: prepareResult.usdtAmount,
                fractionDigits: USDT.fractionDigits,
                accessory: .tokenSymbol(USDT.symbol),
                isNegative: false,
                style: .regular
            )
        }()

        return TransactionCellContent(
            icon: .sent,
            title: TKLocales.NativeSwap.Field.send,
            subtitle: .init(
                text: shortTronAddress(prepareResult.destinationAddress),
                style: .primary
            ),
            amount: .init(
                title: amountTitle,
                style: .primary
            ),
            accessory: .init(
                text: TKLocales.Settings.Migration.trc20
            )
        )
    }

    private static func mapTronTRX(
        prepareResult: WalletMigrationTronPrepareResult,
        trxAmount: BigUInt,
        amountFormatter: AmountFormatter,
        isSecureMode: Bool
    ) -> TransactionCellContent {
        let amountTitle: String = {
            guard !isSecureMode else { return String.secureModeValueShort }
            return amountFormatter.format(
                amount: trxAmount,
                fractionDigits: TRX.fractionDigits,
                accessory: .tokenSymbol(TRX.symbol),
                isNegative: false,
                style: .regular
            )
        }()

        return TransactionCellContent(
            icon: .sent,
            title: TKLocales.NativeSwap.Field.send,
            subtitle: .init(
                text: shortTronAddress(prepareResult.destinationAddress),
                style: .primary
            ),
            amount: .init(
                title: amountTitle,
                style: .primary
            ),
            accessory: .init(
                text: TKLocales.Settings.Migration.trx
            )
        )
    }

    private static func mapAction(
        _ action: AccountEventAction,
        sourceAddress: TonSwift.Address?,
        destinationAddress: TonSwift.Address?,
        recipientAddress: String,
        isSecureMode: Bool,
        nftProvider: (TonSwift.Address) -> NFT?
    ) -> TransactionCellContent? {
        switch action.type {
        case let .tonTransfer(transfer):
            guard isOutgoingMigrationTonTransfer(
                transfer,
                sourceAddress: sourceAddress,
                destinationAddress: destinationAddress
            ) else {
                return nil
            }
        case .jettonTransfer, .nftItemTransfer, .smartContractExec:
            break
        default:
            return nil
        }

        let amountTitle = action.preview.value ?? defaultAmountTitle(for: action.type)
        let includesNft = if case .nftItemTransfer = action.type { true } else { false }
        let accessoryText: String = {
            guard !isSecureMode else { return String.secureModeValueShort }
            guard !includesNft else { return "" }
            return action.preview.fiatValue?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }()

        var nftPreview: TransactionCellContent.NftPreview?
        if case let .nftItemTransfer(transfer) = action.type {
            nftPreview = makeNftPreview(
                transfer: transfer,
                action: action,
                nftProvider: nftProvider
            )
        }

        return TransactionCellContent(
            icon: .sent,
            title: TKLocales.NativeSwap.Field.send,
            subtitle: .init(
                text: recipientAddress,
                style: .primary
            ),
            amount: .init(
                title: amountTitle,
                style: .primary
            ),
            accessory: .init(
                text: accessoryText
            ),
            nftPreview: nftPreview
        )
    }

    private static func defaultAmountTitle(for type: AccountEventAction.ActionType) -> String {
        switch type {
        case .nftItemTransfer:
            return "NFT"
        default:
            return "—"
        }
    }

    private static func makeNftPreview(
        transfer: AccountEventAction.NFTItemTransfer,
        action: AccountEventAction,
        nftProvider: (TonSwift.Address) -> NFT?
    ) -> TransactionCellContent.NftPreview? {
        if let nft = nftProvider(transfer.nftAddress) {
            return TransactionCellContent.NftPreview(
                id: nft.address.toRaw(),
                imageSource: .url(nft.imageURL),
                title: nft.notNilName,
                subtitle: nft.collection?.notEmptyName ?? "",
                isVerified: !nft.isUnverified
            )
        }

        guard let title = action.preview.name.nilIfEmpty else {
            return nil
        }

        return TransactionCellContent.NftPreview(
            id: transfer.nftAddress.toRaw(),
            imageSource: .url(nil),
            title: title,
            subtitle: "",
            isVerified: false
        )
    }

    private static func makeTotalSummary(
        tonTransactions: [WalletMigrationPreparedTransaction]?,
        tronPrepareResult: WalletMigrationTronPrepareResult?,
        tronFeeMethod: WalletMigrationTronPrepareResult.FeeMethod?,
        usdtRate: Rates.Rate?,
        trxRate: Rates.Rate?,
        amountFormatter: AmountFormatter,
        currency: Currency,
        isSecureMode: Bool
    ) -> String {
        guard tonTransactions != nil || tronPrepareResult != nil else { return "" }

        let nftCount = tonTransactions?.reduce(into: 0) { count, transaction in
            count += transaction.event.actions.filter {
                if case .nftItemTransfer = $0.type {
                    return true
                }
                return false
            }.count
        } ?? 0

        let totalFiat: String = {
            guard !isSecureMode else { return String.secureModeValueShort }

            var total = tonTransactions?.reduce(into: Decimal.zero) { partial, transaction in
                if let totalEquivalent = transaction.totalEquivalent {
                    partial += Decimal(totalEquivalent)
                }
            } ?? 0

            if let tronPrepareResult {
                total += tronFiatValue(
                    prepareResult: tronPrepareResult,
                    feeMethod: tronFeeMethod,
                    usdtRate: usdtRate,
                    trxRate: trxRate
                )
            }

            return amountFormatter.format(
                decimal: total,
                accessory: .fiat(currency),
                style: .fiatBalance
            )
        }()

        var parts = [TKLocales.ConfirmSend.Risk.total(totalFiat)]
        if nftCount > 0 {
            parts.append(
                nftCount == 1
                    ? TKLocales.Settings.Migration.nftCount(nftCount)
                    : TKLocales.Settings.Migration.nftsCount(nftCount)
            )
        }

        return parts.joined(separator: " · ")
    }

    private static func tronFiatValue(
        prepareResult: WalletMigrationTronPrepareResult,
        feeMethod: WalletMigrationTronPrepareResult.FeeMethod?,
        usdtRate: Rates.Rate?,
        trxRate: Rates.Rate?
    ) -> Decimal {
        let converter = RateConverter()
        var total = Decimal.zero

        if prepareResult.hasUSDT, let usdtRate {
            total += converter.convertToDecimal(
                amount: prepareResult.usdtAmount,
                amountFractionLength: USDT.fractionDigits,
                rate: usdtRate
            )
        }

        let resolvedFeeMethod = feeMethod ?? prepareResult.preferredFeeMethod
        let trxAmount = resolvedFeeMethod.map { prepareResult.displayedTRXAmount(for: $0) }
            ?? prepareResult.availableTRXSun
        if trxAmount > 0, let trxRate {
            total += converter.convertToDecimal(
                amount: trxAmount,
                amountFractionLength: TRX.fractionDigits,
                rate: trxRate
            )
        }

        return total
    }

    private static func shortAddress(_ address: String) -> String {
        if let friendlyAddress = try? FriendlyAddress(string: address) {
            return friendlyAddress.toShort()
        }
        if let parsedAddress = try? TonSwift.Address.parse(address) {
            return parsedAddress.toShortString(bounceable: true)
        }
        return address
    }

    private static func shortTronAddress(_ address: String) -> String {
        guard address.count > 14 else { return address }
        return "\(address.prefix(7))…\(address.suffix(7))"
    }

    private static func parseAddress(_ address: String?) -> TonSwift.Address? {
        guard let address else { return nil }
        if let friendlyAddress = try? FriendlyAddress(string: address) {
            return friendlyAddress.address
        }
        return try? TonSwift.Address.parse(address)
    }

    private static func isOutgoingMigrationTonTransfer(
        _ transfer: AccountEventAction.TonTransfer,
        sourceAddress: TonSwift.Address?,
        destinationAddress: TonSwift.Address?
    ) -> Bool {
        if let sourceAddress, transfer.sender.address != sourceAddress {
            return false
        }
        if let destinationAddress, transfer.recipient.address != destinationAddress {
            return false
        }
        return true
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
