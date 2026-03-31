import BigInt
import Foundation
import TonAPI
import TonSwift

public enum SignRawEmulationResult {
    case success(SignRawEmulation)
    case failed

    public var transactionType: TransferType {
        switch self {
        case let .success(signRawEmulation):
            return signRawEmulation.transferType
        case .failed:
            return .default
        }
    }
}

public struct SignRawEmulation {
    public struct Risk {
        public struct Jetton {
            public let walletAddress: Address
            public let quantity: BigUInt
            public let jettonPreview: JettonPreview
        }

        public let ton: UInt64
        public let jettons: [Jetton]
        public let nftsCount: Int
        public let totalAmountTreshold: Decimal = 0.2
        public let transferAllRemainingBalance: Bool
        public let totalEquivalent: Double?
    }

    public struct FeeConverted {
        public let converted: Decimal
        public let currency: Currency
    }

    public let event: AccountEvent
    public let totalFees: UInt64
    public let totalFeesConverted: FeeConverted?
    public let fee: UInt64
    public let feeConverted: FeeConverted?
    public let risk: Risk
    public let nfts: NFTsCollection
    public let transferType: TransferType
    public let traceChildrenCount: Int?
}

public protocol SignRawControllerResultHandler {
    func didConfirm(boc: String)
    func didFail(error: SomeOf<TransferError, TransactionConfirmationError>)
    func didCancel()
}

public final class SignRawController {
    public enum Error: Swift.Error {
        case noEmulationResult
    }

    public var signHandler: ((TransferData, Wallet) async throws(TransactionConfirmationError) -> SignedTransactions)?

    private let wallet: Wallet
    private let transferProvider: () async throws -> Transfer
    private let transferService: TransferService
    private let nftService: NFTService
    private let tonRatesStore: TonRatesStore
    private let currencyStore: CurrencyStore
    private let resultHandler: SignRawControllerResultHandler?

    public init(
        wallet: Wallet,
        transferProvider: @escaping () async throws -> Transfer,
        transferService: TransferService,
        nftService: NFTService,
        tonRatesStore: TonRatesStore,
        currencyStore: CurrencyStore,
        resultHandler: SignRawControllerResultHandler?
    ) {
        self.wallet = wallet
        self.transferProvider = transferProvider
        self.transferService = transferService
        self.nftService = nftService
        self.tonRatesStore = tonRatesStore
        self.currencyStore = currencyStore
        self.resultHandler = resultHandler
    }

    public func numOfMessages() async throws -> Int {
        let transfer = try await transferProvider()
        return transfer.messagesCount
    }

    public func sendTransaction(
        transactionType: TransferType
    ) async throws(SomeOf<TransferError, TransactionConfirmationError>) {
        let transfer: Transfer
        do {
            transfer = try await transferProvider()
        } catch {
            let error = TransferError.failedToCreateTransferData(
                message: "failed to get transfer data from provider due to error: \(error.localizedDescription)"
            )
            resultHandler?.didFail(error: .certain(error))
            throw .certain(error)
        }
        do {
            let boc = try await transferService.sendTransaction(
                wallet: wallet,
                transfer: transfer,
                transferType: transactionType,
                signClosure: { [weak self, wallet] transferData -> Result<SignedTransactions, TransactionConfirmationError> in
                    guard let self else {
                        return .failure(.cancelledByUser)
                    }
                    return await signTransactions(transferData: transferData, wallet: wallet)
                }
            )
            resultHandler?.didConfirm(boc: boc)
        } catch {
            let typedError = error

            if case let .secondOption(transactionError) = typedError,
               case .cancelledByUser = transactionError
            {
                throw typedError
            }
            resultHandler?.didFail(error: typedError)
            throw typedError
        }
    }

    public func cancel() {
        resultHandler?.didCancel()
    }

    public func emulate() async throws -> SignRawEmulation {
        let result = try await transferService.emulate(
            wallet: wallet,
            transfer: await transferProvider()
        )
        guard let transactionInfo = result.transactionInfo else {
            throw Error.noEmulationResult
        }
        let event = try AccountEvent(accountEvent: transactionInfo.event)
        // TODO: Update to extra
        let fee = UInt64(abs(transactionInfo.event.extra))
        let totalFees = UInt64(transactionInfo.trace.transaction.totalFees)
        let nfts = try await loadEventNFTs(event: event)
        let risk = handleRisk(risk: transactionInfo.risk)
        let currency = currencyStore.state

        let traceChildrenCount = transactionInfo.trace.children?.count

        var totalFeesConverted: SignRawEmulation.FeeConverted?
        var feeConverted: SignRawEmulation.FeeConverted?
        if let rates = tonRatesStore.state.tonRates.first(where: { $0.currency == currency }) {
            totalFeesConverted = SignRawEmulation.FeeConverted(
                converted: RateConverter().convertToDecimal(
                    amount: BigUInt(totalFees),
                    amountFractionLength: TonInfo.fractionDigits,
                    rate: rates
                ),
                currency: currency
            )
            feeConverted = SignRawEmulation.FeeConverted(
                converted: RateConverter().convertToDecimal(
                    amount: BigUInt(fee),
                    amountFractionLength: TonInfo.fractionDigits,
                    rate: rates
                ),
                currency: currency
            )
        }

        return SignRawEmulation(
            event: event,
            totalFees: totalFees,
            totalFeesConverted: totalFeesConverted,
            fee: fee,
            feeConverted: feeConverted,
            risk: risk,
            nfts: nfts,
            transferType: result.transferType,
            traceChildrenCount: traceChildrenCount
        )
    }

    private func handleRisk(risk: TonAPI.Risk) -> SignRawEmulation.Risk {
        SignRawEmulation.Risk(
            ton: UInt64(risk.ton),
            jettons: risk.jettons.compactMap {
                try? SignRawEmulation.Risk.Jetton(
                    walletAddress: Address.parse($0.walletAddress.address),
                    quantity: BigUInt(stringLiteral: $0.quantity),
                    jettonPreview: $0.jetton
                )
            },
            nftsCount: risk.nfts.count,
            transferAllRemainingBalance: risk.transferAllRemainingBalance,
            totalEquivalent: risk.totalEquivalent.flatMap(Double.init)
        )
    }

    private func loadEventNFTs(event: AccountEvent) async throws -> NFTsCollection {
        var nftAddressesToLoad = Set<Address>()
        var nfts = [Address: NFT]()
        for action in event.actions {
            switch action.type {
            case let .nftItemTransfer(nftItemTransfer):
                nftAddressesToLoad.insert(nftItemTransfer.nftAddress)
            case let .nftPurchase(nftPurchase):
                nfts[nftPurchase.nft.address] = nftPurchase.nft
                try? nftService.saveNFT(nft: nftPurchase.nft, network: wallet.network)
            default: continue
            }
        }

        if let loadedNFTs = try? await nftService.loadNFTs(addresses: Array(nftAddressesToLoad), network: wallet.network) {
            nfts.merge(loadedNFTs, uniquingKeysWith: { $1 })
        }

        return NFTsCollection(nfts: nfts)
    }

    private func signTransactions(
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
