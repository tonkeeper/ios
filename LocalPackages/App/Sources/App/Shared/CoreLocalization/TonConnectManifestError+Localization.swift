import KeeperCore
import TKLocalize

extension TonConnectManifestError {
    var description: String {
        switch self {
        case .incorrectURL:
            TKLocales.TonconnectManifestError.incorrectUrl
        case .loadFailed:
            TKLocales.TonconnectManifestError.loadFailed
        case .invalidManifest:
            TKLocales.TonconnectManifestError.invalidManifest
        }
    }
}
