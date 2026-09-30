import Foundation
import TKLogging

struct TronChainFees: Codable, Sendable {
    let energySun: Int64
    let bandwidthSun: Int64
    let createAccountSun: Int64
    let createNewAccountSun: Int64
    let createNewAccountBandwidthRate: Int64
}

protocol TronChainParametersRepository: AnyObject {
    func chainFees() async -> TronChainFees?
    func setChainFees(_ value: TronChainFees) async
}

actor TronChainParametersRepositoryImplementation: TronChainParametersRepository {
    /// TRON can raise `getEnergyFee`/`getTransactionFee` at any time, and a stale price understates the fee.
    static let cacheLifetime: TimeInterval = 10 * 60

    private var cachedChainFees: TronChainFees?
    private var cachedAt: Date?
    private let lifetime: TimeInterval
    private let now: @Sendable () -> Date

    init(
        lifetime: TimeInterval = TronChainParametersRepositoryImplementation.cacheLifetime,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.lifetime = lifetime
        self.now = now
    }

    func chainFees() -> TronChainFees? {
        guard let cachedChainFees,
              let cachedAt,
              now().timeIntervalSince(cachedAt) < lifetime
        else {
            return nil
        }
        return cachedChainFees
    }

    func setChainFees(_ value: TronChainFees) {
        cachedChainFees = value
        cachedAt = now()
    }
}
