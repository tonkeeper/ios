@testable import KeeperCore
import KeeperCoreComponents
import TonSwift
import XCTest

final class ChartDataRepositoryTests: XCTestCase {
    func test_repositoryReturnsSavedDataWithinCurrentSession() throws {
        let repository = SessionChartDataRepository()
        let token = "token-\(UUID().uuidString)"
        let coordinates = [
            Coordinate(x: 1, y: 10),
            Coordinate(x: 2, y: 20),
        ]

        try repository.saveChartData(
            coordinates: coordinates,
            period: .month,
            token: token,
            currency: .USD,
            network: .mainnet
        )

        let loadedCoordinates = repository.getChartData(
            period: .month,
            token: token,
            currency: .USD,
            network: .mainnet
        )

        XCTAssertEqual(loadedCoordinates?.map(\.x), coordinates.map(\.x))
        XCTAssertEqual(loadedCoordinates?.map(\.y), coordinates.map(\.y))
    }

    func test_repositoryReturnsNilForMissingKey() throws {
        let repository = SessionChartDataRepository()
        let token = "token-\(UUID().uuidString)"

        try repository.saveChartData(
            coordinates: [Coordinate(x: 1, y: 10)],
            period: .month,
            token: token,
            currency: .USD,
            network: .mainnet
        )

        let loadedCoordinates = repository.getChartData(
            period: .week,
            token: token,
            currency: .USD,
            network: .mainnet
        )

        XCTAssertNil(loadedCoordinates)
    }

    func test_repositoryReturnsNilForSavedEmptyData() throws {
        let repository = SessionChartDataRepository()
        let token = "token-\(UUID().uuidString)"

        try repository.saveChartData(
            coordinates: [],
            period: .month,
            token: token,
            currency: .USD,
            network: .mainnet
        )

        let loadedCoordinates = repository.getChartData(
            period: .month,
            token: token,
            currency: .USD,
            network: .mainnet
        )

        XCTAssertNil(loadedCoordinates)
    }

    func test_persistentRepositoryReturnsSavedDataAcrossRepositoryInstances() throws {
        let storageDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        addTeardownBlock {
            try? FileManager.default.removeItem(at: storageDirectory)
        }

        let token = "token-\(UUID().uuidString)"
        let coordinates = [
            Coordinate(x: 1, y: 10),
            Coordinate(x: 2, y: 20),
        ]

        let firstRepository = PersistentChartDataRepository(
            fileSystemVault: FileSystemVault(fileManager: .default, directory: storageDirectory)
        )
        try firstRepository.saveChartData(
            coordinates: coordinates,
            period: .month,
            token: token,
            currency: .USD,
            network: .mainnet
        )

        let secondRepository = PersistentChartDataRepository(
            fileSystemVault: FileSystemVault(fileManager: .default, directory: storageDirectory)
        )
        let loadedCoordinates = secondRepository.getChartData(
            period: .month,
            token: token,
            currency: .USD,
            network: .mainnet
        )

        XCTAssertEqual(loadedCoordinates?.map(\.x), coordinates.map(\.x))
        XCTAssertEqual(loadedCoordinates?.map(\.y), coordinates.map(\.y))
    }

    func test_persistentRepositoryReturnsSavedDataForMultichainAssetId() throws {
        let storageDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        addTeardownBlock {
            try? FileManager.default.removeItem(at: storageDirectory)
        }

        let token = "ton/mainnet/jetton/0:1234567890abcdef"
        let coordinates = [
            Coordinate(x: 1, y: 10),
            Coordinate(x: 2, y: 20),
        ]

        let firstRepository = PersistentChartDataRepository(
            fileSystemVault: FileSystemVault(fileManager: .default, directory: storageDirectory)
        )
        try firstRepository.saveChartData(
            coordinates: coordinates,
            period: .month,
            token: token,
            currency: .USD,
            network: .mainnet
        )

        let secondRepository = PersistentChartDataRepository(
            fileSystemVault: FileSystemVault(fileManager: .default, directory: storageDirectory)
        )
        let loadedCoordinates = secondRepository.getChartData(
            period: .month,
            token: token,
            currency: .USD,
            network: .mainnet
        )

        XCTAssertEqual(loadedCoordinates?.map(\.x), coordinates.map(\.x))
        XCTAssertEqual(loadedCoordinates?.map(\.y), coordinates.map(\.y))
    }

    func test_persistentRepositoryReturnsNilForReadFailure() throws {
        let storageDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        addTeardownBlock {
            try? FileManager.default.removeItem(at: storageDirectory)
        }

        let token = "token-\(UUID().uuidString)"
        let repository = PersistentChartDataRepository(
            fileSystemVault: FileSystemVault(fileManager: .default, directory: storageDirectory)
        )
        let folderURL = storageDirectory.appendingPathComponent(
            String(describing: [Coordinate].self),
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        let fileURL = folderURL.appendingPathComponent(
            "\(Period.month.stringValue)_\(Currency.USD.code)_\(token)_\(Network.mainnet.rawValue)"
        )
        try Data("not valid json".utf8).write(to: fileURL)

        let loadedCoordinates = repository.getChartData(
            period: .month,
            token: token,
            currency: .USD,
            network: .mainnet
        )

        XCTAssertNil(loadedCoordinates)
    }
}
