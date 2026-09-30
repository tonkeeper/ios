import Foundation

public protocol MultichainRampService {
    func getLayoutCards(flow: String, currency: String?) async throws -> OnRampLayoutCards
    func getOnrampChains(query: OnRampChainsQuery, walletId: String?) async throws -> OnRampChains
    func getOnrampConfiguration(query: OnRampConfigurationQuery, walletId: String?) async throws -> OnRampConfiguration
    func getOnrampAsset(assetId: String, fiat: String?, walletId: String?) async throws -> OnRampAssetDetail
    func onrampQuote(request: OnRampQuoteRequest, walletId: String?) async throws -> OnRampQuotesResult
    func createOnrampOrder(request: OnRampCreateOrderRequest, walletId: String?) async throws -> OnRampOrder
    func getOnrampOrder(orderId: String) async throws -> OnRampOrder

    func getOfframpConfiguration(query: OffRampConfigurationQuery) async throws -> OffRampConfiguration
    func getOfframpAsset(assetId: String) async throws -> OffRampAssetDetail
    func offrampQuote(request: OffRampQuoteRequest) async throws -> OffRampQuotesResult
    func createOfframpOrder(request: OffRampCreateOrderRequest) async throws -> OffRampOrder
    func getOfframpOrder(orderId: String) async throws -> OffRampOrder
}

final class MultichainRampServiceImplementation: MultichainRampService {
    private let multichainRampAPI: MultichainRampAPI

    init(multichainRampAPI: MultichainRampAPI) {
        self.multichainRampAPI = multichainRampAPI
    }

    func getLayoutCards(flow: String, currency: String?) async throws -> OnRampLayoutCards {
        try await multichainRampAPI.getLayoutCards(flow: flow, currency: currency)
    }

    func getOnrampChains(query: OnRampChainsQuery, walletId: String?) async throws -> OnRampChains {
        try await multichainRampAPI.getOnrampChains(query: query, walletId: walletId)
    }

    func getOnrampConfiguration(query: OnRampConfigurationQuery, walletId: String?) async throws -> OnRampConfiguration {
        try await multichainRampAPI.getOnrampConfiguration(query: query, walletId: walletId)
    }

    func onrampQuote(request: OnRampQuoteRequest, walletId: String?) async throws -> OnRampQuotesResult {
        try await multichainRampAPI.onrampQuote(request: request, walletId: walletId)
    }

    func createOnrampOrder(request: OnRampCreateOrderRequest, walletId: String?) async throws -> OnRampOrder {
        try await multichainRampAPI.createOnrampOrder(request: request, walletId: walletId)
    }

    func getOnrampOrder(orderId: String) async throws -> OnRampOrder {
        try await multichainRampAPI.getOnrampOrder(orderId: orderId)
    }

    func getOnrampAsset(assetId: String, fiat: String?, walletId: String?) async throws -> OnRampAssetDetail {
        try await multichainRampAPI.getOnrampAsset(assetId: assetId, fiat: fiat, walletId: walletId)
    }

    func getOfframpConfiguration(query: OffRampConfigurationQuery) async throws -> OffRampConfiguration {
        try await multichainRampAPI.getOfframpConfiguration(query: query)
    }

    func offrampQuote(request: OffRampQuoteRequest) async throws -> OffRampQuotesResult {
        try await multichainRampAPI.offrampQuote(request: request)
    }

    func createOfframpOrder(request: OffRampCreateOrderRequest) async throws -> OffRampOrder {
        try await multichainRampAPI.createOfframpOrder(request: request)
    }

    func getOfframpOrder(orderId: String) async throws -> OffRampOrder {
        try await multichainRampAPI.getOfframpOrder(orderId: orderId)
    }

    func getOfframpAsset(assetId: String) async throws -> OffRampAssetDetail {
        try await multichainRampAPI.getOfframpAsset(assetId: assetId)
    }
}
