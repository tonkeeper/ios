import Foundation

public protocol OnRampService {
    func getMerchants(walletId: String?) async throws -> [OnRampMerchantInfo]
    func getLayout(flow: String, currency: String?, walletId: String?) async throws -> OnRampLayout
    func calculate(
        from: String,
        to: String,
        amount: String,
        walletAddress: String,
        purchaseType: OnRampPurchaseType,
        fromNetwork: String?,
        toNetwork: String?,
        paymentMethodType: String?,
        walletId: String?
    ) async throws -> OnRampCalculateResult
    func createExchange(
        from: String,
        to: String,
        fromNetwork: String?,
        toNetwork: String?,
        walletAddress: String,
        extraId: String?,
        flow: String
    ) async throws -> OnRampExchangeResult
    func createP2PSession(data: CreateP2PSession) async throws -> P2PSessionResult
    func clearCachedOnRampResponses()
}

final class OnRampServiceImplementation: OnRampService {
    private let onRampAPI: OnRampAPI
    private let repository: OnRampRepository
    private let onRampCacheTTL: TimeInterval = 60 * 60

    init(onRampAPI: OnRampAPI, repository: OnRampRepository) {
        self.onRampAPI = onRampAPI
        self.repository = repository
    }

    func getMerchants(walletId: String?) async throws -> [OnRampMerchantInfo] {
        if let cached = try? repository.getMerchants(walletId: walletId),
           Date().timeIntervalSince(cached.cachedAt) < onRampCacheTTL
        {
            return cached.data
        }
        let result = try await onRampAPI.getMerchants(walletId: walletId)
        try? repository.saveMerchants(result, walletId: walletId)
        return result
    }

    func getLayout(flow: String, currency: String?, walletId: String?) async throws -> OnRampLayout {
        if let cached = try? repository.getLayout(flow: flow, currency: currency, walletId: walletId),
           Date().timeIntervalSince(cached.cachedAt) < onRampCacheTTL
        {
            return cached.data
        }
        let result = try await onRampAPI.getLayout(flow: flow, currency: currency, walletId: walletId)
        try? repository.saveLayout(result, flow: flow, currency: currency, walletId: walletId)
        return result
    }

    func calculate(
        from: String,
        to: String,
        amount: String,
        walletAddress: String,
        purchaseType: OnRampPurchaseType,
        fromNetwork: String?,
        toNetwork: String?,
        paymentMethodType: String?,
        walletId: String?
    ) async throws -> OnRampCalculateResult {
        try await onRampAPI.calculate(
            from: from,
            to: to,
            amount: amount,
            walletAddress: walletAddress,
            purchaseType: purchaseType,
            fromNetwork: fromNetwork,
            toNetwork: toNetwork,
            paymentMethodType: paymentMethodType,
            walletId: walletId
        )
    }

    func createExchange(
        from: String,
        to: String,
        fromNetwork: String?,
        toNetwork: String?,
        walletAddress: String,
        extraId: String?,
        flow: String
    ) async throws -> OnRampExchangeResult {
        try await onRampAPI.createOnRampExchange(
            from: from,
            to: to,
            fromNetwork: fromNetwork,
            toNetwork: toNetwork,
            walletAddress: walletAddress,
            extraId: extraId,
            flow: flow
        )
    }

    func createP2PSession(data: CreateP2PSession) async throws -> P2PSessionResult {
        try await onRampAPI.createP2PSession(data: data)
    }

    func clearCachedOnRampResponses() {
        repository.clearCache()
    }
}
