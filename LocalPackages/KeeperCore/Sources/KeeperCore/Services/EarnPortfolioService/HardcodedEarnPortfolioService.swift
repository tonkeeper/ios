import Foundation

struct HardcodedEarnPortfolioService: EarnPortfolioService {
    private let isEarnEnabled: Bool

    init(isEarnEnabled: Bool) {
        self.isEarnEnabled = isEarnEnabled
    }

    func loadPositions(address _: String) async throws -> [EarnPosition] {
        isEarnEnabled ? EarnHardcodedData.positions : []
    }
}
