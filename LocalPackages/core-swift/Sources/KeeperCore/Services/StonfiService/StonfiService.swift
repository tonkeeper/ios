import Foundation
import TonSwift
import BigInt

protocol StonfiService {
    func simulateSwap(
        sendAddress: Address,
        receiveAddress: Address,
        amount: BigUInt,
        tolerance: Double
    ) async throws -> SimulateSwapInfo
    
    func createStakingTransactionParams(
        poolAddress: String,
        walletAddress: String,
        tokenAddress: String,
        amount: String,
        queryId: String
    ) async -> (to: String, payload: Cell, gasAmount: BigUInt)?
}

final class StonfiServiceImplementation: StonfiService {
    private let webViewApi: WKWebViewNetwork
    private let api: API
    
    init(webViewApi: WKWebViewNetwork, api: API) {
        self.webViewApi = webViewApi
        self.api = api
    }
    
    func simulateSwap(
        sendAddress: Address,
        receiveAddress: Address,
        amount: BigUInt,
        tolerance: Double
    ) async throws -> SimulateSwapInfo {
        return try await api.simulateSwap(sendAddress: sendAddress, receiveAddress: receiveAddress, amount: amount, tolerance: tolerance)
    }
    
    func createStakingTransactionParams(
        poolAddress: String,
        walletAddress: String,
        tokenAddress: String,
        amount: String,
        queryId: String
    ) async -> (to: String, payload: Cell, gasAmount: BigUInt)? {
        let input = WKWBNetworkRequestBuilder.CreateStakingTransactionBocInput(
            POOL_ADDRESS: poolAddress,
            WALLET_ADDRESS: walletAddress,
            TOKEN_ADDRESS: tokenAddress,
            AMOUNT: amount,
            QUERY_ID: queryId
        )
        
        let request = WKWBNetworkRequestBuilder.createStakingTransactionBoc(
            input: input
        )
        
        let result = try? await withCheckedThrowingContinuation { continuation in
            webViewApi.perform(request: request) { result in
                continuation.resume(with: result)
            }
        }
                
        guard let result,
              let to = result["to"] as? String,
              let payloadStr = result["payload"] as? String,
              let gasAmount = BigUInt(result["gasAmount"] as? String ?? "0")
        else { return nil }
        
        if let payload = try? payloadStr.toTonCell() {
            return (to, payload, gasAmount)
        }
        
        return nil
    }
}

private struct StonfiCell: Decodable {
    struct Bits: Decodable {
        let array: [String: Int]
        let length: Int?
        let cursor: Int?
    }
    let bits: Bits?
    let refs: [StonfiCell]?
}

private extension StonfiCell {
    func bitsToData() -> Data? {
        if let array = bits?.array.sorted(by: { $0.key < $1.key }).compactMap({ $0.value }) {
            return Data(bytes: array, count: array.count)
        }
        return nil
    }
}
