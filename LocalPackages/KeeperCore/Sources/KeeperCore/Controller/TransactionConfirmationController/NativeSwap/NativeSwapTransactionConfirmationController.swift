import BigInt
import Foundation
import TKBatteryAPI
import TonAPI
import TonSwift

public final class NativeSwapTransactionConfirmationController: TransactionConfirmationController {
    public var signHandler: ((TransferData, Wallet) async throws(TransactionConfirmationError) -> SignedTransactions)?

    private var preferredExtraType: TransactionConfirmationModel.ExtraType = .default
    private var availableTypes: [TransactionConfirmationModel.ExtraType] = [.default]

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

    init(
        wallet: Wallet,
        confirmation: SwapConfirmation,
        fromToken: KeeperCore.Token,
        toToken: KeeperCore.Token,
        fromAmount: BigUInt,
        transferService: TransferService,
        tonConnectService: TonConnectService,
        balanceService: BalanceService,
        settingsRepository: SettingsRepository
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

        setBatteryPrefferedExtraTypeIfNeeded()
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
        var availableTypes: [TransactionConfirmationModel.ExtraType] = [.default]

        let isBatteryAvailable = await transferService.isRelayerAvailable(
            wallet: wallet,
            transfer: nativeSwapTransfer()
        )

        if isBatteryAvailable, fromToken != .ton(.ton) {
            availableTypes.insert(.battery, at: 0)
        }

        self.availableTypes = availableTypes

        return .success(())
    }

    public func sendTransaction() async -> Result<TransactionConfirmationSendResult, TransactionConfirmationError> {
        do {
            let broadcastedTransactions = try await transferService.sendTransaction(
                wallet: wallet,
                transfer: nativeSwapTransfer(),
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
                    activityType: .swap(
                        MultichainPendingTransaction.SwapDetails(
                            fromAssetId: fromToken.assetId(network: wallet.network),
                            toAssetId: toToken.assetId(network: wallet.network)
                        )
                    )
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

    public func setPrefferedExtraType(
        extraType: TransactionConfirmationModel.ExtraType
    ) {
        preferredExtraType = extraType
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
            case .ton: .ton(getIsMaxAmount())
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
