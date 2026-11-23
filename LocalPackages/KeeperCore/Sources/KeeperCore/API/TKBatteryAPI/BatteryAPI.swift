import Foundation
import TKBatteryAPI

struct BatteryAPI {
    let hostProvider: APIHostProvider
    let urlSession: URLSession
}

// MARK: - Convenience

extension BatteryAPI {
    private func apiClient(
        authorization: BatteryAuthorization = .none,
        extraHeaders: [String: String] = [:]
    ) async throws(ApiError) -> Client {
        do {
            return try await Client(
                hostProvider: hostProvider,
                urlSession: urlSession,
                authorization: authorization,
                extraHeaders: extraHeaders
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

    func getBalance(authorization: BatteryAuthorization) async throws(ApiError) -> BatteryBalance {
        let client = try await apiClient(authorization: authorization)
        let response = try await apiCall(
            await client.getBalance(
                query: .init(units: .ton)
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

    /// Battery holds a send lock while `pending_transactions` is non-empty; the next sponsored
    /// send is rejected until that list clears.
    func getStatus(authorization: BatteryAuthorization) async throws(ApiError) -> Components.Schemas.Status {
        let client = try await apiClient(authorization: authorization)
        let response = try await apiCall(
            await client.getStatus()
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

    func getRechargeMethos(includeRechargeOnly: Bool) async throws(ApiError) -> [BatteryRechargeMethod] {
        try await rechargeMethods(includeRechargeOnly: includeRechargeOnly, multichain: false)
            .compactMap { BatteryRechargeMethod(method: $0) }
    }

    func rechargeMethods(includeRechargeOnly: Bool, multichain: Bool) async throws(ApiError) -> [Components.Schemas.RechargeMethods.methodsPayloadPayload] {
        let client = try await apiClient()
        let response = try await apiCall(
            await client.getRechargeMethods(query: .init(include_recharge_only: includeRechargeOnly, multichain: multichain))
        )
        switch response {
        case let .ok(ok):
            return try decodeResponse(ok.body.json.methods)
        case let .default(statusCode, error):
            throw try .badStatus(status: statusCode, message: decodeResponse(error.body.json.error))
        }
    }

    func emulate(
        authorization: BatteryAuthorization,
        boc: String
    ) async throws(ApiError) -> (responseData: Data, isBatteryAvailable: Bool, excess: UInt?) {
        let client = try await apiClient(authorization: authorization)
        let response = try await apiCall(
            await client.emulateMessageToWallet(
                query: .init(enable_validation: true),
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
        authorization: BatteryAuthorization,
        jettonMasterAddress: String,
        boc: String
    ) async throws(ApiError) -> String {
        let client = try await apiClient(authorization: authorization)
        let response = try await apiCall(
            await client.estimateGaslessCost(
                path: .init(jetton_master: jettonMasterAddress),
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

    func sendMessage(
        authorization: BatteryAuthorization,
        boc: String,
        proof: String?,
        extraHeaders: [String: String] = [:]
    ) async throws(ApiError) -> String? {
        let client = try await apiClient(
            authorization: authorization,
            extraHeaders: extraHeaders
        )
        let response = try await apiCall(
            await client.sendMessage(
                body: .json(.init(boc: boc, proof: proof))
            )
        )
        switch response {
        case let .ok(ok):
            return ok.headers.X_hyphen_Battery_hyphen_Relayer_hyphen_Message_hyphen_Hash
        case let .default(statusCode, error):
            let body = try decodeResponse(error.body.json)
            throw Self.messageRejection(status: statusCode, message: body.error, key: body.error_hyphen_key)
        }
    }

    func makePurchase(
        authorization: BatteryAuthorization,
        transactionId: String,
        promocode: String?
    ) async throws(ApiError) -> Components.Schemas.iOSBatteryPurchaseStatus {
        let client = try await apiClient(authorization: authorization)
        let response = try await apiCall(
            await client.iosBatteryPurchase(
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

    func getPurchases(authorization: BatteryAuthorization) async throws(ApiError) -> [BatteryPurchase] {
        let client = try await apiClient(authorization: authorization)
        let response = try await apiCall(
            await client.getPurchases()
        )
        switch response {
        case let .ok(ok):
            return try decodeResponse(ok.body.json.purchases)
                .compactMap(BatteryPurchase.init(purchase:))
        case let .default(statusCode, error):
            throw try .badStatus(
                status: statusCode,
                message: decodeResponse(error.body.json.error)
            )
        }
    }

    func migrateBattery(
        authorization: BatteryAuthorization,
        proof: String,
        fromAddress: String
    ) async throws(ApiError) -> Components.Schemas.BatteryMigration {
        let client = try await apiClient(authorization: authorization)
        let response = try await apiCall(
            await client.migrateBattery(
                body: .json(.init(proof: proof, from_address: fromAddress))
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
        authorization: BatteryAuthorization,
        address: String,
        energy: Int,
        bandwidth: Int
    ) async throws(ApiError) -> Components.Schemas.EstimatedTronTx {
        let client = try await apiClient(authorization: authorization)
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
        authorization: BatteryAuthorization,
        limit: Int,
        maxTimestamp: Int64? = nil
    ) async throws(ApiError) -> [TronTransaction] {
        let client = try await apiClient(authorization: authorization)
        let response = try await apiCall(
            await client.getTronTransactions(
                query: .init(
                    limit: limit,
                    max_timestamp: maxTimestamp
                )
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
        authorization: BatteryAuthorization,
        wallet: String,
        tx: String,
        energy: Int,
        bandwidth: Int,
        instantFeeTx: String? = nil,
        userPublicKey: String? = nil
    ) async throws(ApiError) -> String {
        let client = try await apiClient(authorization: authorization)
        let response = try await apiCall(
            await client.tronSend(
                query: Operations.tronSend.Input.Query(
                    user_public_key: userPublicKey
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

// MARK: - Gasless 2.0

extension BatteryAPI {
    func purchaseBatteryEstimate(
        authorization: BatteryAuthorization,
        request: Components.Schemas.PurchaseBatteryEmulateRequest
    ) async throws(ApiError) -> Components.Schemas.PurchaseBatteryEstimateResponse {
        let client = try await apiClient(authorization: authorization)
        let response = try await apiCall(await client.purchaseBatteryEstimate(body: .json(request)))
        switch response {
        case let .ok(ok): return try decodeResponse(ok.body.json)
        case let .clientError(statusCode, error):
            throw try Self.gaslessRejection(status: statusCode, error: decodeResponse(error.body.json.error))
        case let .default(statusCode, error):
            throw try .badStatus(status: statusCode, message: decodeResponse(error.body.json.error))
        }
    }

    func purchaseBatteryEmulate(
        authorization: BatteryAuthorization,
        request: Components.Schemas.PurchaseBatteryEmulateRequest
    ) async throws(ApiError) -> Components.Schemas.PurchaseBatteryEmulateResponse {
        let client = try await apiClient(authorization: authorization)
        let response = try await apiCall(await client.purchaseBatteryEmulate(body: .json(request)))
        switch response {
        case let .ok(ok): return try decodeResponse(ok.body.json)
        case let .clientError(statusCode, error):
            throw try Self.gaslessRejection(status: statusCode, error: decodeResponse(error.body.json.error))
        case let .default(statusCode, error):
            throw try .badStatus(status: statusCode, message: decodeResponse(error.body.json.error))
        }
    }

    func gaslessConfig() async throws(ApiError) -> Components.Schemas.GaslessV2Config {
        let client = try await apiClient()
        let response = try await apiCall(
            await client.gaslessBatteryConfig()
        )
        switch response {
        case let .ok(ok):
            return try decodeResponse(ok.body.json)
        case let .clientError(statusCode, error):
            throw try Self.gaslessRejection(status: statusCode, error: decodeResponse(error.body.json.error))
        case let .default(statusCode, error):
            throw try .badStatus(
                status: statusCode,
                message: decodeResponse(error.body.json.error)
            )
        }
    }

    func gaslessEstimate(
        authorization: BatteryAuthorization,
        request: Components.Schemas.GaslessV2EstimateRequest
    ) async throws(ApiError) -> Components.Schemas.GaslessV2EstimateResponse {
        let client = try await apiClient(authorization: authorization)
        let response = try await apiCall(
            await client.gaslessEstimate(body: .json(request))
        )
        switch response {
        case let .ok(ok):
            return try decodeResponse(ok.body.json)
        case let .clientError(statusCode, error):
            throw try Self.gaslessRejection(status: statusCode, error: decodeResponse(error.body.json.error))
        case let .default(statusCode, error):
            throw try .badStatus(
                status: statusCode,
                message: decodeResponse(error.body.json.error)
            )
        }
    }

    func gaslessEmulate(
        authorization: BatteryAuthorization,
        request: Components.Schemas.GaslessV2EmulateRequest
    ) async throws(ApiError) -> Components.Schemas.GaslessV2EmulateResponse {
        let client = try await apiClient(authorization: authorization)
        let response = try await apiCall(
            await client.gaslessEmulate(body: .json(request))
        )
        switch response {
        case let .ok(ok):
            return try decodeResponse(ok.body.json)
        case let .clientError(statusCode, error):
            throw try Self.gaslessRejection(status: statusCode, error: decodeResponse(error.body.json.error))
        case let .default(statusCode, error):
            throw try .badStatus(
                status: statusCode,
                message: decodeResponse(error.body.json.error)
            )
        }
    }

    func gaslessSend(
        authorization: BatteryAuthorization,
        request: Components.Schemas.GaslessV2SendRequest
    ) async throws(ApiError) -> Components.Schemas.GaslessV2SendResponse {
        let client = try await apiClient(authorization: authorization)
        let response = try await apiCall(
            await client.gaslessSend(body: .json(request))
        )
        switch response {
        case let .ok(ok):
            return try decodeResponse(ok.body.json)
        case let .clientError(statusCode, error):
            throw try Self.gaslessRejection(status: statusCode, error: decodeResponse(error.body.json.error))
        case let .default(statusCode, error):
            throw try .badStatus(
                status: statusCode,
                message: decodeResponse(error.body.json.error)
            )
        }
    }
}
