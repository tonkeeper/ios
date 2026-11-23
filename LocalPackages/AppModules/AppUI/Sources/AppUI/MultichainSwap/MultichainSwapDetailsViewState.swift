import TKUIKit

public struct MultichainSwapDetailsViewState {
    public enum Status {
        case pending
        case done
        case failed
    }

    public struct Amount {
        public let value: String
        public let avatarSource: AssetAvatarViewImageSource

        public init(value: String, avatarSource: AssetAvatarViewImageSource) {
            self.value = value
            self.avatarSource = avatarSource
        }
    }

    public enum Transaction {
        /// Opens one of the swap's transactions in its chain's explorer; a long press copies its hash.
        case link(MultichainTransactionDetailsModel.TransactionButton, hash: String)
        /// The transaction on the receiving chain is not there yet.
        case receiving
    }

    public let send: Amount
    public let receive: Amount
    public let date: String
    public let networkFee: String?
    public let status: Status
    public let transactions: [Transaction]

    public init(
        send: Amount,
        receive: Amount,
        date: String,
        networkFee: String?,
        status: Status,
        transactions: [Transaction]
    ) {
        self.send = send
        self.receive = receive
        self.date = date
        self.networkFee = networkFee
        self.status = status
        self.transactions = transactions
    }
}
