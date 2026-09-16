import BigInt
import Foundation

public enum SendData {
    case ton(TonSendData)
    case tron(TronSendData)
    case multichain(MultichainSendData)
}

public struct TonSendData {
    public enum Item {
        case token(TonToken, amount: BigUInt)
        case nft(NFT)
    }

    public let wallet: Wallet
    public let recipient: TonRecipient
    public let item: Item
    public let comment: String?
    public let isMaxAmount: Bool
    /// When set (e.g. withdraw/exchange flow), show this address on Confirm instead of recipient's address.
    public let recipientDisplayAddress: String?
    /// Estimated exchange duration in seconds (e.g. for withdraw flow).
    public let estimatedDurationSeconds: Int?

    public init(
        wallet: Wallet,
        recipient: TonRecipient,
        item: Item,
        comment: String?,
        isMaxAmount: Bool = false,
        recipientDisplayAddress: String? = nil,
        estimatedDurationSeconds: Int? = nil
    ) {
        self.wallet = wallet
        self.recipient = recipient
        self.item = item
        self.comment = comment
        self.isMaxAmount = isMaxAmount
        self.recipientDisplayAddress = recipientDisplayAddress
        self.estimatedDurationSeconds = estimatedDurationSeconds
    }
}

public struct TronSendData {
    public enum Item {
        case usdt(amount: BigUInt)
        case trx(amount: BigUInt)

        public var token: TronToken {
            switch self {
            case .usdt:
                .usdt
            case .trx:
                .trx
            }
        }

        public var amount: BigUInt {
            switch self {
            case let .usdt(amount), let .trx(amount):
                amount
            }
        }

        public func settingAmount(_ amount: BigUInt) -> Item {
            switch self {
            case .usdt:
                .usdt(amount: amount)
            case .trx:
                .trx(amount: amount)
            }
        }
    }

    public let wallet: Wallet
    public let recipient: TronRecipient
    public let item: Item
    /// When set (e.g. withdraw/exchange flow), show this address on Confirm instead of recipient's address.
    public let recipientDisplayAddress: String?
    /// Estimated exchange duration in seconds (e.g. for withdraw flow).
    public let estimatedDurationSeconds: Int?

    public init(
        wallet: Wallet,
        recipient: TronRecipient,
        item: Item,
        recipientDisplayAddress: String? = nil,
        estimatedDurationSeconds: Int? = nil
    ) {
        self.wallet = wallet
        self.recipient = recipient
        self.item = item
        self.recipientDisplayAddress = recipientDisplayAddress
        self.estimatedDurationSeconds = estimatedDurationSeconds
    }
}

public struct MultichainSendData {
    public let wallet: Wallet
    public let recipient: MultichainRecipient
    public let asset: MultichainAsset
    public let amount: BigUInt
    public let comment: String?
    public let isMaxAmount: Bool

    public init(
        wallet: Wallet,
        recipient: MultichainRecipient,
        asset: MultichainAsset,
        amount: BigUInt,
        comment: String?,
        isMaxAmount: Bool
    ) {
        self.wallet = wallet
        self.recipient = recipient
        self.asset = asset
        self.amount = amount
        self.comment = comment
        self.isMaxAmount = isMaxAmount
    }
}
