import Foundation
import TKUIKit

public struct MultichainTransactionDetailsModel {
    public struct Asset {
        public let imageSource: AssetAvatarViewImageSource

        public init(imageSource: AssetAvatarViewImageSource) {
            self.imageSource = imageSource
        }
    }

    public enum Image {
        case single(Asset)
        case nft(Asset)
        case swap(left: Asset, right: Asset)
    }

    public struct AmountLine {
        public let amount: String
        public let chain: String?

        public init(amount: String, chain: String?) {
            self.amount = amount
            self.chain = chain
        }
    }

    public struct NFT {
        public let name: String
        public let collectionName: String
        public let isVerified: Bool

        public init(
            name: String,
            collectionName: String,
            isVerified: Bool
        ) {
            self.name = name
            self.collectionName = collectionName
            self.isVerified = isVerified
        }
    }

    public struct TransactionButton {
        public let title: TKThemedText
        public let url: URL
        public let browserTitle: String?

        public init(
            title: TKThemedText,
            url: URL,
            browserTitle: String?
        ) {
            self.title = title
            self.url = url
            self.browserTitle = browserTitle
        }
    }

    public let image: Image
    public let nft: NFT?
    public let amountLines: [AmountLine]
    public let fiat: String?
    public let date: String
    public let pendingTitle: String?
    public let rows: [MultichainTransactionDetailsCellContent]
    public let transactionButton: TransactionButton?

    public init(
        image: Image,
        nft: NFT? = nil,
        amountLines: [AmountLine],
        fiat: String?,
        date: String,
        pendingTitle: String? = nil,
        rows: [MultichainTransactionDetailsCellContent],
        transactionButton: TransactionButton?
    ) {
        self.image = image
        self.nft = nft
        self.amountLines = amountLines
        self.fiat = fiat
        self.date = date
        self.pendingTitle = pendingTitle
        self.rows = rows
        self.transactionButton = transactionButton
    }
}

public enum MultichainTransactionDetailsCellContent {
    case address(type: String, address: String)
    case txHash(title: String, hash: String)
    case network(title: String, name: TKThemedText, type: String)
    case fee(title: String, amount: String, fiatAmount: String?)
    case comment(title: String, value: String)
    case property(title: String, value: String)
}
