import BigInt
import Foundation
import TonAPI
import TonSwift

final class JettonTransferTransactionConfirmationController: TransactionConfirmationController {
    private var preferredExtraType: TransactionConfirmationModel.ExtraType?
    private var availableTypes: [TransactionConfirmationModel.ExtraType] = []

    func getModel() -> TransactionConfirmationModel {
        createModel()
    }

    func setLoading() {
        extraState = .loading
    }

    func emulate() async -> Result<Void, TransactionConfirmationError> {
        var availableTypes: [TransactionConfirmationModel.ExtraType] = [.default]

        do {
            defer {
                self.availableTypes = availableTypes
            }

            let amountToSend = jettonItem.jettonInfo.scaleValue.flatMap {
                BigUInt.divide(
                    self.amount, scaleN: jettonItem.jettonInfo.fractionDigits,
                    by: $0, scaleD: jettonItem.jettonInfo.fractionDigits,
                    resultScale: jettonItem.jettonInfo.fractionDigits
                )
            } ?? getAmountValue().value

            let transfer: Transfer = .jetton(jettonItem, transferAmount: BigUInt(65_000_000), amount: isMax ? 1 : amountToSend, recipient: recipient, comment: comment)

            let (gaslessAvailable, isBatteryAvailable) =
                await(
                    transferService.isGaslessAvailable(wallet: wallet, transfer: transfer),
                    transferService.isRelayerAvailable(wallet: wallet, transfer: transfer)
                )

            if isBatteryAvailable {
                availableTypes.append(.battery)
            }

            if gaslessAvailable {
                availableTypes.append(.gasless(token: jettonItem.jettonInfo))
            }

            let isMax = await {
                do {
                    let balance = try await balanceService.loadWalletBalance(wallet: wallet, currency: .USD)
                    let jettonBalance = balance.balance.jettonsBalance.first(where: { $0.item.jettonInfo == jettonItem.jettonInfo
                    })
                    let jettonAmount = jettonBalance?.scaledBalance ?? jettonBalance?.quantity
                    return jettonAmount == amount
                } catch {
                    return false
                }
            }()
            self.isMax = isMax

            let preferredType: TransactionConfirmationModel.ExtraType = {
                if let preferredExtraType { return preferredExtraType }
                switch settingsRepository.getTransferSettings(wallet: wallet).jettonTransfer {
                case .default:
                    return .default
                case .gasless:
                    return .gasless(token: jettonItem.jettonInfo)
                case .battery:
                    return isBatteryAvailable ? .battery : .default
                }
            }()

            let result = try await transferService.emulate(
                wallet: wallet,
                transfer: transfer,
                params: [.init(address: wallet.address.toRaw(), balance: Int64(2_000_000_000))],
                preferredExtraType: preferredType
            )
            self.emulationResult = result
            await updateFee(emulationResult: emulationResult)
            return .success(())
        } catch {
            self.emulationResult = nil
            await updateFee(emulationResult: nil)
            return .failure(.failedToCalculateFee)
        }
    }

    func sendTransaction() async -> Result<Void, TransactionConfirmationError> {
        do {
            let transferAmount: BigUInt = {
                let minimumTransferAmount = BigUInt(stringLiteral: "50000000")
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

            try await transferService.sendTransaction(
                wallet: wallet,
                transfer: .jetton(
                    jettonItem,
                    transferAmount: transferAmount,
                    amount: amountToSend,
                    recipient: recipient,
                    comment: comment
                ),
                transferType: emulationResult?.transferType ?? .default,
                signClosure: { [weak self, wallet] transferData in
                    guard let signed = try? await self?.signHandler?(transferData, wallet) else {
                        throw TransactionConfirmationError.failedToSign
                    }
                    return signed
                }
            )

            return .success(())
        } catch {
            return .failure(.failedToSendTransaction)
        }
    }

    func setPrefferedExtraType(extraType: TransactionConfirmationModel.ExtraType) {
        preferredExtraType = extraType
        var transferSettings = settingsRepository.getTransferSettings(wallet: wallet)
        switch extraType {
        case .default:
            transferSettings.jettonTransfer = .default
        case .battery:
            transferSettings.jettonTransfer = .battery
        case .gasless:
            transferSettings.jettonTransfer = .gasless
        }
        try? settingsRepository.setTransferSettings(wallet: wallet, transferSettings: transferSettings)
    }

    var signHandler: ((TransferData, Wallet) async throws -> SignedTransactions?)?

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
    private let sendService: SendService
    private let blockchainService: BlockchainService
    private let ratesStore: TonRatesStore
    private let currencyStore: CurrencyStore
    private let transferService: TransferService
    private let ratesService: RatesService
    private let balanceService: BalanceService
    private let settingsRepository: SettingsRepository
    private let batteryCalculation: BatteryCalculation

    init(
        wallet: Wallet,
        recipient: TonRecipient,
        jettonItem: JettonItem,
        amount: BigUInt,
        comment: String?,
        sendService: SendService,
        blockchainService: BlockchainService,
        ratesStore: TonRatesStore,
        currencyStore: CurrencyStore,
        transferService: TransferService,
        ratesService: RatesService,
        balanceService: BalanceService,
        settingsRepository: SettingsRepository,
        batteryCalculation: BatteryCalculation
    ) {
        self.wallet = wallet
        self.recipient = recipient
        self.jettonItem = jettonItem
        self.amount = amount
        self.comment = comment
        self.sendService = sendService
        self.blockchainService = blockchainService
        self.ratesStore = ratesStore
        self.currencyStore = currencyStore
        self.transferService = transferService
        self.ratesService = ratesService
        self.balanceService = balanceService
        self.settingsRepository = settingsRepository
        self.batteryCalculation = batteryCalculation
    }

    private func createModel() -> TransactionConfirmationModel {
        TransactionConfirmationModel(
            wallet: wallet,
            recipient: recipient.recipientAddress.name,
            recipientAddress: recipient.recipientAddress.addressString,
            transaction: .transfer(.jetton(jettonItem.jettonInfo)),
            amount: getAmountValue(),
            extraState: extraState,
            comment: comment,
            availableExtraTypes: self.availableTypes,
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
                    case .battery, .default:
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

    func signTransfer(_ transferData: TransferData) async throws -> SignedTransactions {
        guard let signHandler,
              let signedData = try await signHandler(transferData, wallet) else { throw TransactionConfirmationError.failedToSign }
        return signedData
    }
}
