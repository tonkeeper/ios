@testable import KeeperCore
import KeeperCoreComponents
import XCTest

final class EarnPortfolioRepositoryTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EarnPortfolioRepositoryTests-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    func testNothingIsCachedBeforeTheFirstLoad() {
        let repository = makeRepository(service: EarnPortfolioServiceStub(result: .success(positions)))

        XCTAssertNil(repository.cachedPositions(address: address))
    }

    func testLoadedPositionsAreCachedForTheirAddressOnly() async throws {
        let repository = makeRepository(service: EarnPortfolioServiceStub(result: .success(positions)))

        let loaded = try await repository.loadPositions(address: address)

        XCTAssertEqual(loaded, positions)
        XCTAssertEqual(repository.cachedPositions(address: address), positions)
        XCTAssertEqual(repository.cachedPositions(address: address.uppercased()), positions)
        XCTAssertNil(repository.cachedPositions(address: "0x2222222222222222222222222222222222222222"))
    }

    func testFailedLoadKeepsTheCachedPositions() async throws {
        let repository = makeRepository(service: EarnPortfolioServiceStub(result: .success(positions)))
        _ = try await repository.loadPositions(address: address)
        let failing = makeRepository(service: EarnPortfolioServiceStub(result: .failure(URLError(.notConnectedToInternet))))

        do {
            _ = try await failing.loadPositions(address: address)
            XCTFail("expected the load to fail")
        } catch {}

        XCTAssertEqual(failing.cachedPositions(address: address), positions)
    }
}

private extension EarnPortfolioRepositoryTests {
    var address: String {
        "0x1111111111111111111111111111111111111111"
    }

    var positions: [EarnPosition] {
        [
            EarnPosition(
                network: "mainnet",
                vaultId: "0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c",
                protocolName: "Aave",
                assetSymbol: "USDC",
                assetIconURL: nil,
                balanceUsd: Decimal(string: "1.92")!,
                earnedUsd: Decimal(string: "0.02")!
            ),
        ]
    }

    func makeRepository(service: EarnPortfolioService) -> EarnPortfolioRepository {
        EarnPortfolioRepository(
            service: service,
            fileSystemVault: FileSystemVault(fileManager: .default, directory: directory)
        )
    }
}

private struct EarnPortfolioServiceStub: EarnPortfolioService {
    let result: Result<[EarnPosition], Error>

    func loadPositions(address _: String) async throws -> [EarnPosition] {
        try result.get()
    }
}
