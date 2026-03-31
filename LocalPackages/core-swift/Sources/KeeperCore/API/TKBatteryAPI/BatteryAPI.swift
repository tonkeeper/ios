import Foundation
import TKBatteryAPI

public struct BatteryAPI {
    private let hostProvider: APIHostProvider
    private let urlSession: URLSession

    init(
        hostProvider: APIHostProvider,
        urlSession: URLSession
    ) {
        self.hostProvider = hostProvider
        self.urlSession = urlSession
    }
}

// MARK: - Convenience

extension BatteryAPI {
    private func apiClient() async throws(ApiError) -> Client {
        do {
            return try await Client(
                hostProvider: hostProvider,
                urlSession: urlSession
            )
        } catch {
            switch error {
            case .badHost:
                throw .badUrl(underlying: error)
            }
        }
    }

    private func apiCall<T>(
        _ block: @autoclosure () async throws -> T
    ) async throws(ApiError) -> T {
        do {
            return try await block()
        } catch {
            throw .unknown(underlying: error)
        }
    }

    private func decodeResponse<T>(
        _ block: @autoclosure () throws -> T
    ) throws(ApiError) -> T {
        do {
            return try block()
        } catch {
            throw .badResponse(underlying: error)
        }
    }
}

// MARK: - API

extension BatteryAPI {
    func getBatteryConfig() async throws(ApiError) -> Components.Schemas.Config {
        let client = try await apiClient()
        let response = try await apiCall(
            await client.getConfig()
        )
        switch response {
        case let .ok(ok):
            return try decodeResponse(ok.body.json)
        case let .default(statusCode, error):
            throw try .badStatus(
                status: statusCode,
                message: decodeResponse(error.body.json.error)
            )
        }
    }

    func getBalance(tonProofToken: String) async throws(ApiError) -> BatteryBalance {
        let client = try await apiClient()
        let response = try await apiCall(
            await client.getBalance(
                query: .init(units: .ton),
                headers: .init(X_hyphen_TonConnect_hyphen_Auth: tonProofToken)
            )
        )
        switch response {
        case let .ok(ok):
            return try BatteryBalance(
                balance: decodeResponse(ok.body.json)
            )
        case let .default(statusCode, error):
            throw try .badStatus(
                status: statusCode,
                message: decodeResponse(error.body.json.error)
            )
        }
    }

    func getRechargeMethos(includeRechargeOnly: Bool) async throws(ApiError) -> [BatteryRechargeMethod] {
        let client = try await apiClient()
        let response = try await apiCall(
            await client.getRechargeMethods(
                query: .init(include_recharge_only: includeRechargeOnly)
            )
        )
        switch response {
        case let .ok(ok):
            return try decodeResponse(ok.body.json.methods)
                .compactMap {
                    BatteryRechargeMethod(method: $0)
                }
        case let .default(statusCode, error):
            throw try .badStatus(
                status: statusCode,
                message: decodeResponse(error.body.json.error)
            )
        }
    }

    func emulate(
        tonProofToken: String,
        boc: String
    ) async throws(ApiError) -> (responseData: Data, isBatteryAvailable: Bool, excess: UInt?) {
        let client = try await apiClient()
        let response = try await apiCall(
            await client.emulateMessageToWallet(
                query: .init(enable_validation: true),
                headers: .init(X_hyphen_TonConnect_hyphen_Auth: tonProofToken),
                body: .json(.init(boc: boc))
            )
        )
        switch response {
        case let .ok(ok):
            let responseData = try decodeResponse(
                JSONEncoder().encode(ok.body.json)
            )
            let isBatteryAvailable = ok.headers.Allowed_hyphen_By_hyphen_Battery && ok.headers.Supported_hyphen_By_hyphen_Battery
            let excess = ok.headers.Excess >= 0 ? UInt(ok.headers.Excess) : nil
            return (responseData, isBatteryAvailable, excess)
        case let .default(statusCode, error):
            throw try .badStatus(
                status: statusCode,
                message: decodeResponse(error.body.json.error)
            )
        }
    }

    func gasslessEmulate(
        tonProofToken: String,
        jettonMasterAddress: String,
        boc: String
    ) async throws(ApiError) -> String {
        let client = try await apiClient()
        let response = try await apiCall(
            await client.estimateGaslessCost(
                path: .init(jetton_master: jettonMasterAddress),
                headers: .init(X_hyphen_TonConnect_hyphen_Auth: tonProofToken),
                body: .json(.init(battery: false, payload: boc))
            )
        )
        switch response {
        case let .ok(ok):
            return try decodeResponse(ok.body.json.commission)
        case let .default(statusCode, error):
            throw try .badStatus(
                status: statusCode,
                message: decodeResponse(error.body.json.error)
            )
        }
    }

    func sendMessage(tonProofToken: String, boc: String) async throws(ApiError) {
        let client = try await apiClient()
        let response = try await apiCall(
            await client.sendMessage(
                headers: .init(X_hyphen_TonConnect_hyphen_Auth: tonProofToken),
                body: .json(.init(boc: boc))
            )
        )
        if case let .default(statusCode, error) = response {
            throw try .badStatus(
                status: statusCode,
                message: decodeResponse(error.body.json.error)
            )
        }
    }

    func makePurchase(
        tonProofToken: String,
        transactionId: String,
        promocode: String?
    ) async throws(ApiError) -> Components.Schemas.iOSBatteryPurchaseStatus {
        let client = try await apiClient()
        let response = try await apiCall(
            await client.iosBatteryPurchase(
                headers: .init(X_hyphen_TonConnect_hyphen_Auth: tonProofToken),
                body: .json(.init(transactions: [.init(id: transactionId, promo: promocode)]))
            )
        )
        switch response {
        case let .ok(ok):
            return try decodeResponse(ok.body.json)
        case let .default(statusCode, error):
            throw try .badStatus(
                status: statusCode,
                message: decodeResponse(error.body.json.error)
            )
        }
    }

    func verifyPromocode(promocode: String) async throws(ApiError) {
        let client = try await apiClient()
        let response = try await apiCall(
            await client.verifyPurchasePromo(
                query: .init(promo: promocode)
            )
        )
        if case let .default(statusCode, error) = response {
            throw try .badStatus(
                status: statusCode,
                message: decodeResponse(error.body.json.error)
            )
        }
    }

    func getTronConfig() async throws(ApiError) -> Operations.getTronConfig.Output.Ok.Body.jsonPayload {
        let client = try await apiClient()
        let response = try await apiCall(
            await client.getTronConfig()
        )
        switch response {
        case let .ok(ok):
            return try decodeResponse(ok.body.json)
        case let .default(statusCode, error):
            throw try .badStatus(
                status: statusCode,
                message: decodeResponse(error.body.json.error)
            )
        }
    }

    func getTronEstimate(
        address: String,
        energy: Int,
        bandwidth: Int
    ) async throws(ApiError) -> Components.Schemas.EstimatedTronTx {
        let client = try await apiClient()
        let response = try await apiCall(
            await client.tronEstimate(
                query: .init(
                    energy: energy,
                    bandwidth: bandwidth,
                    wallet: address
                )
            )
        )
        switch response {
        case let .ok(ok):
            return try decodeResponse(ok.body.json)
        case let .default(statusCode, error):
            throw try .badStatus(
                status: statusCode,
                message: decodeResponse(error.body.json.error)
            )
        }
    }

    func getTronTransactions(
        tonProofToken: String,
        limit: Int,
        maxTimestamp: Int64? = nil
    ) async throws(ApiError) -> [TronTransaction] {
        let client = try await apiClient()
        let response = try await apiCall(
            await client.getTronTransactions(
                query: .init(
                    limit: limit,
                    max_timestamp: maxTimestamp
                ),
                headers: .init(X_hyphen_TonConnect_hyphen_Auth: tonProofToken)
            )
        )
        switch response {
        case let .ok(ok):
            return try decodeResponse(ok.body.json.transactions)
                .compactMap {
                    try? TronTransaction(apiTransaction: $0)
                }
        case let .default(statusCode, error):
            throw try .badStatus(
                status: statusCode,
                message: decodeResponse(error.body.json.error)
            )
        }
    }

    func tronSend(
        tonProofToken: String,
        wallet: String,
        tx: String,
        energy: Int,
        bandwidth: Int,
        instantFeeTx: String? = nil,
        userPublicKey: String? = nil
    ) async throws(ApiError) -> String {
        let client = try await apiClient()
        let response = try await apiCall(
            await client.tronSend(
                query: Operations.tronSend.Input.Query(
                    user_public_key: userPublicKey
                ),
                headers: .init(
                    X_hyphen_TonConnect_hyphen_Auth: tonProofToken
                ),
                body: .json(
                    .init(
                        tx: tx,
                        energy: energy,
                        bandwidth: bandwidth,
                        wallet: wallet,
                        instant_fee_tx: instantFeeTx
                    )
                )
            )
        )
        switch response {
        case let .ok(ok):
            return try decodeResponse(ok.body.json.status)
        case let .default(statusCode, error):
            throw try .badStatus(
                status: statusCode,
                message: decodeResponse(error.body.json.error)
            )
        }
    }
}
