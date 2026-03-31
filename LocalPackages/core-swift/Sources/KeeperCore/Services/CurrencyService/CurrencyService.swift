import CoreComponents
import Foundation

public protocol CurrencyService {
    func getActiveCurrency() throws -> Currency
}

final class CurrencyServiceImplementation: CurrencyService {
    let keeperInfoRepository: KeeperInfoRepository

    init(keeperInfoRepository: KeeperInfoRepository) {
        self.keeperInfoRepository = keeperInfoRepository
    }

    func getActiveCurrency() throws -> Currency {
        let keeperInfo = try keeperInfoRepository.getKeeperInfo()
        return keeperInfo.currency
    }
}
