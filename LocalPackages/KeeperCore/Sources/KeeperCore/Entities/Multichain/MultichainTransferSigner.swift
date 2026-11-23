import Foundation
import TonTransport

/// A transaction of one message as the Ledger TON app signs it. The module and its main class share a name, so
/// `TonTransport.Transaction` would name a member of the class.
public typealias LedgerTonTransaction = Transaction

/// Who signs a multichain transfer.
@frozen public enum MultichainTransferSigner {
    /// The app, with the wallet's mnemonic unlocked by the passcode the closure asks the user for.
    case mnemonic(passcodeProvider: () async -> String?)
    /// A hardware wallet. Nothing falls back to signing in the app.
    case device(DeviceTransferSigner)
}

/// Signs on a hardware wallet, one closure per kind of chain and message. Each throws `CancellationError`
/// when the user cancels or refuses.
public struct DeviceTransferSigner: Sendable {
    /// Returns `r ‖ s ‖ recovery id`.
    public let evm: @Sendable (EVMDeviceSignRequest) async throws -> Data
    /// Signs a transaction's protobuf `raw_data` and returns `r ‖ s ‖ v`.
    public let tron: @Sendable (_ rawData: Data) async throws -> Data
    /// Signs a transaction's message and returns the ed25519 signature.
    public let solana: @Sendable (_ message: Data) async throws -> Data
    /// Returns a DER signature, without its sighash byte, for each input in order.
    public let bitcoin: @Sendable (BitcoinDeviceSignRequest) async throws -> [Data]
    /// Signs TON transactions of one message each, in order, and returns the signature of each one's signing message.
    public let ton: @Sendable (_ transactions: [LedgerTonTransaction]) async throws -> [Data]
    /// Signs a `personal_sign` message and returns `r ‖ s ‖ v`.
    public let evmMessage: @Sendable (_ message: Data) async throws -> Data
    /// Signs EIP-712 data by its domain separator and message hash and returns `r ‖ s ‖ v`.
    public let evmTypedData: @Sendable (_ domainSeparator: Data, _ messageHash: Data) async throws -> Data
    /// Signs a `tron_signMessage` message and returns `r ‖ s ‖ v`.
    public let tronMessage: @Sendable (_ message: Data) async throws -> Data

    public init(
        evm: @escaping @Sendable (EVMDeviceSignRequest) async throws -> Data,
        tron: @escaping @Sendable (_ rawData: Data) async throws -> Data,
        solana: @escaping @Sendable (_ message: Data) async throws -> Data,
        bitcoin: @escaping @Sendable (BitcoinDeviceSignRequest) async throws -> [Data],
        ton: @escaping @Sendable (_ transactions: [LedgerTonTransaction]) async throws -> [Data],
        evmMessage: @escaping @Sendable (_ message: Data) async throws -> Data,
        evmTypedData: @escaping @Sendable (_ domainSeparator: Data, _ messageHash: Data) async throws -> Data,
        tronMessage: @escaping @Sendable (_ message: Data) async throws -> Data
    ) {
        self.evm = evm
        self.tron = tron
        self.solana = solana
        self.bitcoin = bitcoin
        self.ton = ton
        self.evmMessage = evmMessage
        self.evmTypedData = evmTypedData
        self.tronMessage = tronMessage
    }
}

/// A spend from a Ledger account's one native SegWit address, `0/0` of the account: every input is signed
/// by its key, and an output to it is change.
public struct BitcoinDeviceSignRequest: Sendable {
    public struct Input: Sendable {
        /// In the byte order the transaction carries it, the reverse of the displayed id.
        public let previousTxid: Data
        public let previousIndex: UInt32
        public let amount: UInt64
        public let script: Data
        /// The transaction the input spends, so the device can check its amount; `nil` when it was not found.
        public let previousTransaction: Data?
        public let sequence: UInt32
    }

    public struct Output: Sendable {
        public let amount: UInt64
        public let script: Data
        public let isChange: Bool
    }

    /// The account's extended key, `xpub…` as the Bitcoin app reports it, so the device can be checked to hold it.
    public let accountXpub: String
    /// The compressed key of the address.
    public let publicKey: Data
    public let version: UInt32
    public let lockTime: UInt32
    public let inputs: [Input]
    public let outputs: [Output]
}

public struct EVMDeviceSignRequest: Sendable {
    public let chainId: UInt64
    /// The unsigned transaction as the device parses it: the type byte of a typed one, then its RLP.
    public let transaction: Data
    /// The ERC-20 contract a token transfer or approval calls, so the device can name the token.
    public let tokenContract: String?
}
