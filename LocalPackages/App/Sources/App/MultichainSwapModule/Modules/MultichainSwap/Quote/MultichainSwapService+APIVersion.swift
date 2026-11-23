import KeeperCore

extension MultichainSwapService {
    /// `request` quoted on `apiVersion`. `/v3` files the swap under the wallet's id, so a wallet the
    /// backend does not know is quoted on `/v2`, and its routes say so.
    func createCrossSwapQuote(
        request: MultichainSwapQuoteRequest,
        walletId: String?,
        apiVersion: MultichainSwapAPIVersion
    ) async throws(MultichainSwapAPIError) -> MultichainSwapQuote {
        if apiVersion == .v3, let walletId {
            return try await createCrossSwapQuoteV3(request: request, walletId: walletId)
        }
        return try await createCrossSwapQuote(request: request, walletId: walletId)
    }
}
