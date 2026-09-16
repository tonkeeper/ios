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
        case noTotal
    }

    private var totals = [String: MultichainPortfolioTotal]()

    func getPortfolioTotal(walletId: String) throws -> MultichainPortfolioTotal {
        guard let total = totals[walletId] else {
            throw Error.noTotal
        }
        return total
    }

    func savePortfolioTotal(_ total: MultichainPortfolioTotal, walletId: String) throws {
        totals[walletId] = total
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
