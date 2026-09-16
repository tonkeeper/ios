import Foundation
import MultichainAPI
import OpenAPIRuntime

/// Endpoints the device session itself needs. Unauthenticated: they are what mints the JWT.
protocol DeviceAuthAPI: Sendable {
    func getDeviceChallenge() async throws(MultichainClientAPIError) -> MultichainWalletChallenge
    func registerDevice(
        devicePublicKey: String,
        deviceProof: String,
        challenge: String,
        platform: String,
        appId: Int64,
        clientVersion: String
    ) async throws(MultichainClientAPIError) -> DeviceTokenPair
    func refreshDevice(
        deviceId: String,
        refreshToken: String,
        deviceProof: String
    ) async throws(MultichainClientAPIError) -> DeviceTokenPair
}

/// Everything under the `auth` tag. The `deviceJWT` parameter marks the operations the
/// spec guards with `security: deviceJWT`; the rest go out unauthenticated.
protocol MultichainAuthClientAPI: DeviceAuthAPI {
    func getDeviceBindings(
        walletIds: [String],
        deviceJWT: String
    ) async throws(MultichainClientAPIError) -> DeviceBindings
    func registerWallets(
        challenge: String,
        wallets: [MultichainWalletRegisterItem],
        deviceJWT: String
    ) async throws(MultichainClientAPIError) -> [MultichainWalletRegisterResult]
    func unregisterWallets(
        walletIds: [String],
        deviceJWT: String
    ) async throws(MultichainClientAPIError) -> [String]
    func subscribeWalletPush(
        pushToken: String,
        locale: String?,
        walletIds: [String],
        deviceJWT: String
    ) async throws(MultichainClientAPIError)
    func unsubscribeWalletPush(deviceJWT: String) async throws(MultichainClientAPIError)
}

final class MultichainAuthClientAPIImplementation: MultichainAuthClientAPI {
    private let makeClient: @Sendable () async -> MultichainAPI.Client
    private let makeDeviceAuthClient: @Sendable (String) async -> MultichainAPI.Client

    init(
        multichainAPIClient: @escaping @Sendable () async -> MultichainAPI.Client,
        deviceAuthMultichainAPIClient: @escaping @Sendable (String) async -> MultichainAPI.Client
    ) {
        makeClient = multichainAPIClient
        makeDeviceAuthClient = deviceAuthMultichainAPIClient
    }

    func getDeviceChallenge() async throws(MultichainClientAPIError) -> MultichainWalletChallenge {
        let output = try await apiCall(await makeClient().getDeviceChallenge())
        switch output {
        case let .ok(response):
            return try MultichainWalletChallenge(api: decodeResponse(response.body.json))
        case .tooManyRequests:
            throw MultichainClientAPIError.badStatus(message: Self.tooManyRequestsMessage)
        case let .internalServerError(error):
            throw try internalError(from: error)
        case let .undocumented(statusCode, _):
            throw MultichainClientAPIError.undocumented(statusCode: statusCode)
        }
    }

    func registerDevice(
        devicePublicKey: String,
        deviceProof: String,
        challenge: String,
        platform: String,
        appId: Int64,
        clientVersion: String
    ) async throws(MultichainClientAPIError) -> DeviceTokenPair {
        let body = MultichainAPI.Components.RequestBodies.DeviceRegister.json(
            .init(
                proof_type: .es256_raw,
                device_pub: devicePublicKey,
                device_proof: deviceProof,
                challenge: challenge,
                platform: .init(rawValue: platform) ?? .ios,
                app_id: appId,
                client_version: clientVersion
            )
        )
        let output = try await apiCall(await makeClient().registerDevice(body: body))
        switch output {
        case let .ok(response):
            return try DeviceTokenPair(api: decodeResponse(response.body.json))
        case let .badRequest(error):
            throw try badRequest(from: error)
        case let .unauthorized(error):
            throw try unauthorized(from: error)
        case .conflict:
            throw MultichainClientAPIError.badStatus(message: Self.registerConflictMessage)
        case .tooManyRequests:
            throw MultichainClientAPIError.badStatus(message: Self.tooManyRequestsMessage)
        case let .internalServerError(error):
            throw try internalError(from: error)
        case let .undocumented(statusCode, _):
            throw MultichainClientAPIError.undocumented(statusCode: statusCode)
        }
    }

    func refreshDevice(
        deviceId: String,
        refreshToken: String,
        deviceProof: String
    ) async throws(MultichainClientAPIError) -> DeviceTokenPair {
        let body = MultichainAPI.Components.RequestBodies.DeviceRefresh.json(
            .init(
                device_id: deviceId,
                refresh_token: refreshToken,
                device_proof: deviceProof
            )
        )
        let output = try await apiCall(await makeClient().refreshDevice(body: body))
        switch output {
        case let .ok(response):
            return try DeviceTokenPair(api: decodeResponse(response.body.json))
        case let .badRequest(error):
            throw try badRequest(from: error)
        case let .unauthorized(error):
            throw try unauthorized(from: error)
        case .tooManyRequests:
            throw MultichainClientAPIError.badStatus(message: Self.tooManyRequestsMessage)
        case let .internalServerError(error):
            throw try internalError(from: error)
        case let .undocumented(statusCode, _):
            throw MultichainClientAPIError.undocumented(statusCode: statusCode)
        }
    }

    func getDeviceBindings(
        walletIds: [String],
        deviceJWT: String
    ) async throws(MultichainClientAPIError) -> DeviceBindings {
        let body = MultichainAPI.Components.RequestBodies.DeviceBindingsRequest.json(
            .init(wallets: walletIds)
        )
        let output = try await apiCall(await makeDeviceAuthClient(deviceJWT).getDeviceBindings(body: body))
        switch output {
        case let .ok(response):
            let payload = try decodeResponse(response.body.json)
            return DeviceBindings(
                known: payload.known,
                unknown: payload.unknown,
                extra: payload.extra
            )
        case let .badRequest(error):
            throw try badRequest(from: error)
        case let .unauthorized(error):
            throw try unauthorized(from: error)
        case let .internalServerError(error):
            throw try internalError(from: error)
        case let .undocumented(statusCode, _):
            throw MultichainClientAPIError.undocumented(statusCode: statusCode)
        }
    }

    func registerWallets(
        challenge: String,
        wallets: [MultichainWalletRegisterItem],
        deviceJWT: String
    ) async throws(MultichainClientAPIError) -> [MultichainWalletRegisterResult] {
        let body = MultichainAPI.Components.RequestBodies.WalletRegisterBatch.json(
            .init(
                challenge: challenge,
                wallets: wallets.map { wallet in
                    .init(
                        wallet_id: wallet.walletId,
                        wallet_proof: wallet.walletProof,
                        accounts: wallet.accounts.map { $0.toAPIWalletAccount() }
                    )
                }
            )
        )
        let output = try await apiCall(await makeDeviceAuthClient(deviceJWT).registerWallets(body: body))
        switch output {
        case let .ok(response):
            let payload = try decodeResponse(response.body.json)
            return payload.results.map { MultichainWalletRegisterResult(api: $0) }
        case let .badRequest(error):
            throw try badRequest(from: error)
        case let .unauthorized(error):
            throw try unauthorized(from: error)
        case .tooManyRequests:
            throw MultichainClientAPIError.badStatus(message: Self.tooManyRequestsMessage)
        case let .internalServerError(error):
            throw try internalError(from: error)
        case let .undocumented(statusCode, _):
            throw MultichainClientAPIError.undocumented(statusCode: statusCode)
        }
    }

    func unregisterWallets(
        walletIds: [String],
        deviceJWT: String
    ) async throws(MultichainClientAPIError) -> [String] {
        let body = MultichainAPI.Components.RequestBodies.WalletUnregisterBatch.json(
            .init(wallet_ids: walletIds)
        )
        let output = try await apiCall(await makeDeviceAuthClient(deviceJWT).unregisterWallets(body: body))
        switch output {
        case let .ok(response):
            return try decodeResponse(response.body.json).detached
        case let .badRequest(error):
            throw try badRequest(from: error)
        case let .unauthorized(error):
            throw try unauthorized(from: error)
        case let .internalServerError(error):
            throw try internalError(from: error)
        case let .undocumented(statusCode, _):
            throw MultichainClientAPIError.undocumented(statusCode: statusCode)
        }
    }

    func subscribeWalletPush(
        pushToken: String,
        locale: String?,
        walletIds: [String],
        deviceJWT: String
    ) async throws(MultichainClientAPIError) {
        let body = MultichainAPI.Components.RequestBodies.WalletPushSubscribe.json(
            .init(
                push_token: pushToken,
                locale: locale,
                wallet_ids: walletIds
            )
        )
        let output = try await apiCall(await makeDeviceAuthClient(deviceJWT).subscribeDevicePush(body: body))
        switch output {
        case .ok:
            return
        case let .badRequest(error):
            throw try badRequest(from: error)
        case let .unauthorized(error):
            throw try unauthorized(from: error)
        case let .internalServerError(error):
            throw try internalError(from: error)
        case .badGateway:
            throw MultichainClientAPIError.badStatus(message: Self.pusherUnavailableMessage)
        case let .undocumented(statusCode, _):
            throw MultichainClientAPIError.undocumented(statusCode: statusCode)
        }
    }

    func unsubscribeWalletPush(deviceJWT: String) async throws(MultichainClientAPIError) {
        let output = try await apiCall(await makeDeviceAuthClient(deviceJWT).unsubscribeDevicePush())
        switch output {
        case .ok:
            return
        case let .unauthorized(error):
            throw try unauthorized(from: error)
        case let .internalServerError(error):
            throw try internalError(from: error)
        case .badGateway:
            throw MultichainClientAPIError.badStatus(message: Self.pusherUnavailableMessage)
        case let .undocumented(statusCode, _):
            throw MultichainClientAPIError.undocumented(statusCode: statusCode)
        }
    }
}

private extension MultichainAuthClientAPIImplementation {
    static let tooManyRequestsMessage = "rate limited (429)"
    static let registerConflictMessage = "device registration conflict (409)"
    static let pusherUnavailableMessage = "pusher unavailable (502)"

    func apiCall<T>(
        _ block: @autoclosure () async throws -> T
    ) async throws(MultichainClientAPIError) -> T {
        do {
            return try await block()
        } catch {
            throw error.isCancelledError ? .cancelled : .connectionError(underlying: error)
        }
    }

    func decodeResponse<T>(
        _ block: @autoclosure () throws -> T
    ) throws(MultichainClientAPIError) -> T {
        do {
            return try block()
        } catch {
            throw .badResponse(underlying: error)
        }
    }

    func badRequest(from response: MultichainAPI.Components.Responses.BadRequest) throws(MultichainClientAPIError) -> MultichainClientAPIError {
        try .badStatus(message: decodeResponse(response.body.json.error))
    }

    func unauthorized(from response: MultichainAPI.Components.Responses.Unauthorized) throws(MultichainClientAPIError) -> MultichainClientAPIError {
        try .unauthorized(message: decodeResponse(response.body.json.error))
    }

    func internalError(from response: MultichainAPI.Components.Responses.InternalError) throws(MultichainClientAPIError) -> MultichainClientAPIError {
        try .badStatus(message: decodeResponse(response.body.json.error))
    }
}

private extension DeviceTokenPair {
    init(api: MultichainAPI.Components.Schemas.DeviceTokens) {
        self.init(
            deviceId: api.device_id,
            accessToken: api.device_jwt,
            refreshToken: api.refresh_token,
            expiresIn: api.expires_in
        )
    }
}

private extension MultichainWalletRegisterResult {
    init(api: MultichainAPI.Components.Schemas.WalletRegisterResult) {
        self.init(
            index: api.index,
            walletId: api.wallet_id,
            error: api.status == .ok ? nil : (api.error ?? "unknown")
        )
    }
}
