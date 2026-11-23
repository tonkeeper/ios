import Foundation

public struct LedgerAccountsScreenState: Equatable {
    public struct Account: Identifiable, Equatable {
        public struct Address: Equatable, Identifiable {
            public let network: String
            /// The short address, with anything worth knowing about it, such as the balance.
            public let value: String

            public var id: String {
                network
            }

            public init(network: String, value: String) {
                self.network = network
                self.value = value
            }
        }

        /// The account index on the Ledger.
        public let id: Int
        public let title: String
        public let addresses: [Address]
        public let isAdded: Bool
        public let isSelected: Bool

        public init(id: Int, title: String, addresses: [Address], isAdded: Bool, isSelected: Bool) {
            self.id = id
            self.title = title
            self.addresses = addresses
            self.isAdded = isAdded
            self.isSelected = isSelected
        }
    }

    public var accounts: [Account]
    /// The Ledger is reading accounts: the first ones, a further page or one by its number.
    public var isReading: Bool
    public var canShowMore: Bool
    public var isContinueEnabled: Bool

    public init(accounts: [Account], isReading: Bool, canShowMore: Bool, isContinueEnabled: Bool) {
        self.accounts = accounts
        self.isReading = isReading
        self.canShowMore = canShowMore
        self.isContinueEnabled = isContinueEnabled
    }
}
