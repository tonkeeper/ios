import Foundation
import TonSwift

public struct TonConnectApps: Codable {
    public let apps: [TonConnectApp]

    public func addApp(_ app: TonConnectApp) -> TonConnectApps {
        var mutableApps = apps
        mutableApps.append(app)
        return TonConnectApps(apps: mutableApps)
    }

    public func removeApp(_ app: TonConnectApp) -> TonConnectApps {
        let mutableApps = apps.filter { $0.manifest.host != app.manifest.host }
        return TonConnectApps(apps: mutableApps)
    }

    public func removeApp(at index: Int) -> TonConnectApps {
        var mutableApps = apps
        mutableApps.remove(at: index)
        return TonConnectApps(apps: mutableApps)
    }
}

public struct TonConnectApp: Codable, Equatable {
    public static func == (lhs: TonConnectApp, rhs: TonConnectApp) -> Bool {
        lhs.manifest.host == rhs.manifest.host
    }

    public enum ConnectionType: Int, Codable {
        case bridge
        case remote
        case unknown

        public init?(rawValue: Int) {
            switch rawValue {
            case 0:
                self = .bridge
            case 1:
                self = .remote
            default:
                self = .unknown
            }
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.clientId = try container.decode(String.self, forKey: .clientId)
        self.manifest = try container.decode(TonConnectManifest.self, forKey: .manifest)
        self.keyPair = try container.decode(KeyPair.self, forKey: .keyPair)
        do {
            self.connectionType = try container.decode(TonConnectApp.ConnectionType.self, forKey: .connectionType)
        } catch {
            self.connectionType = .unknown
        }
    }

    public init(clientId: String, manifest: TonConnectManifest, keyPair: TonSwift.KeyPair, connectionType: ConnectionType) {
        self.clientId = clientId
        self.manifest = manifest
        self.keyPair = keyPair
        self.connectionType = connectionType
    }

    public let clientId: String
    public let manifest: TonConnectManifest
    public let keyPair: TonSwift.KeyPair
    public let connectionType: ConnectionType
}
