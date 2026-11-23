import Foundation
import KeeperCore

/// Prepares a route once for everyone who asks for it: the fee row under the cards, the pricing details
/// and a swap started from the Swap button read one plan, and a route asked for while it is being
/// prepared waits for that preparation instead of starting another.
@MainActor
final class MultichainSwapPlanProvider {
    private typealias Preparation = Task<Result<MultichainSwapExecutionPlan, MultichainSwapExecutionFailure>, Never>

    private let swapWallet: MultichainSwapWallet
    private let executionService: MultichainSwapExecutionService
    private var preparations = [String: (preparation: Preparation, dateExpire: Date)]()

    init(swapWallet: MultichainSwapWallet, executionService: MultichainSwapExecutionService) {
        self.swapWallet = swapWallet
        self.executionService = executionService
    }

    /// A route that failed is prepared again on the next ask, unless only the chain's coin fell short of the
    /// fee: that answer is kept like a plan, so the pricing details open with the fee the row names. An expired
    /// route is prepared again too: the preparation reports it expired, so a swap held past its route's expiry,
    /// such as on the price impact warning, recovers a fresh route rather than sending the stale plan. A plan
    /// is kept only while what it signs can be signed: the operation `/v3` built for a route can stop being
    /// signed before the route expires, and the route is prepared again after that.
    /// `reusingPrepared: false` prepares a route again anyway, for balances that changed since it was, such
    /// as after a deposit.
    func plan(
        sourceAsset: MultichainAsset,
        destinationAsset: MultichainAsset,
        route: MultichainSwapRoute,
        reusingPrepared: Bool = true
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapExecutionPlan {
        let now = Date()
        let preparation: Preparation
        if reusingPrepared, let prepared = preparations[route.routeId], prepared.dateExpire > now {
            preparation = prepared.preparation
        } else {
            preparations = preparations.filter { $0.value.dateExpire > now }
            preparation = Task { [swapWallet, executionService] in
                do throws(MultichainSwapExecutionFailure) {
                    return try await .success(executionService.prepareExecutionPlan(
                        swapWallet: swapWallet,
                        sourceAsset: sourceAsset,
                        destinationAsset: destinationAsset,
                        route: route
                    ))
                } catch {
                    return .failure(error)
                }
            }
            preparations[route.routeId] = (preparation, route.dateExpire)
        }
        let result = await preparation.value
        switch result {
        case let .success(plan):
            if let expiresAt = plan.expiresAt,
               let prepared = preparations[route.routeId],
               prepared.preparation == preparation,
               expiresAt < prepared.dateExpire
            {
                preparations[route.routeId] = (preparation, expiresAt)
            }
        case .failure(.insufficientNativeFee):
            break
        case .failure:
            if preparations[route.routeId]?.preparation == preparation {
                preparations[route.routeId] = nil
            }
        }
        return try result.get()
    }
}
