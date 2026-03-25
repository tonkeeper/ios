import CoreComponents
import Foundation

protocol SwapAssetsRepository {
    func getAssets() throws -> [SwapAsset]
    func saveAssets(_ assets: [SwapAsset]) throws
}

final class SwapAssetsRepositoryImplementation: SwapAssetsRepository {
    private let fileSystemVault: FileSystemVault<[SwapAsset], String>
    private let key = "swap_assets"

    init(fileSystemVault: FileSystemVault<[SwapAsset], String>) {
        self.fileSystemVault = fileSystemVault
    }

    func getAssets() throws -> [SwapAsset] {
        try fileSystemVault.loadItem(key: key)
    }

    func saveAssets(_ assets: [SwapAsset]) throws {
        try fileSystemVault.saveItem(assets, key: key)
    }
}
