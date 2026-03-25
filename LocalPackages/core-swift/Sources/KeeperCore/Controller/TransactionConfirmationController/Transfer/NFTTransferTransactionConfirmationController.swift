import BigInt
import Foundation
import TonAPI
import TonSwift

final class NFTTransferTransactionConfirmationController: TransactionConfirmationController {
    func getModel() -> TransactionConfirmationModel {
        createModel()
    }

    func setLoading() {
        extraState = .loading
    }

    private var preferredExtraType: TransactionConfirmationModel.ExtraType?
    private var availableTypes: [TransactionConfirmationModel.ExtraType] = []

    func setPrefferedExtraType(extraType: TransactionConfirmationModel.ExtraType) {
        preferredExtraType = extraType
        var transferSettings = settingsRepository.getTransferSettings(wallet: wallet)
        switch extraType {
        case .default:
            transferSettings.jettonTransfer = .default
        case .battery:
            transferSettings.jettonTransfer = .battery
        case .gasless:
            return
        }
        try? settingsRepository.setTransferSettings(wallet: wallet, transferSettings: transferSettings)
    }

    func emulate() async -> Result<Void, TransactionConfirmationError> {
        var availableTypes: [TransactionConfirmationModel.ExtraType] = [.default]

        do {
            defer {
                self.availableTypes = availableTypes
            }

            let transfer: Transfer = .nft(nft, transferAmount: BigUInt(65_000_000), recipient: recipient, comment: comment)

            let isBatteryAvailable = await transferService.isRelayerAvailable(wallet: wallet, transfer: transfer)

            if isBatteryAvailable {
                availableTypes.append(.battery)
            }

            let preferredType: TransactionConfirmationModel.ExtraType = {
                if let preferredExtraType { return preferredExtraType }
                switch settingsRepository.getTransferSettings(wallet: wallet).jettonTransfer {
                case .default:
                    return .default
                case .gasless:
                    return isBatteryAvailable ? .battery : .default
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
                guard let emulationResult else {
                    return BigUInt(100_000_000)
                }
                let emulationExtra = emulationResult.extra.amount
                let minimumTransferAmount = BigUInt(stringLiteral: "50000000")

                var transferAmount = {
                    switch emulationExtra {
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
            try await transferService.sendTransaction(
                wallet: wallet,
                transfer: .nft(nft, transferAmount: transferAmount, recipient: recipient, comment: comment),
                transferType: emulationResult?.transferType ?? .default,
                signClosure: { [weak self, wallet] transferData -> Result<SignedTransactions, TransactionConfirmationError> in
                    guard let self else {
                        return .failure(.cancelledByUser)
                    }
                    return await signedTransactions(transferData: transferData, wallet: wallet)
                }
            )
            return .success(())
        } catch {
            if case let .secondOption(transactionError) = error,
               case .cancelledByUser = transactionError
            {
                return .failure(.cancelledByUser)
            }
            return .failure(
                .failedToSendTransaction(
                    message: error.localizedDescription
                )
            )
        }
    }

    var signHandler: ((TransferData, Wallet) async throws(TransactionConfirmationError) -> SignedTransactions)?

    @Atomic private var emulationResult: TransferEmulationResult?
    @Atomic private var extraState: TransactionConfirmationModel.ExtraState = .loading
    @Atomic private var totalFee: BigInt = 0

    private let wallet: Wallet
    private let recipient: TonRecipient
    private let nft: NFT
    private let comment: String?
    private let recipientDisplayAddress: String?
    private let sendService: SendService
    private let blockchainService: BlockchainService
    private let ratesStore: TonRatesStore
    private let currencyStore: CurrencyStore
    private let transferService: TransferService
    private let ratesService: RatesService
    private let settingsRepository: SettingsRepository
    private let batteryCalculation: BatteryCalculation

    init(
        wallet: Wallet,
        recipient: TonRecipient,
        nft: NFT,
        comment: String?,
        recipientDisplayAddress: String? = nil,
        sendService: SendService,
        blockchainService: BlockchainService,
        ratesStore: TonRatesStore,
        currencyStore: CurrencyStore,
        transferService: TransferService,
        ratesService: RatesService,
        settingsRepository: SettingsRepository,
        batteryCalculation: BatteryCalculation
    ) {
        self.wallet = wallet
        self.recipient = recipient
        self.nft = nft
        self.comment = comment
        self.recipientDisplayAddress = recipientDisplayAddress
        self.sendService = sendService
        self.blockchainService = blockchainService
        self.ratesStore = ratesStore
        self.currencyStore = currencyStore
        self.transferService = transferService
        self.ratesService = ratesService
        self.settingsRepository = settingsRepository
        self.batteryCalculation = batteryCalculation
    }

    private func createModel() -> TransactionConfirmationModel {
        return TransactionConfirmationModel(
            wallet: wallet,
            recipient: recipient.recipientAddress.name,
            recipientAddress: recipientDisplayAddress ?? recipient.recipientAddress.addressString,
            transaction: .transfer(.nft(nft)),
            amount: nil,
            extraState: extraState,
            comment: comment,
            availableExtraTypes: [.default, .battery],
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
        extraType = emulationResult.transferType.isBattery ? .battery : .default

        let (amount, isRefund) = {
            switch extra.amount {
            case let .fee(fee):
                return (fee, false)
            case let .refund(refund):
                return (refund, true)
            }
        }()

        if let totalFee = emulationResult.transactionInfo?.trace.transaction.totalFees {
            self.totalFee = BigInt(totalFee)
        }

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

        self.extraState = .extra(
            TransactionConfirmationModel.Extra(
                value: value,
                kind: isRefund ? .refund : .fee
            )
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
