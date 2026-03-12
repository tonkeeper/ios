import BigInt
import Foundation
import TronSwift

public struct API {
    public enum Error: Swift.Error {
        case invalidURL
        case invalidResponse
        case serverError(statusCode: Int)
        case responseError(JSONRpcResponse.RPCError)
        case invalidResult(Any?)
        case invalidHex
    }

    private let urlSession: URLSession
    private let baseApiUrl: URL

    public init(urlSession: URLSession, baseApiUrl: URL) {
        self.urlSession = urlSession
        self.baseApiUrl = baseApiUrl
    }

    public func tronUSDTBalance(owner: Address) async throws -> BigUInt {
        let contractAddress = USDT.address
        let request = ContractCallRequest.request(
            contractAddress: contractAddress,
            data: BalanceOfMethod(owner: owner).encode()
        )
        let result = try await performDataRequest(request: request)
        guard let amount = BigUInt(result.hexString(), radix: 16) else {
            throw Error.invalidHex
        }
        return amount
    }

    public func getTronHistory(
        address: Address,
        limit: Int,
        minTimestamp: Int64?,
        maxTimestamp: Int64?,
        fingerprint: String?
    ) async throws -> TransactionsResponse {
        let path = baseApiUrl.appendingPathComponent("v1/accounts/\(address.base58)/transactions/trc20")
        var components = URLComponents(url: path, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if let minTimestamp {
            components?.queryItems?.append(URLQueryItem(name: "min_timestamp", value: String(minTimestamp)))
        }
        if let maxTimestamp {
            components?.queryItems?.append(URLQueryItem(name: "max_timestamp", value: String(maxTimestamp)))
        }
        if let fingerprint {
            components?.queryItems?.append(URLQueryItem(name: "fingerprint", value: fingerprint))
        }

        guard let url = components?.url else {
            throw Error.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"

        let (data, response) = try await urlSession.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Error.invalidResponse
        }
        switch httpResponse.statusCode {
        case 200 ..< 300:
            return try JSONDecoder().decode(TransactionsResponse.self, from: data)
        default:
            throw Error.serverError(statusCode: httpResponse.statusCode)
        }
    }

    public enum EstimateResourcesError: Swift.Error {
        case energyFailed
        case transactionDataMissing
    }

    public func estimateUSDTResources(
        owner: Address,
        method: ContractMethod
    ) async throws -> (energy: Int, bandwidth: Int) {
        let json = try await triggerConstantContract(
            owner: owner,
            contract: USDT.address,
            method: method,
            visible: true
        )

        guard let result = (json["result"] as? [String: Any])?["result"] as? Bool,
              result,
              let energyUsed = json["energy_used"] as? Int
        else {
            throw EstimateResourcesError.energyFailed
        }

        guard let rawDataHex = (json["transaction"] as? [String: Any])?["raw_data_hex"] as? String else {
            throw EstimateResourcesError.transactionDataMissing
        }

        let DATA_HEX_PROTOBUF_EXTRA = 9
        let MAX_RESULT_SIZE_IN_TX = 64
        let A_SIGNATURE = 67

        guard let rawData = Data(hex: rawDataHex) else {
            throw Error.invalidHex
        }

        let bandwidth: Int = rawData.count
            + DATA_HEX_PROTOBUF_EXTRA
            + MAX_RESULT_SIZE_IN_TX
            + A_SIGNATURE

        return (energy: energyUsed, bandwidth: bandwidth)
    }

    public func getTransferTransaction(
        owner: Address,
        method: ContractMethod,
        feeLimit: Int
    ) async throws -> Transaction {
        let json = try await triggerSmartContract(
            owner: owner,
            contract: USDT.address,
            method: method,
            feeLimit: feeLimit
        )
        guard let transactionJson = json["transaction"] as? [String: Any],
              let transaction = Transaction(json: transactionJson)
        else {
            throw NSError(domain: "", code: 1)
        }
        return transaction
    }

    public func getSignWeightTransaction(transaction: Transaction) async throws -> Transaction {
        let json = try await getSignWeight(transaction: transaction)
        guard let transactionJson = (json["transaction"] as? [String: Any])?["transaction"] as? [String: Any],
              let transaction = Transaction(json: transactionJson)
        else {
            throw NSError(domain: "", code: 1)
        }
        return transaction
    }

    public func getSignWeight(transaction: Transaction) async throws -> [String: Any] {
        let path = baseApiUrl.appendingPathComponent("wallet/getsignweight")
        var urlRequest = URLRequest(url: path)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: transaction.toJson())
        let (data, response) = try await urlSession.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Error.invalidResponse
        }
        switch httpResponse.statusCode {
        case 200 ..< 300:
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw Error.invalidResponse
            }
            return json
        default:
            throw Error.serverError(statusCode: httpResponse.statusCode)
        }
    }

    public func triggerConstantContract(
        owner: Address,
        contract: Address,
        method: ContractMethod,
        visible: Bool
    ) async throws -> [String: Any] {
        let path = baseApiUrl.appendingPathComponent("wallet/triggerconstantcontract")
        var urlRequest = URLRequest(url: path)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: [
            "owner_address": owner.base58,
            "contract_address": contract.base58,
            "function_selector": method.signature,
            "parameter": ContractCoding.encode(parameters: method.arguments).hexString(),
            "visible": visible,
        ])
        let (data, response) = try await urlSession.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Error.invalidResponse
        }
        switch httpResponse.statusCode {
        case 200 ..< 300:
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw Error.invalidResponse
            }
            return json
        default:
            throw Error.serverError(statusCode: httpResponse.statusCode)
        }
    }

    public func triggerSmartContract(
        owner: Address,
        contract: Address,
        method: ContractMethod,
        feeLimit: Int
    ) async throws -> [String: Any] {
        let path = baseApiUrl.appendingPathComponent("wallet/triggersmartcontract")
        var urlRequest = URLRequest(url: path)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: [
            "owner_address": owner.raw.hexString(),
            "contract_address": contract.raw.hexString(),
            "function_selector": method.signature,
            "parameter": ContractCoding.encode(parameters: method.arguments).hexString(),
            "fee_limit": feeLimit,
        ])
        let (data, response) = try await urlSession.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Error.invalidResponse
        }
        switch httpResponse.statusCode {
        case 200 ..< 300:
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw Error.invalidResponse
            }
            return json
        default:
            throw Error.serverError(statusCode: httpResponse.statusCode)
        }
    }

    public func performDataRequest(request: JSONRpcRequest) async throws -> Data {
        try await perform(request: request) { rpcResponse in
            guard let hexString = rpcResponse.result as? String,
                  let value = Data(hex: hexString)
            else {
                throw Error.invalidResult(rpcResponse.result)
            }
            return value
        }
    }

    public func perform<T>(request: JSONRpcRequest, responseParse: (_ rpcResponse: JSONRpcResponse.SuccessResponse) throws -> T) async throws -> T {
        let path = baseApiUrl.appendingPathComponent("jsonrpc")
        var urlRequest = URLRequest(url: path)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = try request.parameters()
        let (data, response) = try await urlSession.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Error.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200 ..< 300:
            let rpcResponse = try JSONRpcResponse(responseData: data)
            switch rpcResponse {
            case let .success(successResponse):
                return try responseParse(successResponse)
            case let .error(errorResponse):
                throw Error.responseError(errorResponse.error)
            }
        default:
            throw Error.serverError(statusCode: httpResponse.statusCode)
        }
    }
}

public extension Data {
    init?(hex: String) {
        var hex = hex
        if hex.hasPrefix("0x") {
            hex = String(hex.dropFirst(2))
        }

        let len = hex.count / 2
        var data = Data(capacity: len)
        var i = hex.startIndex

        for _ in 0 ..< len {
            let j = hex.index(i, offsetBy: 2)
            let bytes = hex[i ..< j]

            if var num = UInt8(bytes, radix: 16) {
                data.append(&num, count: 1)
            } else {
                return nil
            }

            i = j
        }
        self = data
    }
}

extension Data {
    func hexString() -> String {
        map { String(format: "%02hhx", $0) }.joined()
    }
}
