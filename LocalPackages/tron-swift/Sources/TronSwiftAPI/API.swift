import BigInt
import Foundation
import TKLogging
import TronSwift

private struct EmptyRequest: Encodable {}

public struct TronApi {
    public enum Error: Swift.Error {
        case invalidRequest
        case invalidResponse
        case networkError
        case serverError(statusCode: Int)
        case responseError(JSONRpcResponse.RPCError)
        case invalidResult(Any?)
        case invalidHex
    }

    private var client: HttpApiClient

    public init(urlSession: URLSession, baseApiUrl: URL) {
        client = HttpApiClient(
            urlSession: urlSession,
            baseApiUrl: baseApiUrl,
            isSuccessStatusCode: (200 ..< 300).contains
        )
    }

    public func tronUSDTBalance(owner: Address) async throws(Error) -> BigUInt {
        let request = ContractCallRequest.request(
            contractAddress: USDT.address,
            data: BalanceOfMethod(owner: owner).encode()
        ).parameters()
        let response: JSONRpcResponse = try await client.post(
            endpoint: "jsonrpc",
            request: request,
            encoder: .defaultJsonSerialization(),
            decoder: HttpApiClient.Decoder { data in
                try JSONRpcResponse(responseData: data)
            }
        )
        let success: JSONRpcResponse.SuccessResponse
        switch response {
        case let .success(successResponse):
            success = successResponse
        case let .error(errorResponse):
            throw .responseError(errorResponse.error)
        }
        guard
            let hexString = success.result as? String,
            let amountData = Data(hex: hexString)
        else {
            throw .invalidResult(success.result)
        }
        guard let amount = BigUInt(amountData.hexString(), radix: 16) else {
            throw .invalidHex
        }
        return amount
    }

    public func tronBalance(owner: Address) async throws(Error) -> BigUInt {
        let balance = try await client.post(
            endpoint: "wallet/getaccount",
            request: WalletGetAccountRequest(
                address: owner.base58,
                visible: true
            ),
            responseType: WalletGetAccountResponse.self,
            encoder: .defaultEncodable(),
            decoder: .defaultDecodable()
        ).balance?.bigIntValue ?? 0
        if balance < 0 {
            Log.w("http.tronBalance returns negative balance")
        }
        return BigUInt(max(0, balance))
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

    public func estimateUSDTResources(
        owner: Address,
        method: ContractMethod
    ) async throws(Error) -> (energy: Int, bandwidth: Int) {
        let response = try await triggerConstantContract(
            owner: owner,
            contract: USDT.address,
            method: method,
            visible: true
        )
        let estimatedResources: (energy: Int, bandwidth: Int)
        do {
            estimatedResources = try response.estimatedResources
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

    public func getAccountBandwidth(owner: Address) async throws(Error) -> Int {
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

        let freeBandwidth = max(0, freeNetLimit - freeNetUsed)
        let stakedBandwidth = max(0, netLimit - netUsed)

        return freeBandwidth + stakedBandwidth
    }

    public func getAccountEnergy(owner: Address) async throws(Error) -> Int {
        let response = try await client.post(
            endpoint: "wallet/getaccountresource",
            request: WalletGetAccountRequest(
                address: owner.base58,
                visible: true
            ),
            responseType: WalletGetAccountResourceResponse.self,
            encoder: .defaultEncodable(),
            decoder: .defaultDecodable()
        )

        let energyLimit = max(0, response.energyLimit ?? 0)
        let energyUsed = max(0, response.energyUsed ?? 0)
        return max(0, energyLimit - energyUsed)
    }

    public func getResourcePrices() async throws(Error) -> (energySun: Int64, bandwidthSun: Int64) {
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
            let bandwidthSun = value(for: "getTransactionFee")
        else {
            throw .invalidResponse
        }
        return (energySun: energySun, bandwidthSun: bandwidthSun)
    }

    public func getTransferTransaction(
        owner: Address,
        method: ContractMethod,
        feeLimit: Int
    ) async throws(Error) -> Transaction {
        let json = try await triggerSmartContract(
            owner: owner,
            contract: USDT.address,
            method: method,
            feeLimit: feeLimit
        )
        guard let transactionJson = json["transaction"] as? [String: Any],
              let transaction = Transaction(json: transactionJson)
        else {
            throw .invalidResponse
        }
        return transaction
    }

    public func triggerSmartContract(
        owner: Address,
        contract: Address,
        method: ContractMethod,
        feeLimit: Int
    ) async throws(Error) -> [String: Any] {
        try await client.post(
            endpoint: "wallet/triggersmartcontract",
            request: TriggerSmartContractRequest(
                ownerAddress: owner.raw.hexString(),
                contractAddress: contract.raw.hexString(),
                functionSelector: method.signature,
                parameter: ContractCoding.encode(parameters: method.arguments).hexString(),
                feeLimit: feeLimit
            ),
            encoder: .defaultEncodable(),
            decoder: .defaultJsonSerialization()
        )
    }

    public func broadcastSignedTransaction(transaction: Transaction) async throws(Error) {
        let response: [String: Any] = try await client.post(
            endpoint: "wallet/broadcasttransaction",
            request: transaction.toJson(),
            encoder: .defaultJsonSerialization(),
            decoder: .defaultJsonSerialization()
        )
        guard let result = response["result"] as? Bool, result else {
            throw .invalidResponse
        }
    }

    public func getSignWeightTransaction(transaction: Transaction) async throws(Error) -> Transaction {
        let responseObject: [String: Any] = try await client.post(
            endpoint: "wallet/getsignweight",
            request: transaction.toJson(),
            encoder: .defaultJsonSerialization(),
            decoder: .defaultJsonSerialization()
        )
        guard
            let transactionContainer = responseObject["transaction"] as? [String: Any],
            let transactionJson = transactionContainer["transaction"] as? [String: Any],
            let transaction = Transaction(json: transactionJson)
        else {
            throw .invalidResponse
        }
        return transaction
    }
}
