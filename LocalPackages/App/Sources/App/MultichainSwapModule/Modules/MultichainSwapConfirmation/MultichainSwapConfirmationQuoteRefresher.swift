import BigInt
import Foundation
import KeeperCore
import TKLogging

enum MultichainSwapConfirmationQuoteRefreshError: LoggableError {
    case missingWalletAddress
    case noNonExpiredRoute(MultichainSwapQuote)
}

extension MultichainSwapConfirmationQuoteRefreshError {
    var logDescription: String {
        switch self {
        case .missingWalletAddress:
            return "type=MultichainSwapConfirmationQuoteRefreshError, case=missingWalletAddress"
        case .noNonExpiredRoute:
            return "type=MultichainSwapConfirmationQuoteRefreshError, case=noNonExpiredRoute"
        }
    }
}

struct MultichainSwapConfirmationQuoteRefresher {
    let multichainSwapService: MultichainSwapService
    let requestedAggregators: [String]

    func refresh(
        input: MultichainSwapConfirmationInput,
        selectedSlippageBps: Int,
        wallet: Wallet
    ) async throws -> MultichainSwapConfirmationQuoteState {
        let userInput = input.userInput
        guard let sourceChain = userInput.sendAsset.asset.chain,
              let destinationChain = userInput.receiveAsset.asset.chain,
              let senderAddress = walletAddress(for: sourceChain, wallet: wallet),
              let recipientAddress = walletAddress(for: destinationChain, wallet: wallet)
        else {
            throw MultichainSwapConfirmationQuoteRefreshError.missingWalletAddress
        }

        let quote = try await multichainSwapService.createCrossSwapQuote(
            request: MultichainSwapQuoteRequest(
                sourceAsset: userInput.sendAsset.asset.assetId,
                sourceAmount: userInput.sourceAmount.description,
                destinationAsset: userInput.receiveAsset.asset.assetId,
                senderAddress: senderAddress,
                recipientAddress: recipientAddress,
                slippageBps: selectedSlippageBps,
                exactType: MultichainSwapQuoteRequest.exactInputType,
                aggregators: requestedAggregators,
                returnDepositAddress: MultichainSwapQuoteRequest.returnDepositAddress(sourceChain: sourceChain),
                includePayload: true
            ),
            walletId: wallet.multichainWalletId
        )
        guard let route = quote.preferredRoute(at: Date()) else {
            throw MultichainSwapConfirmationQuoteRefreshError.noNonExpiredRoute(quote)
        }

        return MultichainSwapConfirmationQuoteState(
            quote: quote,
            route: route
        )
    }
}

private extension MultichainSwapConfirmationQuoteRefresher {
    func walletAddress(
        for chain: MultichainChain,
        wallet: Wallet
    ) -> String? {
        guard case let .multichain(state) = wallet.multichain else {
            return nil
        }
        return state.address(for: chain, preferredType: wallet.preferredMultichainAddressType(for: chain))
    }
}
