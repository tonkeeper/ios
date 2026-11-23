import BigInt
import Foundation
import TKBatteryAPI
import TonAPI
import TonSwift

public final class NativeSwapTransactionConfirmationController: TransactionConfirmationController {
    public var signHandler: ((TransferData, Wallet) async throws(TransactionConfirmationError) -> SignedTransactions)?

    private var preferredExtraType: TransactionConfirmationModel.ExtraType = .default
    private var availableTypes: [TransactionConfirmationModel.ExtraType] = [.default]
    /// The fee method the user set through `setPrefferedExtraType`. The emulation tries it first, also after
    /// one that could not pay fell back to TON.
    private var pickedExtraType: TransactionConfirmationModel.ExtraType?

    private var transferType: TransferType {
        if preferredExtraType == .default {
            return .default
        } else {
            do {
                return try .battery(excessAddress: wallet.address)
            } catch {
                return .default
            }
        }
    }

    private var extraState: TransactionConfirmationModel.ExtraState {
        let value: TransactionConfirmationModel.ExtraValue = switch preferredExtraType {
        case .battery: .battery(charges: nil, excess: nil)
        case .default, .gasless, .multichain: .default(amount: confirmation.requiredGasAmount)
        }
        return .extra(TransactionConfirmationModel.Extra(value: value, kind: .fee))
    }

    private let wallet: Wallet
    private var confirmation: SwapConfirmation
    private let fromToken: KeeperCore.Token
    private let toToken: KeeperCore.Token
    private let fromAmount: BigUInt
    private let transferService: TransferService
    private let tonConnectService: TonConnectService
    private let balanceService: BalanceService
    private let settingsRepository: SettingsRepository
    private let isEmulationEnabled: Bool

    init(
        wallet: Wallet,
        confirmation: SwapConfirmation,
        fromToken: KeeperCore.Token,
        toToken: KeeperCore.Token,
        fromAmount: BigUInt,
        transferService: TransferService,
        tonConnectService: TonConnectService,
        balanceService: BalanceService,
        settingsRepository: SettingsRepository,
        isEmulationEnabled: Bool
    ) {
        self.wallet = wallet
        self.confirmation = confirmation
        self.fromToken = fromToken
        self.toToken = toToken
        self.fromAmount = fromAmount
        self.transferService = transferService
        self.tonConnectService = tonConnectService
        self.balanceService = balanceService
        self.settingsRepository = settingsRepository
        self.isEmulationEnabled = isEmulationEnabled

        if !isEmulationEnabled {
            setBatteryPrefferedExtraTypeIfNeeded()
        }
    }

    public func getModel() -> TransactionConfirmationModel {
        TransactionConfirmationModel(
            wallet: wallet,
            recipient: nil,
            recipientAddress: nil,
            transaction: .transfer(getTransferType()),
            amount: getAmountValue(),
            extraState: extraState,
            comment: nil,
            availableExtraTypes: availableTypes,
            isMax: getIsMaxAmount(),
            totalFee: BigInt(confirmation.requiredGasAmount)
        )
    }

    public func setLoading() {}

    public func updateConfirmation(_ newConfirmation: SwapConfirmation) {
        confirmation = newConfirmation
    }

    public func emulate() async -> Result<Void, TransactionConfirmationError> {
        let isBatteryAvailable = await transferService.isRelayerAvailable(
            wallet: wallet,
            transfer: nativeSwapTransfer()
        )
        let isBatteryEligible = isBatteryAvailable && fromToken != .ton(.ton)

        availableTypes = isBatteryEligible ? [.battery, .default] : [.default]

        guard isEmulationEnabled else {
            return .success(())
        }
        return await emulateSwap(isBatteryEligible: isBatteryEligible)
    }

    public func sendTransaction() async -> Result<TransactionConfirmationSendResult, TransactionConfirmationError> {
        let confirmation = confirmation
        let fromAddress: String? = switch fromToken {
        case .ton:
            wallet.addressToCopy
        case .tron:
            wallet.multichainAddress(for: .tron) ?? wallet.tron?.address.base58
        }
        let swapDetails = MultichainPendingTransaction.SwapDetails(
            fromAssetId: fromToken.assetId(network: wallet.network),
            toAssetId: toToken.assetId(network: wallet.network),
            fromAddress: fromAddress,
            fromAmount: (BigUInt(confirmation.bidUnits) ?? fromAmount).description
        )
        do {
            let broadcastedTransactions = try await transferService.sendTransaction(
                wallet: wallet,
                transfer: .nativeSwap(confirmation),
                transferType: transferType,
                signClosure: { [weak self] transferData -> Result<SignedTransactions, TransactionConfirmationError> in
                    guard let self else {
                        return .failure(.cancelledByUser)
                    }
                    return await signedTransactions(transferData: transferData)
                }
            )
            return .success(
                .ton(
                    wallet: wallet,
                    signedTransactions: broadcastedTransactions,
                    activityType: .swap(swapDetails)
                )
            )
        } catch {
            return .failure(TransactionConfirmationError(sendFailure: error))
        }
    }

    public func setPrefferedExtraType(
        extraType: TransactionConfirmationModel.ExtraType
    ) {
        preferredExtraType = extraType
        pickedExtraType = extraType
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

        try? settingsRepository.setTransferSettings(
            wallet: wallet,
            transferSettings: transferSettings
        )
    }

    /// The swap's own messages go through the emulation of the fee method it is about to pay with. A method
    /// picked here is the swap's alone and stays out of the wallet's transfer settings.
    private func emulateSwap(isBatteryEligible: Bool) async -> Result<Void, TransactionConfirmationError> {
        let candidate = FeeMethod.candidate(picked: pickedExtraType, isBatteryEligible: isBatteryEligible)
        let emulation: TransferEmulationResult
        do {
            emulation = try await transferService.emulate(
                wallet: wallet,
                transfer: nativeSwapTransfer(),
                preferredExtraType: candidate
            )
            // A newer emulation replaced this one, and the fee method is the newer one's to set.
            try Task.checkCancellation()
        } catch {
            return .failure(.failedToCalculateFee(message: error.analyticsReason))
        }
        let feeMethod = FeeMethod(
            candidate: candidate,
            emulatedTransferType: emulation.transferType,
            isBatteryEligible: isBatteryEligible
        )
        preferredExtraType = feeMethod.extraType
        availableTypes = feeMethod.availableTypes
        return .success(())
    }

    private func setBatteryPrefferedExtraTypeIfNeeded() {
        Task {
            let isBatteryAvailable = await transferService.isRelayerAvailable(
                wallet: wallet,
                transfer: nativeSwapTransfer()
            )

            if isBatteryAvailable, fromToken != .ton(.ton) {
                setPrefferedExtraType(extraType: .battery)
            }
        }
    }

    private func getTransferType() -> TransactionConfirmationModel.Transaction.Transfer {
        switch fromToken {
        case let .ton(token):
            switch token {
            // The funds check skips a transfer of the whole balance, which pays its fee out of the amount. A
            // swap attaches its gas on top of the amount instead, so the check has to count both.
            case .ton: .ton(isEmulationEnabled ? false : getIsMaxAmount())
            case let .jetton(jetton): .jetton(jetton.jettonInfo)
            }
        case .tron: .tronUSDT
        }
    }

    private func getIsMaxAmount() -> Bool {
        switch fromToken {
        case let .ton(token):
            let balance: WalletBalance
            do {
                balance = try balanceService.getBalance(wallet: wallet)
            } catch {
                return false
            }
            switch token {
            case .ton:
                let tonAmount = BigUInt(balance.balance.tonBalance.amount)
                let requiredForFee = NativeSwapConstants.tonFeeReserve

                if requiredForFee > tonAmount {
                    return false
                }

                let availableForSwap = tonAmount - requiredForFee
                return fromAmount >= availableForSwap
            case let .jetton(jettonInfo):
                let jettonBalance = balance.balance.jettonsBalance.first {
                    $0.item.jettonInfo.address == jettonInfo.jettonInfo.address
                }
                let jettonAmount = jettonBalance?.quantity ?? 0
                return fromAmount >= jettonAmount
            }
        case .tron:
            do {
                let balance = try balanceService.getBalance(wallet: wallet)
                let tronAmount = balance.tronBalance?.amount ?? 0
                let requiredForFee = BigUInt(250_000_000)

                if requiredForFee > tronAmount {
                    return false
                }

                let availableForSwap = tronAmount - requiredForFee
                return fromAmount >= availableForSwap
            } catch {
                return false
            }
        }
    }

    private func nativeSwapTransfer() -> Transfer {
        .nativeSwap(confirmation)
    }

    private func getAmountValue() -> TransactionConfirmationModel.Amount {
        let tokenItem: TransactionConfirmationModel.Amount.Item

        switch fromToken {
        case let .ton(token):
            switch token {
            case .ton:
                tokenItem = .ton(.ton)
            case let .jetton(jettonItem):
                tokenItem = .ton(.jetton(jettonItem))
            }
        case .tron:
            tokenItem = .tronUSDT
        }

        return TransactionConfirmationModel.Amount(
            token: tokenItem,
            value: fromAmount
        )
    }

    private func signedTransactions(
        transferData: TransferData
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

extension NativeSwapTransactionConfirmationController {
    /// What the swap pays its fee with once an emulation priced it. `TransferService` emulates through the
    /// battery only when its charges cover the swap and falls back to TON otherwise, so a battery the emulation
    /// did not go through neither pays nor stays on offer. With TON picked, the battery stays on offer
    /// wherever the wallet holds charges.
    struct FeeMethod {
        let extraType: TransactionConfirmationModel.ExtraType
        let availableTypes: [TransactionConfirmationModel.ExtraType]

        /// What the swap is emulated with: the user's pick, else the battery where the wallet holds charges,
        /// else TON.
        static func candidate(
            picked: TransactionConfirmationModel.ExtraType?,
            isBatteryEligible: Bool
        ) -> TransactionConfirmationModel.ExtraType {
            picked ?? (isBatteryEligible ? .battery : .default)
        }

        init(
            candidate: TransactionConfirmationModel.ExtraType,
            emulatedTransferType: TransferType,
            isBatteryEligible: Bool
        ) {
            if emulatedTransferType.isBattery {
                extraType = .battery
                availableTypes = [.battery, .default]
            } else {
                extraType = .default
                availableTypes = isBatteryEligible && candidate == .default ? [.battery, .default] : [.default]
            }
        }
    }
}
