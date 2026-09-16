import KeeperCore
import TKLogging

extension MultichainSwapConfirmationLogInfoMaker {
    static func feeAssetsLogDescription(_ fees: [MultichainTransactionEmulationResult]) -> String {
        fees.map(\.asset.assetId).joined(separator: ",")
    }
}
