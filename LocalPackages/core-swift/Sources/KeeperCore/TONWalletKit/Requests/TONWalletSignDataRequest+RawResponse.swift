import Foundation
import TONWalletKit

public extension TONWalletSignDataRequest {
    @discardableResult
    func approve(rawResponse: Data) async throws -> TONSignDataApprovalResponse {
        guard let json = try JSONSerialization.jsonObject(with: rawResponse) as? [String: Any],
              let result = json["result"] as? [String: Any]
        else {
            throw "Invalid sign data response structure"
        }

        guard let responseData = try? JSONSerialization.data(withJSONObject: result) else {
            throw "Signature not found in response"
        }

        let decoder = JSONDecoder()
        let response = try decoder.decode(TONSignDataApprovalResponse.self, from: responseData)
        return try await approve(response: response)
    }
}
