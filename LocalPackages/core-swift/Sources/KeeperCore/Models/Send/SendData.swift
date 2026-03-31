import BigInt
import Foundation

public enum SendData {
    case ton(TonSendData)
    case tron(TronSendData)
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
