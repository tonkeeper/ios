import Foundation

public protocol EarnPortfolioService: Sendable {
    func loadPositions(address: String) async throws -> [EarnPosition]
}
