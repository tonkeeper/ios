import Foundation
@testable import KeeperCore
import TKBatteryAPI
import TonAPI
import TonSwift
import TronSwift
import TronSwiftAPI

/// The node requests by path and the passcode prompt, in the order the engine makes them, and what
/// the battery was handed to relay. The node stub records from URL loading threads, so the log is
/// guarded by its lock.
final class TronSwapCalls: @unchecked Sendable {
    private let lock = NSLock()
    private var calls = [String]()
    private var transactions = [String]()
    private var instantFees = [String?]()

    var recorded: [String] {
        lock.withLock { calls }
    }

    var relayed: [String] {
        lock.withLock { transactions }
    }

    /// The GRAM payment relayed with each transaction, if any.
    var relayedInstantFees: [String?] {
        lock.withLock { instantFees }
    }

    func record(_ call: String) {
        lock.withLock { calls.append(call) }
    }

    func relay(_ transaction: String, instantFee: String?) {
        lock.withLock {
            transactions.append(transaction)
            instantFees.append(instantFee)
        }
    }
}

/// Answers the account and bandwidth reads of the fee estimate as an activated account with no
/// bandwidth of its own, prices a USDT transfer, and builds the TRX or USDT transfer of 10 to the
/// deposit address `owner` asks for as a node does, unless it `refusesTransaction`; anything else,
/// the battery's TRON config included, fails.
final class TronNodeStub: URLProtocol {
    static var calls: TronSwapCalls?
    static var owner = Data()
    static var deposit = Data()
    static var refusesTransaction = false
    static var refusesFeeEstimate = false
    static let expiration: Int64 = 1_790_000_060_000

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TronNodeStub.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let path = request.url?.path ?? ""
        Self.calls?.record(path)
        let (statusCode, body): (Int, String) = switch path {
        case "/wallet/getaccount":
            (200, #"{"create_time": 1}"#)
        case "/wallet/getaccountnet":
            (200, "{}")
        case "/wallet/createtransaction":
            Self.refusesTransaction ? (500, "") : (200, Self.transaction(Self.nativeTransfer(), type: "TransferContract"))
        case "/wallet/triggersmartcontract":
            Self.refusesTransaction
                ? (500, "")
                : (200, #"{"result": {"result": true}, "transaction": \#(Self.transaction(Self.usdtTransfer(), type: "TriggerSmartContract"))}"#)
        case "/wallet/triggerconstantcontract":
            Self.refusesFeeEstimate ? (500, "") : (200, #"{"result": {"result": true}, "energy_used": 64285, "transaction": {"raw_data_hex": "\#(Self.hex(Self.usdtTransfer()))"}}"#)
        default:
            (500, "")
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// `raw_data` of a TransferContract of 10 TRX from `owner` to the deposit address, which
    /// `Transaction.verify` accepts.
    private static func nativeTransfer() -> [UInt8] {
        let transfer = field(1, bytes: Array(owner)) + field(2, bytes: Array(deposit)) + field(3, varint: 10_000_000)
        return rawData(type: 1, url: "type.googleapis.com/protocol.TransferContract", contract: transfer)
    }

    /// `raw_data` of a TriggerSmartContract that transfers 10 USDT from `owner` to the deposit address
    /// within the fee limit the app asks for, which `Transaction.verify` accepts.
    private static func usdtTransfer() -> [UInt8] {
        let method = TransferMethod(to: try! TronSwift.Address(raw: deposit), amount: 10_000_000)
        let data = ContractCoding.methodId(signature: method.signature) + ContractCoding.encode(parameters: method.arguments)
        let call = field(1, bytes: Array(owner)) + field(2, bytes: Array(USDT.address.raw)) + field(4, bytes: Array(data))
        return rawData(type: 31, url: "type.googleapis.com/protocol.TriggerSmartContract", contract: call)
            + field(18, varint: UInt64(TronApi.usdtTransferFeeLimit))
    }

    private static func rawData(type: UInt64, url: String, contract: [UInt8]) -> [UInt8] {
        let parameter = field(1, bytes: Array(url.utf8)) + field(2, bytes: contract)
        return field(1, bytes: [0xF9, 0x6C])
            + field(4, bytes: Array(repeating: 0xAB, count: 8))
            + field(8, varint: UInt64(expiration))
            + field(11, bytes: field(1, varint: type) + field(2, bytes: parameter))
            + field(14, varint: UInt64(expiration - 60000))
    }

    /// The JSON a node wraps `rawData` in.
    private static func transaction(_ rawData: [UInt8], type: String) -> String {
        #"{"txID": "node", "raw_data_hex": "\#(hex(rawData))", "visible": true, "raw_data": {"ref_block_bytes": "f96c", "ref_block_hash": "abababababababab", "expiration": \#(expiration), "timestamp": \#(expiration - 60000), "contract": [{"type": "\#(type)"}]}}"#
    }

    private static func hex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02hhx", $0) }.joined()
    }

    private static func varint(_ value: UInt64) -> [UInt8] {
        var value = value
        var bytes = [UInt8]()
        repeat {
            bytes.append(UInt8(value & 0x7F) | (value > 0x7F ? 0x80 : 0))
            value >>= 7
        } while value > 0
        return bytes
    }

    private static func field(_ number: UInt64, varint value: UInt64) -> [UInt8] {
        varint(number << 3) + varint(value)
    }

    private static func field(_ number: UInt64, bytes: [UInt8]) -> [UInt8] {
        varint(number << 3 | 2) + varint(UInt64(bytes.count)) + bytes
    }
}

struct BatteryHostStub: APIHostProvider {
    var basePath: String {
        "https://battery.test"
    }
}

struct UnusedStub: Error {}

/// Prices the TRON transfer in charges and in a GRAM instant fee and relays what it is handed; the
/// battery balance cannot be read.
struct BatteryServiceStub: BatteryService {
    let calls: TronSwapCalls
    let estimate: TKBatteryAPI.Components.Schemas.EstimatedTronTx
    var balance: BatteryBalance? = nil
    var balanceProvider: (() async throws -> BatteryBalance)? = nil

    func estimateTronTransaction(
        wallet _: Wallet,
        tronAddress _: String,
        energy _: Int,
        bandwidth _: Int
    ) async throws -> TKBatteryAPI.Components.Schemas.EstimatedTronTx {
        estimate
    }

    func loadBatteryBalance(wallet _: Wallet) async throws -> BatteryBalance {
        if let balanceProvider { return try await balanceProvider() }
        guard let balance else { throw UnusedStub() }
        return balance
    }

    func loadRechargeMethods(wallet _: Wallet, includeRechargeOnly _: Bool) async throws -> [BatteryRechargeMethod] {
        throw UnusedStub()
    }

    func getRechargeMethods(wallet _: Wallet, includeRechargeOnly _: Bool) -> [BatteryRechargeMethod] {
        []
    }

    func loadBatteryConfig(wallet _: Wallet) async throws -> TKBatteryAPI.Components.Schemas.Config {
        throw UnusedStub()
    }

    func loadTransactionInfo(
        wallet _: Wallet,
        boc _: String
    ) async throws -> (info: TonAPI.Components.Schemas.MessageConsequences, isBatteryAvailable: Bool, excess: UInt?) {
        throw UnusedStub()
    }

    func loadGasslessCommission(wallet _: Wallet, jettonMasterAddress _: String, boc _: String) async throws -> String {
        throw UnusedStub()
    }

    func sendTransaction(wallet _: Wallet, boc _: String, proof _: String?, headers _: [String: String]) async throws -> String? {
        throw UnusedStub()
    }

    func makePurchase(
        wallet _: Wallet,
        transactionId _: String,
        promocode _: String?
    ) async throws -> TKBatteryAPI.Components.Schemas.iOSBatteryPurchaseStatus {
        throw UnusedStub()
    }

    func loadPurchases(wallet _: Wallet) async throws -> [BatteryPurchase] {
        throw UnusedStub()
    }

    func migrateBattery(
        from _: Wallet,
        to _: Wallet,
        proof _: BatteryMigrationProof
    ) async throws -> TKBatteryAPI.Components.Schemas.BatteryMigration {
        throw UnusedStub()
    }

    func loadTronTransactions(wallet _: Wallet, limit _: Int, maxTimestamp _: Int64?) async throws -> [TronTransaction] {
        throw UnusedStub()
    }

    func sendTronTransaction(
        wallet _: Wallet,
        tronAddress _: String,
        transaction: String,
        energy _: Int,
        bandwidth _: Int,
        instantFeeTransaction: String?,
        userPublicKey _: String?
    ) async throws -> String {
        calls.relay(transaction, instantFee: instantFeeTransaction)
        return "relayed"
    }

    func hasPendingTransactions(wallet _: Wallet) async throws -> Bool {
        throw UnusedStub()
    }

    func verifyPromocode(wallet _: Wallet, promocode _: String) async throws {
        throw UnusedStub()
    }
}

/// Reads `seqno` when it is given one, and fails anything else.
struct SendServiceStub: SendService {
    var seqno: UInt64?

    func loadSeqno(wallet _: Wallet) async throws -> UInt64 {
        guard let seqno else {
            throw UnusedStub()
        }
        return seqno
    }

    func loadTransactionInfo(
        boc _: String,
        wallet _: Wallet,
        params _: [EmulateMessageToWalletRequestParamsInner]?,
        currency _: Currency?
    ) async throws -> TonAPI.Components.Schemas.MessageConsequences {
        throw UnusedStub()
    }

    func sendTransaction(boc _: String, wallet _: Wallet, headers _: [String: String]) async throws {
        throw UnusedStub()
    }

    func sendTransactions(batch _: [String], wallet _: Wallet) async throws {
        throw UnusedStub()
    }

    func getTimeoutSafely(wallet _: Wallet, TTL _: UInt64) async -> UInt64 {
        0
    }

    func getGaslessRelayAddress(wallet _: Wallet) async throws -> TonSwift.Address {
        throw UnusedStub()
    }

    func getJettonCustomPayload(wallet _: Wallet, jetton _: TonSwift.Address) async throws -> JettonTransferPayload {
        throw UnusedStub()
    }

    func getIndexingLatency(wallet _: Wallet) async throws -> Int {
        throw UnusedStub()
    }
}

/// Holds `tonBalance` nanotons when it is given one, and cannot be read otherwise.
struct BalanceServiceStub: BalanceService {
    var tonBalance: Int64?

    func loadWalletBalance(wallet: Wallet, currency _: Currency, includingTransferFees _: Bool) async throws -> WalletBalance {
        try getBalance(wallet: wallet)
    }

    func getBalance(wallet _: Wallet) throws -> WalletBalance {
        guard let tonBalance else {
            throw UnusedStub()
        }
        return WalletBalance(
            date: Date(),
            balance: KeeperCore.Balance(tonBalance: TonBalance(amount: tonBalance), jettonsBalance: []),
            stacking: [],
            batteryBalance: nil,
            tronBalance: nil
        )
    }
}

/// A TON-only wallet of twelve words, with the TRON address those words derive and no multichain state.
func legacyWallet() -> Wallet {
    let words = [
        "business", "thunder", "episode", "arena",
        "tray", "twelve", "humble", "asthma",
        "uphold", "pumpkin", "crunch", "fortune",
    ]
    return Wallet(
        id: "legacy-wallet",
        identity: .init(network: .mainnet, kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 2, count: 32)), .v4R2)),
        metaData: .init(label: "Legacy wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
        setupSettings: .init(isSetupFinished: true),
        batterySettings: .init(),
        tron: WalletTron(tonMnemonic: words)
    )
}
