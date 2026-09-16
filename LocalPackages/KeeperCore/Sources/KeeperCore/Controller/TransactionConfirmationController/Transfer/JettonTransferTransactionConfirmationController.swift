import BigInt
import Foundation
import TonAPI
import TonSwift

final class JettonTransferTransactionConfirmationController: TransactionConfirmationController {
    private var preferredExtraType: TransactionConfirmationModel.ExtraType?
    private var availableTypes: [TransactionConfirmationModel.ExtraType] = []
    /// The subset of `availableTypes` that `prepareFeeOptions` managed to price. Kept apart from
    /// `availableTypes` so a method that failed to price is only hidden, not forgotten: the next
    /// `prepareFeeOptions` still sees it as pending and retries it.
    private var pricedTypes: [TransactionConfirmationModel.ExtraType]?
    private var extraOptions: [TransactionConfirmationModel.ExtraOption] = []
    private var unavailableGaslessTokenAddresses: Set<String> = []
    private var lastTransfer: Transfer?

    func getModel() -> TransactionConfirmationModel {
        createModel()
    }

    func setLoading() {
        extraState = .loading
        extraOptions = []
        pricedTypes = nil
    }

    func emulate() async -> Result<Void, TransactionConfirmationError> {
        var availableTypes: [TransactionConfirmationModel.ExtraType] = [.default]
        let gaslessTokenAddress = jettonItem.jettonInfo.address.toRaw()

        do {
            defer {
                self.availableTypes = availableTypes
                self.pricedTypes = nil
            }

            let amountToSend = jettonItem.jettonInfo.scaleValue.flatMap {
                BigUInt.divide(
                    self.amount, scaleN: jettonItem.jettonInfo.fractionDigits,
                    by: $0, scaleD: jettonItem.jettonInfo.fractionDigits,
                    resultScale: jettonItem.jettonInfo.fractionDigits
                )
            } ?? getAmountValue().value

            let isMax = await {
                do {
                    let balance = try await balanceService.loadWalletBalance(
                        wallet: wallet,
                        currency: .USD,
                        includingTransferFees: true
                    )
                    let jettonBalance = balance.balance.jettonsBalance.first(where: { $0.item.jettonInfo == jettonItem.jettonInfo
                    })
                    let jettonAmount = jettonBalance?.scaledBalance ?? jettonBalance?.quantity
                    return jettonAmount == amount
                } catch {
                    return false
                }
            }()
            self.isMax = isMax

            let transferAmount = await transferService.transferCost(
                wallet: wallet,
                jettonMasterAddress: jettonItem.jettonInfo.address
            )
            let transfer: Transfer = .jetton(jettonItem, transferAmount: transferAmount, amount: isMax ? 1 : amountToSend, recipient: recipient, comment: comment)
            lastTransfer = transfer

            let (gaslessAvailable, isBatteryAvailable) =
                await(
                    transferService.isGaslessAvailable(wallet: wallet, transfer: transfer),
                    transferService.isRelayerAvailable(wallet: wallet, transfer: transfer)
                )

            // With a fee picker in front of the user, zero charges is a state to show and offer a
            // refill for, not a reason to hide the method. Without one there is nowhere to recover,
            // so the option only appears when it can actually pay.
            let listsBattery = buildsFeeOptions
                ? TransferService.isRelayerEnabled(wallet: wallet, transfer: transfer)
                : isBatteryAvailable
            if listsBattery {
                availableTypes.append(.battery)
            }

            if gaslessAvailable, !unavailableGaslessTokenAddresses.contains(gaslessTokenAddress) {
                availableTypes.append(.gasless(token: jettonItem.jettonInfo))
            }

            let preferredType: TransactionConfirmationModel.ExtraType = {
                if let preferredExtraType,
                   availableTypes.contains(preferredExtraType)
                {
                    return preferredExtraType
                }

                switch settingsRepository.getTransferSettings(wallet: wallet).jettonTransfer {
                case .default:
                    return .default
                case .battery:
                    return isBatteryAvailable ? .battery : .default
                case .gasless:
                    let gaslessType = TransactionConfirmationModel.ExtraType.gasless(token: jettonItem.jettonInfo)
                    if availableTypes.contains(gaslessType) {
                        return gaslessType
                    }
                    return isBatteryAvailable ? .battery : .default
                }
            }()

            let emulateWithType: (TransactionConfirmationModel.ExtraType) async throws -> TransferEmulationResult = { extraType in
                try await self.transferService.emulate(
                    wallet: self.wallet,
                    transfer: transfer,
                    params: [.init(address: self.wallet.address.toRaw(), balance: Int64(2_000_000_000))],
                    preferredExtraType: extraType
                )
            }

            var result = try await emulateWithType(preferredType)

            /* Not enough resources for fee */
            if self.isMax,
               case .gasless = result.transferType,
               case let .fee(gaslessFee) = result.extra.amount,
               gaslessFee >= amount
            {
                unavailableGaslessTokenAddresses.insert(gaslessTokenAddress)
                availableTypes.removeAll(where: { type in
                    if case let .gasless(token) = type, token.address.toRaw() == gaslessTokenAddress {
                        return true
                    }
                    return false
                })

                let fallbackType: TransactionConfirmationModel.ExtraType = isBatteryAvailable ? .battery : .default
                result = try await emulateWithType(fallbackType)
            }

            self.emulationResult = result
            self.extraOptions = buildsFeeOptions ? [makeExtraOption(for: result)] : []
            await updateFee(emulationResult: emulationResult)
            return .success(())
        } catch {
            self.emulationResult = nil
            self.extraOptions = []
            await updateFee(emulationResult: nil)
            return .failure(.failedToCalculateFee)
        }
    }

    func prepareFeeOptions() async {
        guard buildsFeeOptions,
              let selectedResult = emulationResult,
              let transfer = lastTransfer
        else {
            return
        }

        let availableTypes = self.availableTypes
        let isComplete = !extraOptions.isEmpty
            && availableTypes.allSatisfy { type in extraOptions.contains { $0.type == type } }
        guard !isComplete else {
            return
        }

        let emulateWithType: (TransactionConfirmationModel.ExtraType) async throws -> TransferEmulationResult = { extraType in
            try await self.transferService.emulate(
                wallet: self.wallet,
                transfer: transfer,
                params: [.init(address: self.wallet.address.toRaw(), balance: Int64(2_000_000_000))],
                preferredExtraType: extraType,
                includeUnavailableBattery: true
            )
        }

        let preparedOptions = await makeExtraOptions(
            availableTypes: availableTypes,
            selectedResult: selectedResult,
            emulateWithType: emulateWithType
        )
        extraOptions = preparedOptions
        // A method that could not be priced has nothing to show in the picker and nothing to
        // select: keeping it listed leaves a row that silently falls back to another method.
        pricedTypes = availableTypes.filter { type in
            preparedOptions.contains { $0.type == type }
        }
    }

    private func makeExtraOptions(
        availableTypes: [TransactionConfirmationModel.ExtraType],
        selectedResult: TransferEmulationResult,
        emulateWithType: (TransactionConfirmationModel.ExtraType) async throws -> TransferEmulationResult
    ) async -> [TransactionConfirmationModel.ExtraOption] {
        var options: [TransactionConfirmationModel.ExtraOption] = []
        let selectedType = extraType(for: selectedResult)

        for type in availableTypes where !options.contains(where: { $0.type == type }) {
            let result: TransferEmulationResult?
            if type == selectedType {
                result = selectedResult
            } else {
                result = try? await emulateWithType(type)
            }
            // emulate may fall back to another type; only keep an exact match.
            guard let result, extraType(for: result) == type else {
                continue
            }
            options.append(makeExtraOption(for: result))
        }

        return options
    }

    private func makeExtraOption(
        for result: TransferEmulationResult
    ) -> TransactionConfirmationModel.ExtraOption {
        TransactionConfirmationModel.ExtraOption(
            type: extraType(for: result),
            value: extraValue(for: result)
        )
    }

    private func extraType(for result: TransferEmulationResult) -> TransactionConfirmationModel.ExtraType {
        switch result.transferType {
        case .battery:
            return .battery
        case .gasless:
            return .gasless(token: jettonItem.jettonInfo)
        case .default:
            return .default
        }
    }

    private func extraValue(for result: TransferEmulationResult) -> TransactionConfirmationModel.ExtraValue {
        let amount: BigUInt = switch result.extra.amount {
        case let .fee(value): value
        case let .refund(value): value
        }
        switch result.transferType {
        case .battery:
            let excess = result.extra.excess.flatMap {
                batteryCalculation.calculateCharges(tonAmount: BigUInt($0))
            }
            return .battery(
                charges: batteryCalculation.calculateCharges(tonAmount: amount),
                excess: excess
            )
        case .gasless:
            return .gasless(token: jettonItem.jettonInfo, amount: amount)
        case .default:
            return .default(amount: amount)
        }
    }

    func sendTransaction() async -> Result<TransactionConfirmationSendResult, TransactionConfirmationError> {
        do {
            let minimumTransferAmount = await transferService.transferCost(
                wallet: wallet,
                jettonMasterAddress: jettonItem.jettonInfo.address
            )
            let transferAmount: BigUInt = {
                guard let emulationResult else {
                    return BigUInt(100_000_000)
                }
                if case .gasless = emulationResult.transferType {
                    return minimumTransferAmount
                }

                var transferAmount = {
                    switch emulationResult.extra.amount {
                    case let .fee(fee):
                        return fee + minimumTransferAmount
                    case .refund:
                        return minimumTransferAmount
                    }
                }()

                transferAmount = transferAmount < minimumTransferAmount
                    ? minimumTransferAmount
                    : transferAmount
                return transferAmount
            }()

            let amountToSend = jettonItem.jettonInfo.scaleValue.flatMap {
                BigUInt.divide(
                    self.amount, scaleN: jettonItem.jettonInfo.fractionDigits,
                    by: $0, scaleD: jettonItem.jettonInfo.fractionDigits,
                    resultScale: jettonItem.jettonInfo.fractionDigits
                )
            } ?? getAmountValue().value

            let broadcastedTransactions = try await transferService.sendTransaction(
                wallet: wallet,
                transfer: .jetton(
                    jettonItem,
                    transferAmount: transferAmount,
                    amount: amountToSend,
                    recipient: recipient,
                    comment: comment
                ),
                transferType: emulationResult?.transferType ?? .default,
                signClosure: { [weak self, wallet] transferData -> Result<SignedTransactions, TransactionConfirmationError> in
                    guard let self else {
                        return .failure(.cancelledByUser)
                    }
                    return await signedTransactions(transferData: transferData, wallet: wallet)
                }
            )

            return .success(
                .ton(
                    wallet: wallet,
                    signedTransactions: broadcastedTransactions,
                    activityType: .send
                )
            )
        } catch {
            switch error {
            case let .firstOption(transferError):
                switch transferError {
                case let .sendFailed(message):
                    return .failure(
                        .failedToSendTransaction(
                            message: message
                        )
                    )
                default:
                    return .failure(
                        .failedToSendTransaction(
                            message: transferError.localizedDescription
                        )
                    )
                }
            case let .secondOption(transactionError):
                switch transactionError {
                case .cancelledByUser:
                    return .failure(.cancelledByUser)
                default:
                    return .failure(
                        .failedToSendTransaction(
                            message: transactionError.localizedDescription
                        )
                    )
                }
            }
        }
    }

    func setPrefferedExtraType(extraType: TransactionConfirmationModel.ExtraType) {
        setExtraTypeForCurrentTransaction(extraType: extraType)
        var transferSettings = settingsRepository.getTransferSettings(wallet: wallet)
        switch extraType {
        case .default:
            transferSettings.jettonTransfer = .default
        case .battery:
            transferSettings.jettonTransfer = .battery
        case .gasless:
            transferSettings.jettonTransfer = .gasless
        case .multichain:
            return
        }
        try? settingsRepository.setTransferSettings(wallet: wallet, transferSettings: transferSettings)
    }

    func setExtraTypeForCurrentTransaction(extraType: TransactionConfirmationModel.ExtraType) {
        preferredExtraType = extraType
    }

    var signHandler: ((TransferData, Wallet) async throws(TransactionConfirmationError) -> SignedTransactions)?

    @Atomic private var emulationResult: TransferEmulationResult?
    // TODO: сбрасывать стейт на время эмуляции
    @Atomic private var extraState: TransactionConfirmationModel.ExtraState = .loading
    @Atomic private var isMax: Bool = false

    @Atomic private var totalFee: BigInt = 0

    private let wallet: Wallet
    private let recipient: TonRecipient
    private let jettonItem: JettonItem
    private let amount: BigUInt
    private let comment: String?
    private let recipientDisplayAddress: String?
    private let sendService: SendService
    private let blockchainService: BlockchainService
    private let ratesStore: TonRatesStore
    private let currencyStore: CurrencyStore
    private let transferService: TransferService
    private let balanceService: BalanceService
    private let settingsRepository: SettingsRepository
    private let batteryCalculation: BatteryCalculation
    private let buildsFeeOptions: Bool

    init(
        wallet: Wallet,
        recipient: TonRecipient,
        jettonItem: JettonItem,
        amount: BigUInt,
        comment: String?,
        recipientDisplayAddress: String? = nil,
        sendService: SendService,
        blockchainService: BlockchainService,
        ratesStore: TonRatesStore,
        currencyStore: CurrencyStore,
        transferService: TransferService,
        balanceService: BalanceService,
        settingsRepository: SettingsRepository,
        batteryCalculation: BatteryCalculation,
        buildsFeeOptions: Bool = false
    ) {
        self.wallet = wallet
        self.recipient = recipient
        self.jettonItem = jettonItem
        self.amount = amount
        self.comment = comment
        self.recipientDisplayAddress = recipientDisplayAddress
        self.sendService = sendService
        self.blockchainService = blockchainService
        self.ratesStore = ratesStore
        self.currencyStore = currencyStore
        self.transferService = transferService
        self.balanceService = balanceService
        self.settingsRepository = settingsRepository
        self.batteryCalculation = batteryCalculation
        self.buildsFeeOptions = buildsFeeOptions
    }

    private func createModel() -> TransactionConfirmationModel {
        TransactionConfirmationModel(
            wallet: wallet,
            recipient: recipient.recipientAddress.name,
            recipientAddress: recipientDisplayAddress ?? recipient.recipientAddress.addressString,
            transaction: .transfer(.jetton(jettonItem.jettonInfo)),
            amount: getAmountValue(),
            extraState: extraState,
            extraOptions: extraOptions,
            comment: comment,
            availableExtraTypes: pricedTypes ?? availableTypes,
            isMax: isMax,
            totalFee: totalFee
        )
    }

    private func updateFee(emulationResult: TransferEmulationResult?) async {
        guard let emulationResult else {
            extraState = .none
            return
        }
        let extra = emulationResult.extra

        let extraType: TransactionConfirmationModel.ExtraType
        switch emulationResult.transferType {
        case .battery:
            extraType = .battery
        case .gasless:
            extraType = .gasless(
                token: jettonItem.jettonInfo
            )
        case .default:
            extraType = .default
        }

        let (amount, isRefund) = {
            switch extra.amount {
            case let .fee(amount):
                return (amount, false)
            case let .refund(amount):
                return (amount, true)
            }
        }()

        let value: TransactionConfirmationModel.ExtraValue = {
            switch extraType {
            case .default:
                return .default(amount: amount)
            case .battery:
                let excess: Int? = emulationResult.extra.excess.flatMap { batteryCalculation.calculateCharges(tonAmount: BigUInt($0)) }
                return .battery(
                    charges: batteryCalculation.calculateCharges(tonAmount: amount),
                    excess: excess
                )
            case let .gasless(token):
                return .gasless(token: token, amount: amount)
            case let .multichain(token):
                return .multichain(token: token, amount: amount)
            }
        }()

        if let totalFee = emulationResult.transactionInfo?.trace.transaction.totalFees {
            self.totalFee = BigInt(totalFee)
        }

        self.extraState = .extra(
            TransactionConfirmationModel.Extra(
                value: value,
                kind: isRefund ? .refund : .fee
            )
        )
    }

    private func getAmountValue() -> TransactionConfirmationModel.Amount {
        let amount: () -> BigUInt = {
            if self.isMax {
                switch self.extraState {
                case .none, .loading:
                    return self.amount
                case let .extra(extra):
                    switch extra.value {
                    case .battery, .default, .multichain:
                        return self.amount
                    case let .gasless(_, amount):
                        return self.amount - amount
                    }
                }
            } else {
                return self.amount
            }
        }

        return
            TransactionConfirmationModel.Amount(
                token: .ton(.jetton(jettonItem)),
                value: amount()
            )
    }

    private func signedTransactions(
        transferData: TransferData,
        wallet: Wallet
    ) async -> Result<SignedTransactions, TransactionConfirmationError> {
        guard let signHandler else {
            return .failure(.cancelledByUser)
        }
        let transactions: SignedTransactions
        do {
            transactions = try await signHandler(transferData, wallet)
        } catch {
            return .failure(error)
        }
        return .success(transactions)
    }
}
