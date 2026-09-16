import SwapAPI

public struct MultichainSwapPrepareRouteRequest: Sendable, Hashable {
    public var approvalMode: String?
}

extension MultichainSwapPrepareRouteRequest {
    func swapAPIRequestBody() throws(MultichainSwapAPIError) -> SwapAPI.Components.RequestBodies.CrossSwapPrepare? {
        guard let approvalMode else {
            return nil
        }
        guard let mode = SwapAPI.Components.Schemas.CrossSwapApprovalMode(rawValue: approvalMode) else {
            throw MultichainSwapAPIError.badRequest(
                message: "Invalid approval_mode: \(approvalMode)",
                code: nil,
                requestId: nil
            )
        }
        return .json(.init(approval_mode: mode))
    }
}
