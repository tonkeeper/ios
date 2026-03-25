import Foundation
import TONWalletKit

public extension TONWalletSendTransactionRequest {
    @discardableResult
    func approve(rawResponse: Data) async throws -> TONSendTransactionApprovalResponse {
        guard let json = try JSONSerialization.jsonObject(with: rawResponse) as? [String: Any] else {
            throw "Invalid sign data response structure"
        }

        guard let result = json["result"] as? String else {
            throw "Signature not found in response"
        }

        let base64 = try TONBase64(base64Encoded: result)
        let response = TONSendTransactionApprovalResponse(signedBoc: base64)

        return try await approve(response: response)
    }
}
