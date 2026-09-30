import Foundation
import KeeperCoreComponents
import KeeperCoreSensitive
import TonSwift
import TonTransport
import TronSwift

public final class WalletAddController {
    private let walletsStore: WalletsStore
    private let tonProofTokenService: TonProofTokenService
    private let mnemonicAccess: MnemonicAccess
    private let importedWalletTronResolver: ImportedWalletTronResolver
    private let multichainAssembly: MultichainAssembly

    init(
        walletsStore: WalletsStore,
        tonProofTokenService: TonProofTokenService,
        mnemonicAccess: MnemonicAccess,
        tronBalanceService: TronBalanceService,
        multichainAssembly: MultichainAssembly
    ) {
        self.walletsStore = walletsStore
        self.tonProofTokenService = tonProofTokenService
        self.mnemonicAccess = mnemonicAccess
        self.importedWalletTronResolver = ImportedWalletTronResolver(
            tronBalanceService: tronBalanceService
        )
        self.multichainAssembly = multichainAssembly
    }

    public func createWallet(
        metaData: WalletMetaData,
        passcode: String,
        mnemonicWords: [String],
        setupSettings: WalletSetupSettings = WalletSetupSettings(),
        derivationType: DerivationType? = nil
    ) async throws {
        let mnemonic = CoreMnemonic(
            mnemonicWords: mnemonicWords,
            type: derivationType ?? .guessByWords(mnemonicWords)
        )
        let keyPair = try mnemonic.toKeyPair()
        let walletIdentity = WalletIdentity(
            network: .mainnet,
            kind: .Regular(keyPair.publicKey, .currentVersion)
        )
        let wallet = Wallet(
            id: UUID().uuidString,
            identity: walletIdentity,
            metaData: metaData,
            setupSettings: setupSettings,
            batterySettings: BatterySettings(),
            tron: Self.deriveWalletTron(
                mnemonic: mnemonic,
                network: .mainnet
            )
        )

        await tonProofTokenService.loadTokensFor(
            pairs: [WalletPrivateKeyPair(
                wallet: wallet,
                privateKey: keyPair.privateKey
            )]
        )
        try await mnemonicAccess.saveMnemonic(mnemonic, wallet: wallet, passcode: passcode)

        await walletsStore.addWallets([wallet])
        await enrichWalletsIfNeeded(passcode: passcode)
    }

    public enum AddWalletRevisionError: Swift.Error {
        case unsupportedWalletKind
    }

    public func addWalletRevision(wallet: Wallet, revision: WalletContractVersion, passcode: String) async throws {
        let mnemonic = try await mnemonicAccess.getMnemonic(wallet: wallet, passcode: passcode)
        let keyPair = try mnemonic.toKeyPair()

        let newWalletKind: WalletKind
        switch wallet.identity.kind {
        case let .Regular(publicKey, _):
            newWalletKind = .Regular(publicKey, revision)
        case let .Signer(publicKey, _):
            newWalletKind = .Signer(publicKey, revision)
        case let .SignerDevice(publicKey, _):
            newWalletKind = .SignerDevice(publicKey, revision)
        default:
            throw AddWalletRevisionError.unsupportedWalletKind
        }

        let newWalletIdentity = WalletIdentity(
            network: wallet.identity.network,
            kind: newWalletKind
        )

        let wallet = Self.makeWalletRevision(
            sourceWallet: wallet,
            identity: newWalletIdentity,
            mnemonic: mnemonic
        )

        await tonProofTokenService.loadTokensFor(
            pairs: [WalletPrivateKeyPair(
                wallet: wallet,
                privateKey: keyPair.privateKey
            )]
        )
        try await mnemonicAccess.saveMnemonic(mnemonic, wallet: wallet, passcode: passcode)
        await walletsStore.addWallets([wallet])
        await enrichWalletsIfNeeded(passcode: passcode)
    }

    public func importWallets(
        mnemonic: CoreMnemonic,
        revisions: [WalletContractVersion],
        metaData: WalletMetaData,
        passcode: String,
        network: Network,
        walletKindPreference: ImportWalletKindPreference
    ) async throws {
        let keyPair = try mnemonic.toKeyPair()
        let tronResolution = await importedWalletTronResolver.resolve(
            mnemonic: mnemonic,
            network: network,
            walletKindPreference: walletKindPreference
        )
        let addPostfix = revisions.count > 1

        let wallets = revisions.map { revision in
            let label = addPostfix ? "\(metaData.label) \(revision.rawValue)" : metaData.label
            let revisionMetaData = WalletMetaData(
                label: label,
                tintColor: metaData.tintColor,
                icon: metaData.icon
            )

            let walletIdentity = WalletIdentity(
                network: network,
                kind: .Regular(keyPair.publicKey, revision)
            )

            return Wallet(
                id: UUID().uuidString,
                identity: walletIdentity,
                metaData: revisionMetaData,
                setupSettings: WalletSetupSettings(backupDate: Date()),
                batterySettings: BatterySettings(),
                tron: tronResolution.tron,
                multichain: tronResolution.multichain
            )
        }

        await tonProofTokenService.loadTokensFor(
            pairs: wallets.map {
                WalletPrivateKeyPair(
                    wallet: $0,
                    privateKey: keyPair.privateKey
                )
            }
        )
        try await mnemonicAccess.saveMnemonic(
            mnemonic,
            wallets: wallets,
            passcode: passcode
        )
        await walletsStore.addWallets(wallets)
        await enrichWalletsIfNeeded(passcode: passcode)
        await reportRaffleImport(of: wallets)
    }

    static func makeWalletRevision(
        sourceWallet: Wallet,
        identity: WalletIdentity,
        mnemonic: CoreMnemonic
    ) -> Wallet {
        let tron: WalletTron?
        let multichain: MultichainWallet?
        if case .Regular = identity.kind {
            tron = sourceWallet.tron ?? deriveWalletTron(
                mnemonic: mnemonic,
                network: identity.network
            )
            multichain = tron == nil ? nil : .unavailable
        } else {
            tron = nil
            multichain = nil
        }

        return Wallet(
            id: UUID().uuidString,
            identity: identity,
            metaData: sourceWallet.metaData,
            setupSettings: sourceWallet.setupSettings,
            batterySettings: BatterySettings(),
            tron: tron,
            multichain: multichain
        )
    }

    private static func deriveWalletTron(
        mnemonic: CoreMnemonic,
        network: Network
    ) -> WalletTron? {
        guard network == .mainnet, mnemonic.type == .ton else {
            return nil
        }
        return WalletTron(tonMnemonic: mnemonic.mnemonicWords)
    }

    public func importWatchOnlyWallet(
        resolvableAddress: ResolvableAddress,
        metaData: WalletMetaData
    ) async throws {
        let wallet = Wallet(
            id: UUID().uuidString,
            identity: WalletIdentity(network: .mainnet, kind: .Watchonly(resolvableAddress)),
            metaData: metaData,
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings()
        )
        await walletsStore.addWallets([wallet])
    }

    public func importKeystoneWallet(
        publicKey: TonSwift.PublicKey,
        revisions: [WalletContractVersion],
        xfp: String?,
        path: String?,
        metaData: WalletMetaData
    ) async throws {
        let addPostfix = revisions.count > 1

        let wallets = revisions.map { revision in
            let label = addPostfix ? "\(metaData.label) \(revision.rawValue)" : metaData.label
            let revisionMetaData = WalletMetaData(
                label: label,
                tintColor: metaData.tintColor,
                icon: metaData.icon
            )

            let identity = WalletIdentity(
                network: .mainnet,
                kind: .Keystone(publicKey, xfp, path, revision)
            )

            return Wallet(
                id: UUID().uuidString,
                identity: identity,
                metaData: revisionMetaData,
                setupSettings: WalletSetupSettings(backupDate: Date()),
                batterySettings: BatterySettings()
            )
        }
        await walletsStore.addWallets(wallets)
    }

    public func importSignerWallet(
        publicKey: TonSwift.PublicKey,
        revisions: [WalletContractVersion],
        metaData: WalletMetaData,
        isDevice: Bool
    ) async throws {
        let addPostfix = revisions.count > 1

        let wallets = revisions.map { revision in
            let label = addPostfix ? "\(metaData.label) \(revision.rawValue)" : metaData.label
            let revisionMetaData = WalletMetaData(
                label: label,
                tintColor: metaData.tintColor,
                icon: metaData.icon
            )

            let identity: WalletIdentity
            if isDevice {
                identity = WalletIdentity(
                    network: .mainnet,
                    kind: .SignerDevice(publicKey, revision)
                )
            } else {
                identity = WalletIdentity(
                    network: .mainnet,
                    kind: .Signer(publicKey, revision)
                )
            }

            return Wallet(
                id: UUID().uuidString,
                identity: identity,
                metaData: revisionMetaData,
                setupSettings: WalletSetupSettings(backupDate: Date()),
                batterySettings: BatterySettings()
            )
        }
        await walletsStore.addWallets(wallets)
    }

    public func importLedgerWallets(
        accounts: [LedgerAccount],
        deviceId: String,
        deviceProductName: String,
        metaData: WalletMetaData
    ) async throws {
        let addPostfix = accounts.count > 1

        let wallets = accounts.enumerated().map { index, account in
            let label = addPostfix ? "\(metaData.label) \(index + 1)" : metaData.label
            let accountMetaData = WalletMetaData(
                label: label,
                tintColor: metaData.tintColor,
                icon: metaData.icon
            )

            let device = Wallet.LedgerDevice(deviceId: deviceId, deviceModel: deviceProductName, accountIndex: Int16(account.path.index))

            let identity = WalletIdentity(
                network: .mainnet,
                kind: .Ledger(account.publicKey, .v4R2, device)
            )

            return Wallet(
                id: UUID().uuidString,
                identity: identity,
                metaData: accountMetaData,
                setupSettings: WalletSetupSettings(backupDate: Date()),
                batterySettings: BatterySettings()
            )
        }
        await walletsStore.addWallets(wallets)
    }
}

private extension WalletAddController {
    func enrichWalletsIfNeeded(passcode: String) async {
        await multichainAssembly.walletAddressesEnricher.enrichMissingWallets(passcode: passcode)
        await multichainAssembly.walletSyncController.syncPendingWallets(passcode: passcode)
        await multichainAssembly.walletSyncController.warmMissingAppKeys(passcode: passcode)
    }

    /// A raffle task can send the user here to import a wallet, and the tickets go to the wallet
    /// the task was started from. Only the local ids are handed over: the reporter resolves them
    /// once the wallet is registered, which the enrichment above does not always get to.
    func reportRaffleImport(of wallets: [Wallet]) async {
        await multichainAssembly.raffleImportReporter.recordImported(walletIds: wallets.map(\.id))
    }
}
