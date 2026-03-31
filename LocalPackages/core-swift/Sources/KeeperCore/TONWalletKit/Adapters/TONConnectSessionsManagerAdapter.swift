import Foundation
import TonSwift
import TONWalletKit

final class TONConnectSessionsManagerAdapter: TONConnectSessionsManager {
    private let tonConnectService: TonConnectService
    private let appsStore: TonConnectAppsStore
    private let walletsStore: WalletsStore

    init(
        tonConnectService: TonConnectService,
        walletsStore: WalletsStore,
        appsStore: TonConnectAppsStore
    ) {
        self.tonConnectService = tonConnectService
        self.walletsStore = walletsStore
        self.appsStore = appsStore
    }

    func createSession(with parameters: TONConnectSessionCreationParameters) async throws -> TONConnectSession {
        let walletId = parameters.wallet.id

        guard let wallet = walletsStore.wallets.first(where: { (try? $0.walletKitIdentifier) == walletId }) else {
            throw "Wallet not found"
        }

        guard let appUrl = parameters.dAppInfo.url else {
            throw "Invalid manifest URL"
        }

        let sessionCrypto = try TonConnectSessionCrypto(sessionId: parameters.sessionId)

        let manifest = TonConnectManifest(
            url: appUrl,
            name: parameters.dAppInfo.name ?? "",
            iconUrl: parameters.dAppInfo.iconUrl
        )

        let connectionType: TonConnectApp.ConnectionType = parameters.isJsBridge ? .bridge : .remote

        let tonConnectParameters = TonConnectParameters(
            version: .v2,
            clientId: parameters.sessionId,
            requestPayload: TonConnectRequestPayload(manifestUrl: appUrl, items: [])
        )

        try tonConnectService.storeConnectedApp(
            wallet: wallet,
            sessionCrypto: sessionCrypto,
            parameters: tonConnectParameters,
            manifest: manifest,
            connectionType: connectionType
        )

        let now = ISO8601DateFormatter().string(from: Date())
        let walletAddress = parameters.wallet.address

        return TONConnectSession(
            sessionId: parameters.sessionId,
            walletId: walletId,
            walletAddress: walletAddress,
            createdAt: now,
            lastActivityAt: now,
            privateKey: sessionCrypto.keyPair.privateKey.hexString,
            publicKey: sessionCrypto.keyPair.publicKey.hexString,
            domain: manifest.host,
            dAppName: parameters.dAppInfo.name,
            dAppDescription: parameters.dAppInfo.description,
            dAppUrl: appUrl,
            dAppIconUrl: parameters.dAppInfo.iconUrl,
            isJsBridge: parameters.isJsBridge,
            schemaVersion: 1
        )
    }

    private func sessions() async throws -> [TONConnectSession] {
        let wallets = walletsStore.wallets
        var allSessions: [TONConnectSession] = []

        for wallet in wallets {
            if let apps = try? tonConnectService.getConnectedApps(forWallet: wallet) {
                for app in apps.apps {
                    if let session = try? buildSession(from: app, wallet: wallet) {
                        allSessions.append(session)
                    }
                }
            }
        }
        return allSessions
    }

    func session(id: TONConnectSessionID) async throws -> TONConnectSession? {
        let allSessions = try await sessions()
        return allSessions.first { $0.sessionId == id }
    }

    func sessions(filter: TONConnectSessionsFilter?) async throws -> [TONConnectSession] {
        let sessions = try await sessions()
        let domain = filter?.domain.flatMap { URL(string: $0)?.host ?? $0 }

        return sessions.filter {
            if let walletId = filter?.walletId, $0.walletId != walletId {
                return false
            }

            if let domain, $0.domain != domain {
                return false
            }

            if let isJsBridge = filter?.isJsBridge, $0.isJsBridge != isJsBridge {
                return false
            }

            return true
        }
    }

    func removeSession(id: TONConnectSessionID) async throws {
        for wallet in walletsStore.wallets {
            guard let apps = try? tonConnectService.getConnectedApps(forWallet: wallet) else { continue }

            if let appToRemove = apps.apps.first(where: { $0.clientId == id }) {
                try appsStore.disconnect(wallet: wallet, appClientId: appToRemove.clientId)
            }
        }
    }

    func removeSessions(filter: TONConnectSessionsFilter?) async throws {
        let sessions = try await sessions(filter: filter)

        for session in sessions {
            try? await removeSession(id: session.sessionId)
        }
    }

    func removeAllSessions() async throws {
        for wallet in walletsStore.wallets {
            guard let apps = try? tonConnectService.getConnectedApps(forWallet: wallet) else { continue }

            for app in apps.apps {
                try? appsStore.disconnect(wallet: wallet, appUrl: app.manifest.url)
            }
        }
    }

    // MARK: - Private

    private func buildSession(from app: TonConnectApp, wallet: Wallet) throws -> TONConnectSession {
        let walletAddress = try wallet.friendlyAddress.toString()
        let now = ISO8601DateFormatter().string(from: Date())
        let walletId = try wallet.walletKitIdentifier

        return try TONConnectSession(
            sessionId: app.clientId,
            walletId: walletId,
            walletAddress: TONUserFriendlyAddress(value: walletAddress),
            createdAt: now,
            lastActivityAt: now,
            privateKey: app.keyPair.privateKey.hexString,
            publicKey: app.keyPair.publicKey.hexString,
            domain: app.manifest.host,
            dAppName: app.manifest.name,
            dAppDescription: nil,
            dAppUrl: app.manifest.url,
            dAppIconUrl: app.manifest.iconUrl,
            isJsBridge: app.connectionType == .bridge,
            schemaVersion: 1
        )
    }
}
