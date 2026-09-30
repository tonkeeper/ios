import Foundation
import MultichainAPI
import OpenAPIRuntime
import TKLogging

enum MultichainClientAPIError: Error {
    case cancelled
    case connectionError(underlying: Error?)
    case badResponse(underlying: Error?)
    case badStatus(message: String)
    /// 401. Kept apart from `badStatus` because the device session recovers from it.
    case unauthorized(message: String)
    /// 403. Kept apart so realtime can stop retrying a mismatched wallet proof.
    case forbidden(message: String)
    case undocumented(statusCode: Int)
}

struct MultichainWalletAssetRecord: Equatable {
    let asset: MultichainAsset
    let account: MultichainWalletAddress
}

struct MultichainWalletAssetRecordsPage: Equatable {
    let records: [MultichainWalletAssetRecord]
    let nextCursor: String?
}

protocol MultichainClientAPI {
    func healthcheck() async throws(MultichainClientAPIError) -> MultichainHealth
    func searchAssets(
        currencies: [String],
        chain: MultichainChain?,
        search: String?,
        sort: MultichainAssetSearchSort,
        limit: Int?,
        cursor: String?
    ) async throws(MultichainClientAPIError) -> (assets: [MultichainAsset], nextCursor: String?)
    func getWallet(walletId: String) async throws(MultichainClientAPIError) -> MultichainRegisteredWallet
    func getWalletSyncStatus(walletId: String) async throws(MultichainClientAPIError) -> MultichainWalletSyncStatus
    func getWalletAssets(
        walletId: String,
        currencies: [String],
        assetIds: [String]?,
        capabilities: [MultichainAssetCapability]?,
        chain: MultichainChain?,
        search: String?,
        availableOnly: Bool?,
        showHidden: Bool?,
        hideDust: Bool?,
        limit: Int?,
        cursor: String?
    ) async throws(MultichainClientAPIError) -> MultichainWalletAssetRecordsPage
    func saveWalletAssetsFilters(walletId: String, changes: [MultichainAssetFilterChange]) async throws(MultichainClientAPIError)
    func getWalletActivities(
        walletId: String,
        limit: Int?,
        cursor: String?,
        chain: MultichainChain?,
        assetId: String?,
        activityTypeFilter: MultichainActivityTypeFilter?,
        showPerps: Bool?,
        hideDust: Bool?
    ) async throws(MultichainClientAPIError) -> MultichainWalletActivitiesPage
    func getWalletChallenge() async throws(MultichainClientAPIError) -> MultichainWalletChallenge
    func broadcastTx(chain: MultichainChain, signedTransaction: Data) async throws(MultichainClientAPIError) -> MultichainBroadcastResult
    func addPendingTransaction(_ transaction: MultichainPendingTransaction) async throws(MultichainClientAPIError)
    func getFees(chain: MultichainChain) async throws(MultichainClientAPIError) -> MultichainFeeEstimate
    func getWalletRaffles(
        walletId: String,
        lang: String?,
        ids: [String]?,
        debugNow: Date?,
        isNewUser: Bool
    ) async throws(MultichainClientAPIError) -> [MultichainRaffle]
    func completeRaffleMigration(walletId: String) async throws(MultichainClientAPIError)
    func markRaffleImport(walletId: String, importedWalletId: String) async throws(MultichainClientAPIError)
    func forcePickRaffleWinners(
        raffleId: String,
        walletId: String?,
        prizeId: String?
    ) async throws(MultichainClientAPIError)
    func getRealtimeConnectionToken() async throws(MultichainClientAPIError) -> String
    func getWalletRealtimeToken(walletId: String) async throws(MultichainClientAPIError) -> String
}

final class MultichainClientAPIImplementation: MultichainClientAPI {
    private let makeMultichainAPIClient: () async -> MultichainAPI.Client
    private let makeDeviceScopedAPIClient: () async -> MultichainAPI.Client
    private let makeWalletScopedAPIClient: (String) async -> MultichainAPI.Client

    init(
        multichainAPIClient: @escaping () async -> MultichainAPI.Client,
        deviceScopedAPIClient: @escaping () async -> MultichainAPI.Client,
        walletScopedAPIClient: @escaping (String) async -> MultichainAPI.Client
    ) {
        makeMultichainAPIClient = multichainAPIClient
        makeDeviceScopedAPIClient = deviceScopedAPIClient
        makeWalletScopedAPIClient = walletScopedAPIClient
    }

    private func multichainAPIClient() async -> MultichainAPI.Client {
        await makeMultichainAPIClient()
    }

    /// For operations that inherit the spec's top-level `deviceJWT` requirement.
    private func deviceScopedAPIClient() async -> MultichainAPI.Client {
        await makeDeviceScopedAPIClient()
    }

    /// For the operations the spec guards with `walletAuth`: carries the device session and the
    /// wallet-scoped credential naming `walletId`.
    private func walletScopedAPIClient(_ walletId: String) async -> MultichainAPI.Client {
        await makeWalletScopedAPIClient(walletId)
    }

    func healthcheck() async throws(MultichainClientAPIError) -> MultichainHealth {
        let output = try await apiCall(await multichainAPIClient().healthcheck())
        switch output {
        case let .ok(ok):
            let body = try decodeResponse(ok.body.json)
            return MultichainHealth(ok: body.ok)
        case let .internalServerError(error):
            throw try internalError(from: error)
        case let .undocumented(statusCode, _):
            throw MultichainClientAPIError.undocumented(statusCode: statusCode)
        }
    }

    func searchAssets(
        currencies: [String],
        chain: MultichainChain?,
        search: String?,
        sort: MultichainAssetSearchSort,
        limit: Int?,
        cursor: String?
    ) async throws(MultichainClientAPIError) -> (assets: [MultichainAsset], nextCursor: String?) {
        let query = MultichainAPI.Operations.searchAssets.Input.Query(
            chain: chain.map { $0.toAPIParametersSearchChainQuery() },
            currencies: currencies,
            search: search,
            sort: sort.toAPIParametersSort(),
            limit: limit,
            cursor: cursor
        )
        let output = try await apiCall(await deviceScopedAPIClient().searchAssets(query: query))
        return try mapSearchAssetsOutput(output)
    }

    func getWallet(walletId: String) async throws(MultichainClientAPIError) -> MultichainRegisteredWallet {
        let path = MultichainAPI.Operations.getWallet.Input.Path(wallet_id: walletId)
        let output = try await apiCall(await walletScopedAPIClient(walletId).getWallet(path: path))
        switch output {
        case let .ok(response):
            let wallet = try decodeResponse(response.body.json)
            return MultichainRegisteredWallet(api: wallet)
        case let .badRequest(error):
            throw try badRequest(from: error)
        case let .forbidden(error):
            throw try forbidden(from: error)
        case let .notFound(error):
            throw try notFound(from: error)
        case let .internalServerError(error):
            throw try internalError(from: error)
        case let .undocumented(statusCode, _):
            throw MultichainClientAPIError.undocumented(statusCode: statusCode)
        }
    }

    func getWalletSyncStatus(walletId: String) async throws(MultichainClientAPIError) -> MultichainWalletSyncStatus {
        let path = MultichainAPI.Operations.getWalletSyncStatus.Input.Path(wallet_id: walletId)
        let output = try await apiCall(await walletScopedAPIClient(walletId).getWalletSyncStatus(path: path))
        switch output {
        case let .ok(response):
            let status = try decodeResponse(response.body.json)
            return MultichainWalletSyncStatus(api: status)
        case let .badRequest(error):
            throw try badRequest(from: error)
        case let .forbidden(error):
            throw try forbidden(from: error)
        case let .notFound(error):
            throw try notFound(from: error)
        case let .internalServerError(error):
            throw try internalError(from: error)
        case let .undocumented(statusCode, _):
            throw MultichainClientAPIError.undocumented(statusCode: statusCode)
        }
    }

    func getWalletAssets(
        walletId: String,
        currencies: [String],
        assetIds: [String]?,
        capabilities: [MultichainAssetCapability]?,
        chain: MultichainChain?,
        search: String?,
        availableOnly: Bool?,
        showHidden: Bool?,
        hideDust: Bool?,
        limit: Int?,
        cursor: String?
    ) async throws(MultichainClientAPIError) -> MultichainWalletAssetRecordsPage {
        let path = MultichainAPI.Operations.getWalletAssets.Input.Path(wallet_id: walletId)
        let query = MultichainAPI.Operations.getWalletAssets.Input.Query(
            asset_ids: assetIds,
            capabilities: capabilities?.map { $0.toAPICapabilitiesQueryPayload() },
            chain: chain.map { $0.toAPISchemaChain() },
            search: search,
            available_only: availableOnly,
            show_hidden: showHidden,
            show_all: nil,
            currencies: currencies,
            hide_dust: hideDust,
            limit: limit,
            cursor: cursor
        )
        let output = try await apiCall(await walletScopedAPIClient(walletId).getWalletAssets(path: path, query: query))
        return try mapWalletAssetsOutput(output)
    }

    func saveWalletAssetsFilters(walletId: String, changes: [MultichainAssetFilterChange]) async throws(MultichainClientAPIError) {
        let path = MultichainAPI.Operations.saveWalletAssetsFilters.Input.Path(wallet_id: walletId)
        let body = MultichainAPI.Components.RequestBodies.SetAssetFilters.json(
            .init(
                changes: changes.map {
                    .init(
                        asset_id: $0.assetId,
                        action: $0.action.toAPIRequestAction()
                    )
                }
            )
        )
        let output = try await apiCall(await walletScopedAPIClient(walletId).saveWalletAssetsFilters(path: path, body: body))
        switch output {
        case .ok:
            return
        case let .badRequest(error):
            throw try badRequest(from: error)
        case let .forbidden(error):
            throw try forbidden(from: error)
        case let .notFound(error):
            throw try notFound(from: error)
        case let .internalServerError(error):
            throw try internalError(from: error)
        case let .undocumented(statusCode, _):
            throw MultichainClientAPIError.undocumented(statusCode: statusCode)
        }
    }

    func getWalletActivities(
        walletId: String,
        limit: Int?,
        cursor: String?,
        chain: MultichainChain?,
        assetId: String?,
        activityTypeFilter: MultichainActivityTypeFilter?,
        showPerps: Bool?,
        hideDust: Bool?
    ) async throws(MultichainClientAPIError) -> MultichainWalletActivitiesPage {
        let path = MultichainAPI.Operations.getWalletActivities.Input.Path(wallet_id: walletId)
        let query = MultichainAPI.Operations.getWalletActivities.Input.Query(
            limit: limit,
            cursor: cursor,
            chain: chain.map { $0.toAPISchemaChain() },
            activity_type: activityTypeFilter.flatMap {
                MultichainAPI.Components.Schemas.ActivityTypeFilter(rawValue: $0.rawValue)
            },
            asset_id: assetId,
            hide_dust: hideDust,
            show_perps: showPerps
        )
        let output = try await apiCall(await walletScopedAPIClient(walletId).getWalletActivities(path: path, query: query))
        return try mapWalletActivitiesOutput(output)
    }

    func getWalletChallenge() async throws(MultichainClientAPIError) -> MultichainWalletChallenge {
        let output = try await apiCall(await deviceScopedAPIClient().getWalletChallenge())
        switch output {
        case let .ok(response):
            let challenge = try decodeResponse(response.body.json)
            return MultichainWalletChallenge(api: challenge)
        case let .internalServerError(error):
            throw try internalError(from: error)
        case let .undocumented(statusCode, _):
            throw MultichainClientAPIError.undocumented(statusCode: statusCode)
        }
    }

    func broadcastTx(chain: MultichainChain, signedTransaction: Data) async throws(MultichainClientAPIError) -> MultichainBroadcastResult {
        let body = MultichainAPI.Components.RequestBodies.BroadcastTx.json(
            .init(
                chain: chain.toAPISchemaChain(),
                tx: Base64EncodedData(data: ArraySlice(signedTransaction))
            )
        )
        let output = try await apiCall(await deviceScopedAPIClient().broadcastTx(body: body))
        switch output {
        case let .ok(result):
            let payload = try decodeResponse(result.body.json)
            return MultichainBroadcastResult(api: payload)
        case let .badRequest(error):
            throw try badRequest(from: error)
        case let .internalServerError(error):
            throw try internalError(from: error)
        case let .undocumented(statusCode, _):
            throw MultichainClientAPIError.undocumented(statusCode: statusCode)
        }
    }

    func addPendingTransaction(_ transaction: MultichainPendingTransaction) async throws(MultichainClientAPIError) {
        let path = MultichainAPI.Operations.addPendingTransactions.Input.Path(wallet_id: transaction.walletId)
        let body = MultichainAPI.Components.RequestBodies.AddPendingTransaction.json(
            transaction.toAPISchemaPendingTransaction()
        )
        let output = try await apiCall(
            await walletScopedAPIClient(transaction.walletId).addPendingTransactions(path: path, body: body)
        )
        switch output {
        case .ok:
            return
        case let .badRequest(error):
            throw try badRequest(from: error)
        case let .forbidden(error):
            throw try forbidden(from: error)
        case let .notFound(error):
            throw try notFound(from: error)
        case let .tooManyRequests(error):
            throw try tooManyRequests(from: error)
        case let .internalServerError(error):
            throw try internalError(from: error)
        case let .undocumented(statusCode, _):
            throw MultichainClientAPIError.undocumented(statusCode: statusCode)
        }
    }

    func getFees(chain: MultichainChain) async throws(MultichainClientAPIError) -> MultichainFeeEstimate {
        let path = MultichainAPI.Operations.getFees.Input.Path(chain: chain.toAPIParametersChainPath())
        let output = try await apiCall(await deviceScopedAPIClient().getFees(path: path))
        switch output {
        case let .ok(fees):
            let estimate = try decodeResponse(fees.body.json)
            return MultichainFeeEstimate(api: estimate)
        case let .badRequest(error):
            throw try badRequest(from: error)
        case let .internalServerError(error):
            throw try internalError(from: error)
        case let .undocumented(statusCode, _):
            throw MultichainClientAPIError.undocumented(statusCode: statusCode)
        }
    }

    func getWalletRaffles(
        walletId: String,
        lang: String?,
        ids: [String]?,
        debugNow: Date?,
        isNewUser: Bool
    ) async throws(MultichainClientAPIError) -> [MultichainRaffle] {
        let path = MultichainAPI.Operations.getWalletRaffles.Input.Path(wallet_id: walletId)
        let query = MultichainAPI.Operations.getWalletRaffles.Input.Query(
            lang: lang,
            ids: ids,
            _debug_now: debugNow,
            is_new: isNewUser
        )
        let output = try await apiCall(await walletScopedAPIClient(walletId).getWalletRaffles(path: path, query: query))
        switch output {
        case let .ok(response):
            let payload = try decodeResponse(response.body.json)
            return payload.raffles.map { MultichainRaffle(api: $0) }
        case let .badRequest(error):
            throw try badRequest(from: error)
        case let .unauthorized(error):
            throw try unauthorized(from: error)
        case let .forbidden(error):
            throw try forbidden(from: error)
        case let .notFound(error):
            throw try notFound(from: error)
        case let .internalServerError(error):
            throw try internalError(from: error)
        case let .undocumented(statusCode, _):
            throw MultichainClientAPIError.undocumented(statusCode: statusCode)
        }
    }

    func completeRaffleMigration(walletId: String) async throws(MultichainClientAPIError) {
        let path = MultichainAPI.Operations.completeWalletRaffleMigration.Input.Path(wallet_id: walletId)
        let output = try await apiCall(
            await walletScopedAPIClient(walletId).completeWalletRaffleMigration(path: path)
        )
        switch output {
        case .noContent:
            return
        case let .badRequest(error):
            throw try badRequest(from: error)
        case let .unauthorized(error):
            throw try unauthorized(from: error)
        case let .forbidden(error):
            throw try forbidden(from: error)
        case let .notFound(error):
            throw try notFound(from: error)
        case let .internalServerError(error):
            throw try internalError(from: error)
        case let .undocumented(statusCode, _):
            throw MultichainClientAPIError.undocumented(statusCode: statusCode)
        }
    }

    func markRaffleImport(walletId: String, importedWalletId: String) async throws(MultichainClientAPIError) {
        let path = MultichainAPI.Operations.markWalletRaffleImport.Input.Path(wallet_id: walletId)
        let output = try await apiCall(
            await walletScopedAPIClient(walletId).markWalletRaffleImport(
                path: path,
                body: .json(.init(imported_wallet_id: importedWalletId))
            )
        )
        switch output {
        case .noContent:
            return
        case let .badRequest(error):
            throw try badRequest(from: error)
        case let .unauthorized(error):
            throw try unauthorized(from: error)
        case let .forbidden(error):
            throw try forbidden(from: error)
        case let .notFound(error):
            throw try notFound(from: error)
        case let .internalServerError(error):
            throw try internalError(from: error)
        case let .undocumented(statusCode, _):
            throw MultichainClientAPIError.undocumented(statusCode: statusCode)
        }
    }

    /// QA-only: returns 404 on prod pods, where the endpoint is gated off.
    func forcePickRaffleWinners(
        raffleId: String,
        walletId: String?,
        prizeId: String?
    ) async throws(MultichainClientAPIError) {
        let path = MultichainAPI.Operations.forcePickRaffleWinners.Input.Path(raffle_id: raffleId)
        let body = MultichainAPI.Components.RequestBodies.ForceRafflePick.json(
            .init(wallet_id: walletId, prize_id: prizeId)
        )
        let output = try await apiCall(
            await deviceScopedAPIClient().forcePickRaffleWinners(path: path, body: body)
        )
        switch output {
        case .ok:
            return
        case let .notFound(error):
            throw try notFound(from: error)
        case let .internalServerError(error):
            throw try internalError(from: error)
        case let .undocumented(statusCode, _):
            throw MultichainClientAPIError.undocumented(statusCode: statusCode)
        }
    }

    func getRealtimeConnectionToken() async throws(MultichainClientAPIError) -> String {
        let output = try await apiCall(await deviceScopedAPIClient().getRealtimeConnectionToken())
        switch output {
        case let .ok(response):
            let token = try decodeResponse(response.body.json)
            return token.token
        case let .unauthorized(error):
            throw try unauthorized(from: error)
        case let .internalServerError(error):
            throw try internalError(from: error)
        case let .undocumented(statusCode, _):
            throw MultichainClientAPIError.undocumented(statusCode: statusCode)
        }
    }

    func getWalletRealtimeToken(walletId: String) async throws(MultichainClientAPIError) -> String {
        let path = MultichainAPI.Operations.getWalletRealtimeToken.Input.Path(wallet_id: walletId)
        let output = try await apiCall(
            await walletScopedAPIClient(walletId).getWalletRealtimeToken(path: path)
        )
        switch output {
        case let .ok(response):
            let token = try decodeResponse(response.body.json)
            return token.token
        case let .badRequest(error):
            throw try badRequest(from: error)
        case let .unauthorized(error):
            throw try unauthorized(from: error)
        case let .forbidden(error):
            let message = try decodeResponse(error.body.json.error)
            throw MultichainClientAPIError.forbidden(message: message)
        case let .internalServerError(error):
            throw try internalError(from: error)
        case let .undocumented(statusCode, _):
            throw MultichainClientAPIError.undocumented(statusCode: statusCode)
        }
    }

    private func mapSearchAssetsOutput(_ output: MultichainAPI.Operations.searchAssets.Output) throws(MultichainClientAPIError) -> ([MultichainAsset], String?) {
        switch output {
        case let .ok(assets):
            let payload = try decodeResponse(assets.body.json)
            let list = payload.assets.map { MultichainAsset(api: $0, balance: .zero) }
            return (list, normalizedNextCursor(payload.next_cursor))
        case let .badRequest(error):
            throw try badRequest(from: error)
        case let .internalServerError(error):
            throw try internalError(from: error)
        case let .undocumented(statusCode, _):
            throw MultichainClientAPIError.undocumented(statusCode: statusCode)
        }
    }

    private func mapWalletAssetsOutput(_ output: MultichainAPI.Operations.getWalletAssets.Output) throws(MultichainClientAPIError) -> MultichainWalletAssetRecordsPage {
        switch output {
        case let .ok(walletAssets):
            let payload = try decodeResponse(walletAssets.body.json)
            let records: [MultichainWalletAssetRecord] = payload.assets.compactMap { asset in
                guard let chain = MultichainAssetDetails(api: asset.asset).chain else {
                    return nil
                }
                return MultichainWalletAssetRecord(
                    asset: MultichainAsset(api: asset),
                    account: MultichainWalletAddress(
                        chain: chain,
                        address: asset.address,
                        type: asset._type.flatMap { MultichainWalletAddressType(api: $0) }
                    )
                )
            }
            if records.count != payload.assets.count {
                Log.w("Multichain: dropped \(payload.assets.count - records.count) of \(payload.assets.count) wallet asset records with unrecognized chain")
            }
            return MultichainWalletAssetRecordsPage(
                records: records,
                nextCursor: normalizedNextCursor(payload.next_cursor)
            )
        case let .badRequest(error):
            throw try badRequest(from: error)
        case let .forbidden(error):
            throw try forbidden(from: error)
        case let .notFound(error):
            throw try notFound(from: error)
        case let .internalServerError(error):
            throw try internalError(from: error)
        case let .undocumented(statusCode, _):
            throw MultichainClientAPIError.undocumented(statusCode: statusCode)
        }
    }

    private func mapWalletActivitiesOutput(_ output: MultichainAPI.Operations.getWalletActivities.Output) throws(MultichainClientAPIError) -> MultichainWalletActivitiesPage {
        switch output {
        case let .ok(activities):
            let payload = try decodeResponse(activities.body.json)
            let list = payload.activities.compactMap { MultichainActivity(api: $0) }
            return MultichainWalletActivitiesPage(
                activities: list,
                nextCursor: payload.next_cursor.flatMap { normalizedNextCursor($0) }
            )
        case let .badRequest(error):
            throw try badRequest(from: error)
        case let .forbidden(error):
            throw try forbidden(from: error)
        case let .notFound(error):
            throw try notFound(from: error)
        case let .internalServerError(error):
            throw try internalError(from: error)
        case let .undocumented(statusCode, _):
            throw MultichainClientAPIError.undocumented(statusCode: statusCode)
        }
    }

    private func normalizedNextCursor(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func apiCall<T>(
        _ block: @autoclosure () async throws -> T
    ) async throws(MultichainClientAPIError) -> T {
        do {
            return try await block()
        } catch let error as DeviceAuthError {
            switch error {
            case .cancelled:
                throw .cancelled
            case .connectionError:
                throw .connectionError(underlying: error)
            case let .unauthorized(reason):
                throw .unauthorized(message: reason)
            case let .failed(message):
                throw .badStatus(message: message)
            }
        } catch {
            throw error.isCancelledError ? .cancelled : .connectionError(underlying: error)
        }
    }

    private func decodeResponse<T>(
        _ block: @autoclosure () throws -> T
    ) throws(MultichainClientAPIError) -> T {
        do {
            return try block()
        } catch {
            throw .badResponse(underlying: error)
        }
    }

    private func badRequest(from response: MultichainAPI.Components.Responses.BadRequest) throws(MultichainClientAPIError) -> MultichainClientAPIError {
        try .badStatus(message: decodeResponse(response.body.json.error))
    }

    private func forbidden(from response: MultichainAPI.Components.Responses.Forbidden) throws(MultichainClientAPIError) -> MultichainClientAPIError {
        try .badStatus(message: decodeResponse(response.body.json.error))
    }

    private func notFound(from response: MultichainAPI.Components.Responses.NotFound) throws(MultichainClientAPIError) -> MultichainClientAPIError {
        try .badStatus(message: decodeResponse(response.body.json.error))
    }

    private func tooManyRequests(from response: MultichainAPI.Components.Responses.TooManyRequests) throws(MultichainClientAPIError) -> MultichainClientAPIError {
        try .badStatus(message: decodeResponse(response.body.json.error))
    }

    private func unauthorized(from response: MultichainAPI.Components.Responses.Unauthorized) throws(MultichainClientAPIError) -> MultichainClientAPIError {
        try .unauthorized(message: decodeResponse(response.body.json.error))
    }

    private func internalError(from response: MultichainAPI.Components.Responses.InternalError) throws(MultichainClientAPIError) -> MultichainClientAPIError {
        try .badStatus(message: decodeResponse(response.body.json.error))
    }
}
