import Foundation
import TonSwift
import BigInt

public final class SwapTransactionController {
    private let stonfiService: StonfiService
    
    init(stonfiService: StonfiService) {
        self.stonfiService = stonfiService
    }
}

public extension SwapTransactionController {
    func simulateSwap(sendAddress: Address, receiveAddress: Address, amount: BigUInt, tolerance: Double) async throws -> SimulateSwapInfo {
        return try await stonfiService.simulateSwap(sendAddress: sendAddress, receiveAddress: receiveAddress, amount: amount, tolerance: tolerance)
    }
}
