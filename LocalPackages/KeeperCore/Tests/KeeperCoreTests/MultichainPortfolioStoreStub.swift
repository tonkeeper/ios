import Foundation
@testable import KeeperCore

extension MultichainPortfolioStore {
    static func makeStub() -> MultichainPortfolioStore {
        MultichainPortfolioStore(
            walletsStore: WalletsStore(
                keeperInfoStore: KeeperInfoStore(keeperInfoRepository: EmptyKeeperInfoRepositoryStub())
            ),
            repository: InMemoryMultichainPortfolioRepository()
        )
    }
}

final class InMemoryMultichainPortfolioRepository: MultichainPortfolioRepository {
    enum Error: Swift.Error {
        case noPortfolio
    }

    private var portfolios = [String: MultichainPortfolio]()

    func getPortfolio(walletId: String) throws -> MultichainPortfolio {
        guard let portfolio = portfolios[walletId] else {
            throw Error.noPortfolio
        }
        return portfolio
    }

    func savePortfolio(_ portfolio: MultichainPortfolio, walletId: String) throws {
        portfolios[walletId] = portfolio
    }
}

struct EmptyKeeperInfoRepositoryStub: KeeperInfoRepository {
    enum Error: Swift.Error {
        case noKeeperInfo
    }

    func getKeeperInfo() throws -> KeeperInfo {
        throw Error.noKeeperInfo
    }

    func saveKeeperInfo(_: KeeperInfo) throws {}

    func removeKeeperInfo() throws {}
}
