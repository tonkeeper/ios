import Foundation
import KeeperCore
import TKLogging

enum MultichainSwapConfirmationQuoteRefreshError: LoggableError {
    case missingWalletAddress
    case noNonExpiredRoute
    case walletScreened(providerErrors: String)
}

extension MultichainSwapConfirmationQuoteRefreshError {
    var logDescription: String {
        switch self {
        case .missingWalletAddress:
            return "type=MultichainSwapConfirmationQuoteRefreshError, case=missingWalletAddress"
        case .noNonExpiredRoute:
            return "type=MultichainSwapConfirmationQuoteRefreshError, case=noNonExpiredRoute"
        case let .walletScreened(providerErrors):
            return "type=MultichainSwapConfirmationQuoteRefreshError, case=walletScreened, providerErrors=\(providerErrors)"
        }
    }

    var terminalFailure: MultichainSwapExecutionFailure? {
        switch self {
        case .missingWalletAddress, .noNonExpiredRoute:
            return nil
        case let .walletScreened(providerErrors):
            return .preparationFailed(kind: .walletScreened, reason: providerErrors)
        }
    }
}

struct MultichainSwapConfirmationQuoteRefresher {
    let multichainSwapService: MultichainSwapService
    let requestedAggregators: [String]

    func refresh(
        input: MultichainSwapConfirmationInput,
        selectedSlippageBps: Int,
        swapWallet: MultichainSwapWallet
    ) async throws -> MultichainSwapConfirmationQuoteState {
        let userInput = input.userInput
        guard let sourceChain = userInput.sendAsset.asset.chain,
              let destinationChain = userInput.receiveAsset.asset.chain,
              let senderAddress = swapWallet.address(for: sourceChain),
              let recipientAddress = swapWallet.address(for: destinationChain)
        else {
            throw MultichainSwapConfirmationQuoteRefreshError.missingWalletAddress
        }

        let quote = try await multichainSwapService.createCrossSwapQuote(
            request: MultichainSwapQuoteRequest(
                sourceAsset: userInput.sendAsset.asset.assetId,
                destinationAsset: userInput.receiveAsset.asset.assetId,
                amount: userInput.quoteAmount,
                senderAddress: senderAddress,
                recipientAddress: recipientAddress,
                slippageBps: selectedSlippageBps,
                aggregators: requestedAggregators,
                returnDepositAddress: MultichainSwapQuoteRequest.returnDepositAddress(sourceChain: sourceChain),
                includePayload: true,
                isMax: userInput.isMax ? true : nil
            ),
            walletId: swapWallet.walletId,
            apiVersion: input.quoteState.route.apiVersion
        )
        guard let route = quote.preferredRoute(at: Date()) else {
            if quote.hasWalletScreenedProviderError {
                throw MultichainSwapConfirmationQuoteRefreshError.walletScreened(
                    providerErrors: quote.providerErrorsLogDescription
                )
            }
            throw MultichainSwapConfirmationQuoteRefreshError.noNonExpiredRoute
        }

        return MultichainSwapConfirmationQuoteState(
            quote: quote,
            route: route
        )
    }
}
