import BigInt
import KeeperCore
import TKLocalize
import TKUIKit
import TonSwift
import UIKit

struct SignRawConfirmationModel {
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
    private let totalBalanceStore: TotalBalanceStore
    private let balanceStore: BalanceStore
    private let nftManagmentStore: WalletNFTsManagementStore
    private let accountEventMapper: AccountEventMapper
    private let accountEventModelMapper: AccountEventModelMapper
    private let amountFormatter: AmountFormatter

    init(
        nftService: NFTService,
        tonRatesStore: TonRatesStore,
        totalBalanceStore: TotalBalanceStore,
        balanceStore: BalanceStore,
        nftManagmentStore: WalletNFTsManagementStore,
        accountEventMapper: AccountEventMapper,
        accountEventModelMapper: AccountEventModelMapper,
        amountFormatter: AmountFormatter
    ) {
        self.nftService = nftService
        self.tonRatesStore = tonRatesStore
        self.totalBalanceStore = totalBalanceStore
        self.balanceStore = balanceStore
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

    func mapSignMessageEmulationResult(
        emulation: SignRawEmulation,
        wallet: Wallet,
        gaslessRelayAddress: Address?
    ) -> SignRawConfirmationModel {
        let actions = emulation.event.actions.flatMap { action in
            let actionModels = mapAction(action, of: emulation.event, wallet: wallet, currency: emulation.risk.currency)
            guard action.isJettonTransfer(to: gaslessRelayAddress) else {
                return actionModels
            }
            return actionModels.map { $0.setting(customName: TKLocales.EventDetails.fee) }
        }
        let eventModel = AccountEventModel(
            eventId: emulation.event.eventId,
            actions: actions,
            accountEvent: emulation.event,
            date: Date()
        )
        return SignRawConfirmationModel(
            contentModel: accountEventModelMapper.mapSignRawEventContentConfiguration(eventModel),
            risk: mapRisk(
                emulation: emulation,
                totalEquivalent: signMessageTotalEquivalent(emulation: emulation, wallet: wallet),
                wallet: wallet
            )
        )
    }

    func mapSuccessEmulationResult(signRawEmulation: SignRawEmulation, wallet: Wallet) -> AccountEventCellContentView.Model {
        let currency = signRawEmulation.risk.currency
        let tonRate = tonRatesStore.state.tonRates.first(where: { $0.currency == currency })

        let event = signRawEmulation.event
        let eventModel = AccountEventModel(
            eventId: event.eventId,
            actions: event.actions.flatMap { mapAction($0, of: event, wallet: wallet, currency: currency) },
            accountEvent: event,
            date: Date()
        )

        let feeFormatted = "\(String.Symbol.almostEqual)\(String.Symbol.shortSpace)"
            + amountFormatter.format(
                amount: BigUInt(signRawEmulation.fee),
                fractionDigits: TonInfo.fractionDigits,
                accessory: .token(Currency.GRAM),
                isNegative: false,
                style: .regular
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
                accessory: .fiat(currency)
            )
        }

        return accountEventModelMapper.mapSignRawEventContentConfiguration(
            eventModel,
            fee: feeFormatted,
            feeConverted: feeConverted,
            feeDescription: signRawEmulation.transferType.isBattery ? TKLocales.TransactionConfirmation.battery : nil
        )
    }

    /// Unlike the history list, a contract call shows its decoded body here: without it the
    /// confirmation names only the contract, whatever the call does to it.
    private func mapAction(
        _ action: AccountEventAction,
        of event: AccountEvent,
        wallet: Wallet,
        currency: Currency
    ) -> [AccountEventModel.Action] {
        let actionModels = mapEvent(event.replacingActions(with: [action]), wallet: wallet, currency: currency).actions
        guard case let .smartContractExec(smartContractExec) = action.type,
              let payload = smartContractExec.payload?.trimmingCharacters(in: .whitespacesAndNewlines),
              !payload.isEmpty
        else {
            return actionModels
        }
        return actionModels.map { $0.setting(description: payload) }
    }

    private func mapEvent(_ event: AccountEvent, wallet: Wallet, currency: Currency) -> AccountEventModel {
        let descriptionProvider = SignRawConfirmationAccountEventRightTopDescriptionProvider(
            rates: tonRatesStore.state.tonRates.first(where: { $0.currency == currency }),
            currency: currency,
            formatter: amountFormatter
        )

        return accountEventMapper.mapEvent(
            event,
            nftManagmentStore: nftManagmentStore,
            eventDate: Date(),
            accountEventRightTopDescriptionProvider: descriptionProvider,
            network: wallet.network,
            nftProvider: { address in
                try? self.nftService.getNFT(address: address, network: wallet.network)
            },
            decryptedCommentProvider: { _ in nil }
        )
    }

    func mapRisk(emulation: SignRawEmulation, wallet: Wallet) -> SignRawConfirmationModel.Risk? {
        mapRisk(emulation: emulation, totalEquivalent: emulation.risk.totalEquivalent, wallet: wallet)
    }

    private func signMessageTotalEquivalent(emulation: SignRawEmulation, wallet: Wallet) -> Double? {
        let currency = emulation.risk.currency
        guard let tonBalance = balanceStore.state[wallet]?.walletBalance.balance.tonBalance.amount,
              let tonRate = tonRatesStore.state.tonRates.first(where: { $0.currency == currency })
        else {
            return emulation.risk.totalEquivalent
        }
        return emulation.risk.totalEquivalent(limitingTonTo: BigUInt(max(tonBalance, 0)), tonRate: tonRate)
    }

    private func mapRisk(
        emulation: SignRawEmulation,
        totalEquivalent: Double?,
        wallet: Wallet
    ) -> SignRawConfirmationModel.Risk? {
        guard
            let totalBalanceState = totalBalanceStore.state[wallet],
            let totalBalance = totalBalanceState.totalBalance,
            totalBalance.currency == emulation.risk.currency,
            let total = totalEquivalent.flatMap(Decimal.init(floatLiteral:))
        else {
            return nil
        }

        let totalString = amountFormatter.format(
            decimal: total,
            accessory: .fiat(emulation.risk.currency),
            style: .regular
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

private extension AccountEvent {
    func replacingActions(with actions: [AccountEventAction]) -> AccountEvent {
        AccountEvent(
            eventId: eventId,
            date: date,
            account: account,
            isScam: isScam,
            isInProgress: isInProgress,
            extra: extra,
            excess: excess,
            progress: progress,
            actions: actions
        )
    }
}

private extension AccountEventAction {
    func isJettonTransfer(to address: Address?) -> Bool {
        guard let address, case let .jettonTransfer(jettonTransfer) = type else {
            return false
        }
        return jettonTransfer.recipient?.address == address
    }
}

private extension AccountEventModel.Action {
    func setting(customName: String? = nil, description: String? = nil) -> AccountEventModel.Action {
        AccountEventModel.Action(
            eventType: eventType,
            customName: customName ?? self.customName,
            stakingImplementation: stakingImplementation,
            amount: amount,
            subamount: subamount,
            leftTopDescription: leftTopDescription,
            leftBottomDescription: leftBottomDescription,
            rightTopDescription: rightTopDescription,
            status: status,
            comment: comment,
            encryptedComment: encryptedComment,
            description: description ?? self.description,
            nft: nft
        )
    }
}
