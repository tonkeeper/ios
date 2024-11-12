import Foundation
import CoreComponents
import TonSwift
import TonTransport

public final class WalletAddController {

  private let walletsStore: WalletsStore
  private let tonProofTokenService: TonProofTokenService
  private let mnemonicsRepository: MnemonicsRepository
  
  init(walletsStore: WalletsStore,
       tonProofTokenService: TonProofTokenService,
       mnemonicsRepositoty: MnemonicsRepository) {
    self.walletsStore = walletsStore
    self.tonProofTokenService = tonProofTokenService
    self.mnemonicsRepository = mnemonicsRepositoty
  }
  
  public func createWallet(metaData: WalletMetaData, passcode: String) async throws {
    let mnemonic = try Mnemonic(mnemonicWords: TonSwift.Mnemonic.mnemonicNew(wordsCount: 24))
    let keyPair = try TonSwift.Mnemonic.mnemonicToPrivateKey(
      mnemonicArray: mnemonic.mnemonicWords
    )
    let walletIdentity = WalletIdentity(
      network: .mainnet,
      kind: .Regular(keyPair.publicKey, .currentVersion)
    )
    let wallet = Wallet(
      id: UUID().uuidString,
      identity: walletIdentity,
      metaData: metaData,
      setupSettings: WalletSetupSettings(),
      batterySettings: BatterySettings()
    )
    
    await tonProofTokenService.loadTokensFor(
      pairs: [WalletPrivateKeyPair(
        wallet: wallet,
        privateKey: keyPair.privateKey
      )]
    )
    try await mnemonicsRepository.saveMnemonic(mnemonic, wallet: wallet, password: passcode)
    await walletsStore.addWallets([wallet])
  }
  
  public enum AddWalletRevisionError: Swift.Error {
    case unsupportedWalletKind
  }
  public func addWalletRevision(wallet: Wallet, revision: WalletContractVersion,  passcode: String) async throws {
    let mnemonic = try await mnemonicsRepository.getMnemonic(wallet: wallet, password: passcode)
    let keyPair = try TonSwift.Mnemonic.mnemonicToPrivateKey(
      mnemonicArray: mnemonic.mnemonicWords
    )
    
    let newWalletKind: WalletKind
    switch wallet.identity.kind {
    case .Regular(let publicKey, _):
      newWalletKind = .Regular(publicKey, revision)
    case .Signer(let publicKey, _):
      newWalletKind = .Signer(publicKey, revision)
    case .SignerDevice(let publicKey, _):
      newWalletKind = .SignerDevice(publicKey, revision)
    default:
      throw AddWalletRevisionError.unsupportedWalletKind
    }
    
    let newWalletIdentity = WalletIdentity(
      network: wallet.identity.network,
      kind: newWalletKind
    )

    let wallet = Wallet(
      id: UUID().uuidString,
      identity: newWalletIdentity,
      metaData: wallet.metaData,
      setupSettings: wallet.setupSettings,
      batterySettings: BatterySettings()
    )
    
    await tonProofTokenService.loadTokensFor(
      pairs: [WalletPrivateKeyPair(
        wallet: wallet,
        privateKey: keyPair.privateKey
      )]
    )
    try await mnemonicsRepository.saveMnemonic(mnemonic, wallet: wallet, password: passcode)
    await walletsStore.addWallets([wallet])
  }
  
  public func importWallets(phrase: [String],
                            revisions: [WalletContractVersion],
                            metaData: WalletMetaData,
                            passcode: String,
                            isTestnet: Bool) async throws {
    let mnemonic = try Mnemonic(mnemonicWords: phrase)
    let keyPair = try TonSwift.Mnemonic.mnemonicToPrivateKey(
      mnemonicArray: mnemonic.mnemonicWords
    )
    
    let addPostfix = revisions.count > 1

    let network: Network = isTestnet ? .testnet : .mainnet
    
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
        batterySettings: BatterySettings())
    }
    
    await tonProofTokenService.loadTokensFor(
      pairs: wallets.map {
        WalletPrivateKeyPair(
          wallet: $0,
          privateKey: keyPair.privateKey
        )
      }
    )
    try await mnemonicsRepository.saveMnemonic(
      mnemonic,
      wallets: wallets,
      password: passcode
    )
    await walletsStore.addWallets(wallets)
  }
  
  public func importWatchOnlyWallet(resolvableAddress: ResolvableAddress,
                                    metaData: WalletMetaData) async throws {
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
        batterySettings: BatterySettings())
    }
    await walletsStore.addWallets(wallets)
  }
  
  public func importSignerWallet(publicKey: TonSwift.PublicKey,
                                 revisions: [WalletContractVersion],
                                 metaData: WalletMetaData,
                                 isDevice: Bool) async throws {
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
        batterySettings: BatterySettings())
    }
    await walletsStore.addWallets(wallets)
  }
  
  public func importLedgerWallets(accounts: [LedgerAccount],
                                  deviceId: String,
                                  deviceProductName: String,
                                  metaData: WalletMetaData) async throws {
    let addPostfix = accounts.count > 1
    
    let wallets = accounts.enumerated().map { (index, account) in
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
        batterySettings: BatterySettings())
    }
    await walletsStore.addWallets(wallets)
  }
}
