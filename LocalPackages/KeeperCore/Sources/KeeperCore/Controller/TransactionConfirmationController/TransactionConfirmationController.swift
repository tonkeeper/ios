import BigInt
import Foundation
import OperationReviewModels
import TonSwift
import TronSwift

public struct TransactionConfirmationModel {
    @frozen public enum Transaction {
        public struct Staking {
            @frozen public enum Flow {
                case deposit
                case withdraw(isCollect: Bool)
            }

            public let pool: StackingPoolInfo
            public let flow: Flow
        }

        public typealias IsMaxAmount = Bool
        @frozen public enum Transfer {
            case ton(IsMaxAmount)
            case jetton(JettonInfo)
            case nft(NFT)
            case tronUSDT
            case tronTRX
            case multichain(MultichainAsset)
        }

        case staking(Staking)
        case transfer(Transfer)
    }

    public struct Amount {
        @frozen public enum Item {
            case ton(TonToken)
            case tronUSDT
            case tronTRX
            case multichain(MultichainAsset)

            public var fractionDigits: Int {
                switch self {
                case let .ton(token):
                    token.fractionDigits
                case .tronUSDT:
                    TronToken.usdt.fractionDigits
                case .tronTRX:
                    TronToken.trx.fractionDigits
                case let .multichain(asset):
                    asset.asset.decimals
                }
            }

            public var symbol: String {
                switch self {
                case let .ton(token):
                    token.symbol
                case .tronUSDT:
                    TronToken.usdt.symbol
                case .tronTRX:
                    TronToken.trx.symbol
                case let .multichain(asset):
                    asset.asset.symbol
                }
            }
        }

        public let token: Item
        public let value: BigUInt
    }

    @frozen public enum ExtraState {
        case none
        case loading
        case extra(Extra)
    }

    public struct Extra {
        public let value: ExtraValue
        public let kind: ExtraKind
    }

    public struct ExtraOption {
        public let type: ExtraType
        public let value: ExtraValue
        public let isInsufficient: Bool
        /// A method that could not be priced or offered cannot be made payable by adding funds.
        public let isAvailable: Bool

        public init(type: ExtraType, value: ExtraValue, isInsufficient: Bool = false, isAvailable: Bool = true) {
            self.type = type
            self.value = value
            self.isInsufficient = isInsufficient
            self.isAvailable = isAvailable
        }
    }

    @frozen public enum ExtraKind {
        case fee
        case refund
    }

    @frozen public enum ExtraValue {
        case `default`(amount: BigUInt)
        case battery(charges: Int?, excess: Int?)
        case gasless(token: JettonInfo, amount: BigUInt)
        case multichain(token: MultichainAssetDetails, amount: BigUInt)

        public var extraType: ExtraType {
            switch self {
            case .default:
                return .default
            case .battery:
                return .battery
            case let .gasless(token, _):
                return .gasless(token: token)
            case let .multichain(token, _):
                return .multichain(token: token)
            }
        }
    }

    @frozen public enum ExtraType: Equatable {
        case `default`
        case battery
        case gasless(token: JettonInfo)
        case multichain(token: MultichainAssetDetails)
    }

    public let wallet: Wallet
    public let recipient: String?
    public let recipientAddress: String?
    public let transaction: Transaction
    public let amount: Amount?
    public let extraState: ExtraState
    public let extraOptions: [ExtraOption]
    public let comment: String?
    /// Whether the comment goes encrypted to the recipient's key.
    public let isCommentEncrypted: Bool
    public let availableExtraTypes: [ExtraType]
    public let isMax: Bool
    public let totalFee: BigInt
    /// What the checks found in what the confirmation will sign, where it is known before the swipe.
    public let review: OperationReview?

    /// A legacy TRON account's feed carries USDT transfers only, so a TRX transfer sent from one
    /// never shows up in a history screen.
    public var hasHistoryFeed: Bool {
        guard case .transfer(.tronTRX) = transaction else {
            return true
        }
        return wallet.isMultichain
    }

    init(
        wallet: Wallet,
        recipient: String?,
        recipientAddress: String?,
        transaction: Transaction,
        amount: Amount?,
        extraState: ExtraState,
        extraOptions: [ExtraOption] = [],
        comment: String? = nil,
        isCommentEncrypted: Bool = false,
        availableExtraTypes: [ExtraType],
        isMax: Bool = false,
        totalFee: BigInt,
        review: OperationReview? = nil
    ) {
        self.wallet = wallet
        self.recipient = recipient
        self.recipientAddress = recipientAddress
        self.transaction = transaction
        self.amount = amount
        self.extraState = extraState
        self.extraOptions = extraOptions
        self.comment = comment
        self.isCommentEncrypted = isCommentEncrypted
        self.availableExtraTypes = availableExtraTypes
        self.isMax = isMax
        self.totalFee = totalFee
        self.review = review
    }
}

@frozen public enum TransactionConfirmationError: Swift.Error {
    case failedToCalculateFee(message: String? = nil)
    /// `message` is the reason analytics reads, the same in every device language. `localizedMessage` is what the
    /// user reads instead of the generic text, for a failure that has a text of its own.
    case failedToSendTransaction(message: String? = nil, localizedMessage: String? = nil)
    case multichainTransactionFailure(MultichainTransactionFailure)
    case failedToSign(message: String? = nil)
    case cancelledByUser

    public var isCancel: Bool {
        guard case .cancelledByUser = self else {
            return false
        }
        return true
    }
}

public protocol TransactionConfirmationController: AnyObject {
    var signHandler: ((TransferData, Wallet) async throws(TransactionConfirmationError) -> SignedTransactions)? { get set }

    func getModel() -> TransactionConfirmationModel
    func setLoading()
    func emulate() async -> Result<Void, TransactionConfirmationError>
    func sendTransaction() async -> Result<TransactionConfirmationSendResult, TransactionConfirmationError>
    /// Sends under the confirm attempt's `consent`, which answers what a review asks before the signature.
    func sendTransaction(consent: OperationConsent) async -> Result<TransactionConfirmationSendResult, TransactionConfirmationError>

    func setPrefferedExtraType(extraType: TransactionConfirmationModel.ExtraType)
    func prepareFeeOptions() async
}

public extension TransactionConfirmationController {
    func setPrefferedExtraType(extraType: TransactionConfirmationModel.ExtraType) {}
    func prepareFeeOptions() async {}

    /// A controller no gate stands in front of sends as it always has.
    func sendTransaction(consent _: OperationConsent) async -> Result<TransactionConfirmationSendResult, TransactionConfirmationError> {
        await sendTransaction()
    }
}

public extension TransactionConfirmationModel {
    var isSelectedFeeUnavailable: Bool {
        guard case let .extra(extra) = extraState else { return false }
        return extraOptions.first { $0.type == extra.value.extraType }?.isAvailable == false
    }

    var isMaxAmountUsed: Bool {
        isMax
    }

    var isSelectedFeeInsufficient: Bool {
        guard case let .extra(extra) = extraState else {
            return false
        }
        return extraOptions.first { $0.type == extra.value.extraType }?.isInsufficient ?? false
    }

    /// The chain's coin a multichain transfer is short of for the fee it has selected. A relayer's
    /// fee in a token of the chain leaves the wallet short of that token instead, which the fee
    /// picker deposits.
    var nativeFeeShortage: MultichainNativeFeeShortage? {
        guard isSelectedFeeInsufficient,
              case .transfer(.multichain) = transaction,
              case let .extra(extra) = extraState,
              case let .multichain(asset, amount) = extra.value,
              asset.isNative
        else {
            return nil
        }
        return MultichainNativeFeeShortage(asset: asset, requiredAmount: amount)
    }
}
