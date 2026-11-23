import Foundation
import TKEarnAPI

protocol EarnAPI: Sendable {
    func vaults(
        currencies: [String],
        underlyingAssetIds: [String]?
    ) async throws(EarnAPIError) -> [Components.Schemas.Vault]

    func walletBalance(
        walletId: String,
        currencies: [String],
        refresh: Bool
    ) async throws(EarnAPIError) -> Components.Schemas.Balance
}

struct EarnAPIImplementation: EarnAPI {
    private let makeClient: @Sendable () async -> Client
    /// Built per call: the wallet proof is valid only for the device token it signs.
    private let makeWalletClient: @Sendable (_ walletId: String) async -> Client

    init(
        makeClient: @escaping @Sendable () async -> Client,
        makeWalletClient: @escaping @Sendable (_ walletId: String) async -> Client
    ) {
        self.makeClient = makeClient
        self.makeWalletClient = makeWalletClient
    }

    func vaults(
        currencies: [String],
        underlyingAssetIds: [String]?
    ) async throws(EarnAPIError) -> [Components.Schemas.Vault] {
        let client = await makeClient()
        let response: Operations.getVaults.Output
        do {
            response = try await client.getVaults(
                query: .init(currencies: currencies, underlying_asset_ids: underlyingAssetIds)
            )
        } catch {
            throw .transport(error)
        }

        switch response {
        case let .ok(ok):
            do {
                return try ok.body.json.vaults
            } catch {
                throw .badResponse(error)
            }
        case let .default(statusCode, payload):
            throw .badStatus(statusCode, code: try? payload.body.json.code)
        }
    }

    func walletBalance(
        walletId: String,
        currencies: [String],
        refresh: Bool
    ) async throws(EarnAPIError) -> Components.Schemas.Balance {
        let client = await makeWalletClient(walletId)
        let response: Operations.getWalletBalance.Output
        do {
            response = try await client.getWalletBalance(
                path: .init(wallet_id: walletId),
                query: .init(currencies: currencies, refresh: refresh)
            )
        } catch {
            throw .transport(error)
        }

        switch response {
        case let .ok(ok):
            do {
                return try ok.body.json
            } catch {
                throw .badResponse(error)
            }
        case let .default(statusCode, payload):
            throw .badStatus(statusCode, code: try? payload.body.json.code)
        }
    }
}
