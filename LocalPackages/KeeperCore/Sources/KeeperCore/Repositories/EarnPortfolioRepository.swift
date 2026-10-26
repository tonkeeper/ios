import Foundation
import KeeperCoreComponents
import TKLogging

public struct EarnPortfolioRepository {
    private let service: EarnPortfolioService
    private let fileSystemVault: FileSystemVault<[EarnPosition], String>

    init(
        service: EarnPortfolioService,
        fileSystemVault: FileSystemVault<[EarnPosition], String>
    ) {
        self.service = service
        self.fileSystemVault = fileSystemVault
    }

    public func cachedPositions(address: String) -> [EarnPosition]? {
        do {
            return try fileSystemVault.loadItem(key: Self.key(address: address))
        } catch FileSystemVault<[EarnPosition], String>.LoadError.noItem {
            return nil
        } catch {
            Log.w("earn positions cache is unreadable", extraInfo: ["error": "\(error)"])
            return nil
        }
    }

    public func loadPositions(address: String) async throws -> [EarnPosition] {
        let positions = try await service.loadPositions(address: address)
        do {
            try fileSystemVault.saveItem(positions, key: Self.key(address: address))
        } catch {
            Log.w("earn positions cache write failed", extraInfo: ["error": "\(error)"])
        }
        return positions
    }

    private static func key(address: String) -> String {
        "EarnPositions_\(address.lowercased())"
    }
}
