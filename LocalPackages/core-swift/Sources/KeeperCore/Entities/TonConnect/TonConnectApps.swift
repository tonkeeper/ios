import Foundation
import TonSwift

public struct TonConnectApps: Codable {
  public let apps: [TonConnectApp]
  
  public func addApp(_ app: TonConnectApp) -> TonConnectApps {
    var mutableApps = apps.filter { $0.manifest != app.manifest }
    mutableApps.append(app)
    return TonConnectApps(apps: mutableApps)
  }
  
  public func removeApp(_ app: TonConnectApp) -> TonConnectApps {
    var mutableApps = apps.filter { $0.manifest.host != app.manifest.host }
    return TonConnectApps(apps: mutableApps)
  }
}

public struct TonConnectApp: Codable {
  public let clientId: String
  public let manifest: TonConnectManifest
  public let keyPair: TonSwift.KeyPair
}
