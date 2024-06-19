import Foundation
import TonSwift
import CoreComponents
import CryptoKit

public struct RNMigration {
  
  private let walletsStoreUpdate: WalletsStoreUpdate
  private var settingsRepository: SettingsRepository
  private let mnemonicsRepository: MnemonicsRepository
  private let keychainVault: KeychainVault
  
  init(walletsStoreUpdate: WalletsStoreUpdate,
       settingsRepository: SettingsRepository,
       mnemonicsRepository: MnemonicsRepository,
       keychainVault: KeychainVault) {
    self.walletsStoreUpdate = walletsStoreUpdate
    self.settingsRepository = settingsRepository
    self.mnemonicsRepository = mnemonicsRepository
    self.keychainVault = keychainVault
  }
  
  public func checkIfNeedToMigrate() -> Bool {
    !settingsRepository.didMigrateRN && getWalletsStoreState() != nil
  }
  
  public mutating func migrate(passcodeProvider: (_ passcodeValidation: @escaping (String) async -> Bool) async -> String) async throws {
    try await migrateMnemonics(passcodeProvider: passcodeProvider)
    migrateWallets()
  }
  
  enum MigrateError: Swift.Error {
    case failedMigrateWallet
  }
  
  enum MnemonicsMigrateError: Swift.Error {
    case noWalletsChunksCount
    case mnemonicsCorrupted
  }

  private func migrateMnemonics(passcodeProvider: (_ passcodeValidation: @escaping (String) async -> Bool) async -> String) async throws {
    let chunksCount: Int
    do {
      let chunksCountQuery = keychainQuery(key: "wallets_chunks")
      chunksCount = try keychainVault.readValue(chunksCountQuery)
    } catch {
      throw MnemonicsMigrateError.noWalletsChunksCount
    }
    
    let encryptedMnemonicsString: String
    do {
      encryptedMnemonicsString = try (0..<chunksCount)
        .map {
          let key = "wallets_chunk_\($0)"
          let query = keychainQuery(key: key)
          let chunkData = try keychainVault.read(query)
          guard let chunk = String(data: chunkData, encoding: .utf8) else {
            throw MnemonicsMigrateError.mnemonicsCorrupted
          }
          return chunk
        }
        .reduce(into: "") { $0 = $0 + $1 }
    } catch {
      throw MnemonicsMigrateError.mnemonicsCorrupted
    }
    
    let encryptedMnemonics = try JSONDecoder().decode(
      MnemonicsV3Vault.EncryptedMnemonics.self,
      from: encryptedMnemonicsString.data(
        using: .utf8
      )!
    )
    
    let passcodeValidation: (String) async -> Bool = { passcode in
      do {
        _ = try await ScryptHashBox.decrypt(
          string: encryptedMnemonics.ct,
          salt: encryptedMnemonics.salt,
          N: encryptedMnemonics.N,
          r: encryptedMnemonics.r,
          p: encryptedMnemonics.p,
          password: passcode
        )
        return true
      } catch {
        return false
      }
    }
    
    let passcode = await passcodeProvider(passcodeValidation)
    let decryptedData = try await ScryptHashBox.decrypt(
      string: encryptedMnemonics.ct,
      salt: encryptedMnemonics.salt,
      N: encryptedMnemonics.N,
      r: encryptedMnemonics.r,
      p: encryptedMnemonics.p,
      password: passcode
    )
    let rnMnemonics = try JSONDecoder().decode([String: RNMnemonic].self, from: decryptedData)
    let mnemonics = rnMnemonics.compactMapValues { try? Mnemonic(mnemonicWords: $0.mnemonic.components(separatedBy: " ")) }
    try await mnemonicsRepository.importMnemonics(mnemonics, password: passcode)
  }
  
  private func keychainQuery(key: String) -> KeychainQueryable {
    KeychainGenericPasswordItem(service: "app",
                                account: key,
                                accessGroup: nil,
                                accessible: .whenUnlocked)
  }
  
  private mutating func migrateWallets() {
    guard let walletsStoreState = getWalletsStoreState() else { return }

    do {
      let wallets = walletsStoreState.wallets
      let migratedWallets = wallets.compactMap { wallet -> Wallet? in
        return try? createWallet(walletConfig: wallet)
      }
      try walletsStoreUpdate.addWallets(migratedWallets)
      settingsRepository.didMigrateRN = true
    } catch {
      print("Log: failed to migrate from RN \(error)")
    }
  }
  
  private func getWalletsStoreState() -> RNWalletsStoreState? {
    let rnStorageDirectoryPath = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    )[0]
      .appendingPathComponent(Bundle.main.bundleIdentifier ?? "")
      .appendingPathComponent(.asyncStorageFolder)

    let jsonDecoder = JSONDecoder()
    let walletsStoreStateFileName = key(string: .walletsStoreKey)
    let walletsStoreStatePath = rnStorageDirectoryPath.appendingPathComponent(walletsStoreStateFileName)

    let manifestPath = rnStorageDirectoryPath
      .appendingPathComponent(.manifest)
    guard let manifestData = try? Data(contentsOf: manifestPath),
          let manifest = try? jsonDecoder.decode(RNManifest.self, from: manifestData) else {
      return nil
    }

    if let walletsStoreStateString = manifest.walletsStore,
       let walletsStoreStateData = walletsStoreStateString.data(using: .utf8) {
      do {
        let walletsStoreState = try jsonDecoder.decode(RNWalletsStoreState.self, from: walletsStoreStateData)
        return walletsStoreState
      } catch {
        return nil
      }
    } else if let walletsStoreStateData = try? Data(contentsOf: walletsStoreStatePath) {
      do {
        let walletsStoreState = try jsonDecoder.decode(RNWalletsStoreState.self, from: walletsStoreStateData)
        return walletsStoreState
      } catch {
        return nil
      }
    } else {
      return nil
    }
  }
  
  private func createWallet(walletConfig: RNWalletConfig) throws -> Wallet {

    guard let publicKeyData = Data(hex: walletConfig.pubkey) else {
      throw MigrateError.failedMigrateWallet
    }
    let publicKey = TonSwift.PublicKey(data: publicKeyData)

    let contractVersion: WalletContractVersion
    switch walletConfig.version {
    case .v3R1:
      contractVersion = .v3R1
    case .v3R2:
      contractVersion = .v3R2
    case .v4R1:
      contractVersion = .v4R1
    case .v4R2:
      contractVersion = .v4R2
    case .v5R1:
      contractVersion = .v5R1
    case .LockupV1:
      contractVersion = .v3R1
    }
    
    let network: Network
    switch walletConfig.network {
    case .mainnet:
      network = .mainnet
    case .testnet:
      network = .testnet
    }

    let contract: WalletContract
    switch contractVersion {
    case .v5R1:
      contract = WalletV5R1(
        publicKey: publicKey.data,
        walletId: WalletId(
          networkGlobalId: Int32(
            network.rawValue
          ),
          workchain: 0
        )
      )
    case .v4R2:
      contract = WalletV4R2(publicKey: publicKey.data)
    case .v4R1:
      contract = WalletV4R1(publicKey: publicKey.data)
    case .v3R2:
      contract = try WalletV3(workchain: 0, publicKey: publicKey.data, revision: .r2)
    case .v3R1:
      contract = try WalletV3(workchain: 0, publicKey: publicKey.data, revision: .r1)
    }

    let kind: WalletKind
    switch walletConfig.type {
    case .Ledger:
      guard let ledgerDevice = walletConfig.ledger else {
        throw MigrateError.failedMigrateWallet
      }
      kind = .Ledger(
        publicKey,
        contractVersion,
        Wallet.LedgerDevice(deviceId: ledgerDevice.deviceId,
                            deviceModel: ledgerDevice.deviceModel,
                            accountIndex: ledgerDevice.accountIndex)
      )
    case .Lockup:
      throw MigrateError.failedMigrateWallet
    case .Regular:
      kind = .Regular(publicKey, contractVersion)
    case .Signer:
      kind = .Signer(publicKey, contractVersion)
    case .SignerDeeplink:
      kind = .SignerDevice(publicKey, contractVersion)
    case .WatchOnly:
      kind = .Watchonly(.Resolved(try contract.address()))
    }
    
    let icon: WalletIcon
    if walletConfig.emoji.count == 1 {
      icon = .emoji(walletConfig.emoji)
    } else {
      icon = .icon(walletConfig.emoji)
    }
    
    let tintColor = WalletTintColor(rawValue: walletConfig.color) ?? .defaultColor
    
    return Wallet(
      id: walletConfig.identifier,
      identity: WalletIdentity(network: network, kind: kind),
      metaData: WalletMetaData(label: walletConfig.name, tintColor: tintColor, icon: icon),
      setupSettings: WalletSetupSettings(backupDate: Date())
    )
  }
  
}

private struct RNManifest: Decodable {
  let walletsStore: String?
}

private struct RNWalletsStoreState: Decodable {
  let wallets: [RNWalletConfig]
  let selectedIdentifier: String
  let biometryEnabled: Bool
  let lockScreenEnabled: Bool
}

private struct RNWalletConfig: Decodable {
  enum WalletType: String, Decodable {
    case Regular
    case Lockup
    case WatchOnly
    case Signer
    case SignerDeeplink
    case Ledger
  }

  enum WalletNetwork: Int, Decodable {
    case mainnet = -239
    case testnet = -3
  }

  enum WalletContractVersion: String, Decodable {
    case v5R1
    case v4R2
    case v4R1
    case v3R2
    case v3R1
    case LockupV1 = "lockup-0.1"
  }

  struct Ledger: Codable {
    let deviceId: String
    let deviceModel: String
    let accountIndex: Int16
  }

  let identifier: String
  let name: String
  let emoji: String
  let color: String
  let pubkey: String
  let network: WalletNetwork
  let type: WalletType
  let version: WalletContractVersion
  let workchain: Int
  let ledger: Ledger?
}

private struct RNMnemonic: Decodable {
  let identifier: String
  let mnemonic: String
}

private func key(string: String) -> String {
  let digest = Insecure.MD5.hash(data: Data(string.utf8))
  return digest.map {
    String(format: "%02hhx", $0)
  }.joined()
}

private extension String {
  static let asyncStorageFolder = "RCTAsyncLocalStorage_V1"
  static let manifest = "manifest.json"
  static let walletsStoreKey = "walletsStore"
}
