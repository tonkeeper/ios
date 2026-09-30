import BigInt
import Foundation
import TKLogging
import TronSwift

private struct EmptyRequest: Encodable {}

public struct TronApi {
    public enum Error: Swift.Error, LocalizedError {
        case invalidRequest
        case invalidResponse
        case networkError
        case serverError(statusCode: Int)
        case responseError(JSONRpcResponse.RPCError)
        /// The transaction could not be encoded for the wire. The user-facing message is the same
        /// whichever half was wrong, so `reason` is what tells a missing signature from corrupt
        /// `raw_data` when reading the log.
        case invalidHex(reason: String)
        /// The `raw_data` a node built describes something other than what was requested. The node
        /// assembles the transaction and the signature covers its bytes, so this is the one thing
        /// standing between a compromised node and a signature over someone else's transfer.
        case unverifiedTransaction(reason: String)
        /// A node rejected building or broadcasting the transaction and named the reason,
        /// e.g. `BANDWIDTH_ERROR`, `CONTRACT_VALIDATE_ERROR`, `TRANSACTION_EXPIRATION_ERROR`.
        case transactionRejected(code: String, message: String?)
        case apiError(message: String)

        /// A node names the same condition two ways: `code` plus a hex `message` when it rejects a
        /// broadcast, and a bare `Error` string when it refuses to build the transaction. Both have
        /// to classify the same, otherwise the reason a send failed depends on how far it got.
        private var rejectionReason: (code: String, message: String?)? {
            switch self {
            case let .transactionRejected(code, message):
                return (code, message)
            case let .apiError(message):
                return ("", message)
            default:
                return nil
            }
        }

        public var isInactiveTronAccount: Bool {
            TronRejectionCode.isAccountMissing(message: rejectionReason?.message)
        }

        /// Only a broadcast can expire: a build request is answered against the current head.
        public var isExpiredTronTransaction: Bool {
            guard case let .transactionRejected(code, message) = self else {
                return false
            }
            return TronRejectionCode.isExpired(code: code, message: message)
        }

        public var isInsufficientTronResources: Bool {
            guard let rejectionReason else {
                return false
            }
            return TronRejectionCode.isInsufficientResources(
                code: rejectionReason.code,
                message: rejectionReason.message
            )
        }

        public var errorDescription: String? {
            switch self {
            case let .apiError(message):
                return message
            case let .responseError(error):
                return error.message
            case let .transactionRejected(code, message):
                return message ?? code
            default:
                return nil
            }
        }
    }

    public static let defaultNativeTransferBandwidth = 345

    /// One value for the whole USDT transfer path: the estimate has to measure the very `fee_limit`
    /// the signed transaction will carry, and a second copy is how the two came to disagree.
    public static let usdtTransferFeeLimit = 150_000_000

    private var client: HttpApiClient

    public init(urlSession: URLSession, baseApiUrl: URL) {
        client = HttpApiClient(
            urlSession: urlSession,
            baseApiUrl: baseApiUrl,
            isSuccessStatusCode: (200 ..< 300).contains
        )
    }

    /// TRX rides in the same JSON-RPC batch as the USDT `balanceOf` call the assets list needs
    /// anyway, so both amounts cost one TronGrid request instead of two.
    public func tronBalances(owner: Address) async throws(Error) -> TronAccountBalances {
        let call = TronBatchBalancesCall(owners: [owner], usdtContract: USDT.address)
        return try await client.post(
            endpoint: "jsonrpc",
            request: call.payload,
            encoder: .defaultJsonSerialization(),
            decoder: HttpApiClient.Decoder { data in
                try call.balances(for: owner, responseData: data)
            }
        )
    }

    public func tronAccountBalances(owner: Address) async throws(Error) -> TronAccountBalances {
        let response: TronAccountBalancesResponse = try await client.get(
            endpoint: "v1/accounts/\(owner.base58)",
            params: [:],
            decoder: .defaultDecodable()
        )
        return response.balances(usdtContractAddress: USDT.address.base58)
    }

    public func tronAccountBalancesBatch(owners: [Address]) async throws(Error) -> [String: TronBatchAccountBalances] {
        guard !owners.isEmpty else {
            return [:]
        }
        let call = TronBatchBalancesCall(owners: owners, usdtContract: USDT.address)
        return try await client.post(
            endpoint: "jsonrpc",
            request: call.payload,
            encoder: .defaultJsonSerialization(),
            decoder: HttpApiClient.Decoder { data in
                try call.parse(responseData: data)
            }
        )
    }

    public func tronAccountExists(owner: Address) async throws(Error) -> Bool {
        try await tronAccount(owner: owner).exists
    }

    public func tronAccount(owner: Address) async throws(Error) -> (balance: BigUInt, exists: Bool) {
        let response = try await client.post(
            endpoint: "wallet/getaccount",
            request: WalletGetAccountRequest(
                address: owner.base58,
                visible: true
            ),
            responseType: WalletGetAccountResponse.self,
            encoder: .defaultEncodable(),
            decoder: .defaultDecodable()
        )
        let balance = response.balance?.bigIntValue ?? 0
        if balance < 0 {
            Log.w("http.tronBalance returns negative balance")
        }
        return (BigUInt(max(0, balance)), response.exists)
    }

    public func getTronHistory(
        address: Address,
        limit: Int,
        minTimestamp: Int64?,
        maxTimestamp: Int64?,
        fingerprint: String?
    ) async throws -> TransactionsResponse {
        try await client.get(
            endpoint: "v1/accounts/\(address.base58)/transactions/trc20",
            params: [
                "limit": String(limit),
                "min_timestamp": minTimestamp.map(String.init),
                "max_timestamp": maxTimestamp.map(String.init),
                "fingerprint": fingerprint,
            ].compactMapValues { $0 },
            decoder: .defaultDecodable()
        )
    }

    public func getTronAccountTransactions(
        address: Address,
        limit: Int,
        maxTimestamp: Int64?,
        fingerprint: String?
    ) async throws(Error) -> AccountTransactionsResponse {
        try await client.get(
            endpoint: "v1/accounts/\(address.base58)/transactions",
            params: [
                "limit": String(limit),
                "max_timestamp": maxTimestamp.map(String.init),
                "fingerprint": fingerprint,
            ].compactMapValues { $0 },
            decoder: .defaultDecodable()
        )
    }

    public func estimateUSDTResources(
        owner: Address,
        method: ContractMethod,
        feeLimit: Int = TronApi.usdtTransferFeeLimit
    ) async throws(Error) -> (energy: Int, bandwidth: Int) {
        guard feeLimit >= 0 else {
            throw .invalidRequest
        }

        let response = try await triggerConstantContract(
            owner: owner,
            contract: USDT.address,
            method: method,
            visible: true
        )
        let estimatedResources: (energy: Int, bandwidth: Int)
        do {
            estimatedResources = try response.estimatedResources(feeLimit: feeLimit)
        } catch {
            throw .invalidResponse
        }
        return estimatedResources
    }

    public func triggerConstantContract(
        owner: Address,
        contract: Address,
        method: ContractMethod,
        visible: Bool
    ) async throws(Error) -> TriggerConstantContractResponse {
        try await client.post(
            endpoint: "wallet/triggerconstantcontract",
            request: TriggerConstantContractRequest(
                ownerAddress: owner.base58,
                contractAddress: contract.base58,
                functionSelector: method.signature,
                parameter: ContractCoding.encode(parameters: method.arguments).hexString(),
                visible: visible
            ),
            encoder: .defaultEncodable(),
            decoder: .defaultDecodable()
        )
    }

    /// Split because the two pools are not interchangeable: creating an account is payable with
    /// `staked` bandwidth only, while an ordinary transfer may use either.
    public func getAccountBandwidth(owner: Address) async throws(Error) -> (free: Int, staked: Int) {
        let response = try await client.post(
            endpoint: "wallet/getaccountnet",
            request: WalletGetAccountRequest(
                address: owner.base58,
                visible: true
            ),
            responseType: WalletGetAccountNetResponse.self,
            encoder: .defaultEncodable(),
            decoder: .defaultDecodable()
        )

        let freeNetLimit = max(0, response.freeNetLimit ?? 0)
        let freeNetUsed = max(0, response.freeNetUsed ?? 0)
        let netLimit = max(0, response.netLimit ?? 0)
        let netUsed = max(0, response.netUsed ?? 0)

        return (
            free: max(0, freeNetLimit - freeNetUsed),
            staked: max(0, netLimit - netUsed)
        )
    }

    public func getChainFees() async throws(Error) -> (
        energySun: Int64,
        bandwidthSun: Int64,
        createAccountSun: Int64,
        createNewAccountSun: Int64,
        createNewAccountBandwidthRate: Int64
    ) {
        let response = try await client.post(
            endpoint: "wallet/getchainparameters",
            request: EmptyRequest(),
            responseType: WalletGetChainParametersResponse.self,
            encoder: .defaultEncodable(),
            decoder: .defaultDecodable()
        )

        func value(for key: String) -> Int64? {
            response.chainParameter
                .compactMap { item -> (key: String, value: Int64)? in
                    guard let value = item.value else {
                        return nil
                    }
                    return (item.key, value)
                }
                .first {
                    $0.key == key
                }?
                .value
        }

        guard
            let energySun = value(for: "getEnergyFee"),
            let bandwidthSun = value(for: "getTransactionFee"),
            let createAccountSun = value(for: "getCreateAccountFee"),
            let createNewAccountSun = value(for: "getCreateNewAccountFeeInSystemContract"),
            let createNewAccountBandwidthRate = value(for: "getCreateNewAccountBandwidthRate")
        else {
            throw .invalidResponse
        }
        return (
            energySun: energySun,
            bandwidthSun: bandwidthSun,
            createAccountSun: createAccountSun,
            createNewAccountSun: createNewAccountSun,
            createNewAccountBandwidthRate: createNewAccountBandwidthRate
        )
    }

    public func getTransferTransaction(
        owner: Address,
        method: ContractMethod,
        feeLimit: Int = TronApi.usdtTransferFeeLimit
    ) async throws(Error) -> Transaction {
        guard feeLimit >= 0 else {
            throw .invalidRequest
        }

        let functionSelector = method.signature
        let parameter = ContractCoding.encode(parameters: method.arguments)
        let callData = ContractCoding.methodId(signature: functionSelector) + parameter
        let json = try await triggerSmartContract(
            owner: owner,
            contract: USDT.address,
            functionSelector: functionSelector,
            parameter: parameter,
            feeLimit: feeLimit
        )
        let transaction = try Self.transferTransaction(from: json)
        try Self.verify(
            transaction,
            matches: .smartContractCall(
                owner: owner,
                contract: USDT.address,
                data: callData,
                feeLimit: feeLimit
            )
        )
        return transaction
    }

    /// A TRON transaction is built by the node, and the signature covers the `raw_data` it returns
    /// byte for byte, while the confirmation screen shows the local intent. Verifying here — where
    /// the node's answer becomes a `Transaction` — covers every signing path at once, including one
    /// added later, which a check sitting next to each signature would not.
    private static func verify(
        _ transaction: Transaction,
        matches expected: Transaction.ExpectedContract
    ) throws(Error) {
        do {
            try transaction.verify(matches: expected)
        } catch {
            Log.tron.e("tron node returned a transaction that does not match the request: \(error)")
            throw .unverifiedTransaction(reason: "\(error)")
        }
    }

    static func transferTransaction(from json: [String: Any]) throws(Error) -> Transaction {
        if let transactionJson = json["transaction"] as? [String: Any],
           let transaction = Transaction(json: transactionJson)
        {
            return transaction
        }
        throw TronRejectionResponse.rejection(in: json) ?? .invalidResponse
    }

    public func createNativeTransfer(
        owner: Address,
        to: Address,
        amountSun: BigUInt
    ) async throws(Error) -> Transaction {
        guard amountSun > 0, amountSun <= BigUInt(Int64.max) else {
            throw .invalidRequest
        }

        let json: [String: Any] = try await client.post(
            endpoint: "wallet/createtransaction",
            request: WalletCreateTransactionRequest(
                ownerAddress: owner.base58,
                toAddress: to.base58,
                amount: Int64(amountSun),
                visible: true
            ),
            encoder: .defaultEncodable(),
            decoder: .defaultJsonSerialization()
        )

        let transaction = try Self.nativeTransferTransaction(from: json)
        try Self.verify(transaction, matches: .nativeTransfer(owner: owner, to: to, amountSun: amountSun))
        return transaction
    }

    /// Internal on purpose: a `Transaction` reaches the rest of the app only through the two
    /// endpoints above, which verify it against the request before returning it.
    static func nativeTransferTransaction(from json: [String: Any]) throws(Error) -> Transaction {
        if let transaction = Transaction(json: json) {
            return transaction
        }

        let message = ([json["Error"], json["message"]] as [Any?])
            .compactMap { $0 as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }

        if let message {
            throw .apiError(message: message)
        }
        throw .invalidResponse
    }

    /// The node used to be asked to build a throwaway transaction just to measure it; the layout is
    /// fixed, so the length is derived locally instead.
    public static func nativeTransferBandwidth(amountSun: BigUInt) -> Int {
        let amount = amountSun <= BigUInt(UInt64.max) ? UInt64(amountSun) : UInt64.max
        return bandwidth(rawDataLength: TronWireSize.nativeTransferRawDataLength(amountSun: amount))
    }

    /// What a node charges for a signed transaction: `raw_data`, the field header wrapping it,
    /// one signature and the largest result the transaction can come back with. Every estimate goes
    /// through here — a second copy of the arithmetic is how the two paths came to disagree.
    static func bandwidth(rawDataLength: Int) -> Int {
        let maxResultSizeInTx = 64
        let aSignature = 67

        return rawDataLength
            + TronWireSize.rawDataEnvelopeLength(rawDataLength: rawDataLength)
            + maxResultSizeInTx
            + aSignature
    }

    private func triggerSmartContract(
        owner: Address,
        contract: Address,
        functionSelector: String,
        parameter: Data,
        feeLimit: Int
    ) async throws(Error) -> [String: Any] {
        try await client.post(
            endpoint: "wallet/triggersmartcontract",
            request: TriggerSmartContractRequest(
                ownerAddress: owner.raw.hexString(),
                contractAddress: contract.raw.hexString(),
                functionSelector: functionSelector,
                parameter: parameter.hexString(),
                feeLimit: feeLimit
            ),
            encoder: .defaultEncodable(),
            decoder: .defaultJsonSerialization()
        )
    }

    public func broadcastSignedTransaction(transaction: Transaction) async throws(Error) {
        let request: [String: Any]
        do {
            request = try ["transaction": transaction.signedProtobufHex()]
        } catch {
            throw Error.invalidHex(reason: "\(error)")
        }
        let response: [String: Any] = try await client.post(
            endpoint: "wallet/broadcasthex",
            request: request,
            encoder: .defaultJsonSerialization(),
            decoder: .defaultJsonSerialization()
        )
        try Self.validateBroadcastResponse(response)
    }

    /// `nil` while the node has not indexed the tx yet (empty JSON object).
    public func getTransactionInfo(txId: String) async throws(Error) -> TronTransactionInfoResponse? {
        let response: [String: Any] = try await client.post(
            endpoint: "wallet/gettransactioninfobyid",
            request: ["value": txId],
            encoder: .defaultJsonSerialization(),
            decoder: .defaultJsonSerialization()
        )
        return TronTransactionInfoResponse.parse(response)
    }

    /// A duplicate is a success: the very transaction we just sent is already propagating.
    static func validateBroadcastResponse(_ json: [String: Any]) throws(Error) {
        if let result = json["result"] as? Bool, result {
            return
        }
        guard let rejection = TronRejectionResponse.rejection(in: json) else {
            throw .invalidResponse
        }
        if case let .transactionRejected(code, _) = rejection, code == TronRejectionCode.duplicate {
            return
        }
        throw rejection
    }
}
