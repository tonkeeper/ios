import BigInt
import Foundation
import TonAPI
import TonSwift

public final class NativeSwapTransactionConfirmationController: TransactionConfirmationController {
    public var signHandler: ((TransferData, Wallet) async throws -> SignedTransactions?)?

    private var preferredExtraType: TransactionConfirmationModel.ExtraType = .default
    private var availableTypes: [TransactionConfirmationModel.ExtraType] = [.default]

    private var transferType: TransferType {
        if preferredExtraType == .default {
            return .default
        } else {
            if let address = confirmation.messages.first?.targetAddress {
                return .battery(excessAddress: address.address)
            } else {
                return .default
            }
        }
    }

    @Atomic private var extraState: TransactionConfirmationModel.ExtraState

    private let wallet: Wallet
    private var confirmation: SwapConfirmation
    private let fromToken: KeeperCore.Token
    private let toToken: KeeperCore.Token
    private let fromAmount: BigUInt
    private let transferService: TransferService
    private let tonConnectService: TonConnectService
    private let balanceService: BalanceService
    private let settingsRepository: SettingsRepository
    private let batteryCalculation: BatteryCalculation

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
        batteryCalculation: BatteryCalculation
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
        self.batteryCalculation = batteryCalculation
        self.extraState = .extra(
            TransactionConfirmationModel.Extra(
                value: .default(amount: BigUInt(confirmation.gasBudget) ?? 0),
                kind: .fee
            )
        )

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
            totalFee: BigInt(confirmation.gasBudget) ?? 0
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
            transfer: .nativeSwap(confirmation)
        )

        if isBatteryAvailable, fromToken != .ton(.ton) {
            availableTypes.insert(.battery, at: 0)
        }

        self.availableTypes = availableTypes

        return .success(())
    }

    public func sendTransaction() async -> Result<Void, TransactionConfirmationError> {
        do {
            try await transferService.sendTransaction(
                wallet: wallet,
                transfer: .nativeSwap(confirmation),
                transferType: transferType,
                signClosure: { [weak self] transferData in
                    guard let self else {
                        throw TransactionConfirmationError.failedToSign
                    }

                    do {
                        guard let signed = try await signHandler?(transferData, wallet) else {
                            throw TransactionConfirmationError.failedToSign
                        }

                        return signed
                    } catch {
                        throw TransactionConfirmationError.failedToSign
                    }
                }
            )
            return .success(())
        } catch {
            return .failure(.failedToSendTransaction)
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
            extraState = .extra(
                TransactionConfirmationModel.Extra(
                    value: .default(
                        amount: BigUInt(confirmation.gasBudget) ?? 0
                    ),
                    kind: .fee
                )
            )
        case .battery:
            transferSettings.jettonTransfer = .battery
            extraState = .extra(
                TransactionConfirmationModel.Extra(
                    value: .battery(
                        charges: batteryCalculation.calculateCharges(tonAmount: BigUInt(confirmation.gasBudget) ?? 0),
                        excess: nil
                    ),
                    kind: .fee
                )
            )
        case .gasless:
            transferSettings.jettonTransfer = .gasless
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
                transfer: .nativeSwap(confirmation)
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
        case .usdtTron: .tronUSDT
        }
    }

    private func getIsMaxAmount() -> Bool {
        do {
            let balance = try balanceService.getBalance(wallet: wallet)

            switch fromToken {
            case let .ton(token):
                switch token {
                case .ton:
                    let tonAmount = BigUInt(balance.balance.tonBalance.amount)
                    let requiredForFee = BigUInt(250_000_000)

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
            case .usdtTron:
                let tronAmount = balance.tronBalance?.amount ?? 0
                let requiredForFee = BigUInt(250_000_000)

                if requiredForFee > tronAmount {
                    return false
                }

                let availableForSwap = tronAmount - requiredForFee
                return fromAmount >= availableForSwap
            }
        } catch {
            return false
        }
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
        case .usdtTron:
            tokenItem = .tronUSDT
        }

        return TransactionConfirmationModel.Amount(
            token: tokenItem,
            value: fromAmount
        )
    }
}
