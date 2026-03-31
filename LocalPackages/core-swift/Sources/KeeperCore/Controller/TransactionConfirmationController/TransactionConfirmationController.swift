import BigInt
import Foundation
import TonSwift
import TronSwift

public struct TransactionConfirmationModel {
    public enum Transaction {
        public struct Staking {
            public enum Flow {
                case deposit
                case withdraw(isCollect: Bool)
            }

            public let pool: StackingPoolInfo
            public let flow: Flow
        }

        public typealias IsMaxAmount = Bool
        public enum Transfer {
            case ton(IsMaxAmount)
            case jetton(JettonInfo)
            case nft(NFT)
            case tronUSDT
        }

        case staking(Staking)
        case transfer(Transfer)
    }

    public struct Amount {
        public enum Item {
            case ton(TonToken)
            case tronUSDT

            public var fractionDigits: Int {
                switch self {
                case let .ton(token):
                    token.fractionDigits
                case .tronUSDT:
                    TronSwift.USDT.fractionDigits
                }
            }

            public var symbol: String {
                switch self {
                case let .ton(token):
                    token.symbol
                case .tronUSDT:
                    TronSwift.USDT.symbol
                }
            }
        }

        public let token: Item
        public let value: BigUInt
    }

    public enum ExtraState {
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
    }

    public enum ExtraKind {
        case fee
        case refund
    }

    public enum ExtraValue {
        case `default`(amount: BigUInt)
        case battery(charges: Int?, excess: Int?)
        case gasless(token: JettonInfo, amount: BigUInt)

        public var amount: BigUInt? {
            switch self {
            case let .default(amount):
                return amount
            case .battery:
                return nil
            case let .gasless(_, amount):
                return amount
            }
        }

        public var extraType: ExtraType {
            switch self {
            case .default:
                return .default
            case .battery:
                return .battery
            case let .gasless(token, _):
                return .gasless(token: token)
            }
        }
    }

    public enum ExtraType: Equatable {
        case `default`
        case battery
        case gasless(token: JettonInfo)
    }

    public let wallet: Wallet
    public let recipient: String?
    public let recipientAddress: String?
    public let transaction: Transaction
    public let amount: Amount?
    public let extraState: ExtraState
    public let extraOptions: [ExtraOption]
    public let comment: String?
    public let availableExtraTypes: [ExtraType]
    public let isMax: Bool
    public let totalFee: BigInt

    init(
        wallet: Wallet,
        recipient: String?,
        recipientAddress: String?,
        transaction: Transaction,
        amount: Amount?,
        extraState: ExtraState,
        extraOptions: [ExtraOption] = [],
        comment: String? = nil,
        availableExtraTypes: [ExtraType],
        isMax: Bool = false,
        totalFee: BigInt
    ) {
        self.wallet = wallet
        self.recipient = recipient
        self.recipientAddress = recipientAddress
        self.transaction = transaction
        self.amount = amount
        self.extraState = extraState
        self.extraOptions = extraOptions
        self.comment = comment
        self.availableExtraTypes = availableExtraTypes
        self.isMax = isMax
        self.totalFee = totalFee
    }
}

public enum TransactionConfirmationError: Swift.Error {
    case failedToCalculateFee
    case failedToSendTransaction(message: String? = nil)
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
    func sendTransaction() async -> Result<Void, TransactionConfirmationError>

    func setPrefferedExtraType(extraType: TransactionConfirmationModel.ExtraType)
}

public extension TransactionConfirmationController {
    func setPrefferedExtraType(extraType: TransactionConfirmationModel.ExtraType) {}
}

public extension TransactionConfirmationModel {
    var isMaxAmountUsed: Bool {
        isMax
    }
}
