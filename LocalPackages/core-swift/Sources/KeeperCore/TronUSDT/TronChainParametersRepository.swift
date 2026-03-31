import Foundation
import TKLogging

struct TronTRXResourcePrices: Codable, Sendable {
    let energySun: Int64
    let bandwidthSun: Int64
}

protocol TronChainParametersRepository: AnyObject {
    func trxResourcePrices() async -> TronTRXResourcePrices?
    func setTrxResourcePrices(_ value: TronTRXResourcePrices) async
}

actor TronChainParametersRepositoryImplementation: TronChainParametersRepository {
    private var cachedTRXResourcePrices: TronTRXResourcePrices?

    init() {}

    func trxResourcePrices() -> TronTRXResourcePrices? {
        cachedTRXResourcePrices
    }

    func setTrxResourcePrices(_ value: TronTRXResourcePrices) {
        cachedTRXResourcePrices = value
    }
}
