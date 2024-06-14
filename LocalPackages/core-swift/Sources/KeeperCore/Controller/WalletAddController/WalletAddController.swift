import Foundation
import CoreComponents
import TonSwift

public final class WalletAddController {

  private let walletsStoreUpdate: WalletsStoreUpdate
  private let mnemonicsRepository: MnemonicsRepository
  
  init(walletsStoreUpdate: WalletsStoreUpdate,
       mnemonicsRepositoty: MnemonicsRepository) {
    self.walletsStoreUpdate = walletsStoreUpdate
    self.mnemonicsRepository = mnemonicsRepositoty
  }
  
  public func createWallet(metaData: WalletMetaData, passcode: String) async throws {
    let mnemonic = try Mnemonic(mnemonicWords: TonSwift.Mnemonic.mnemonicNew(wordsCount: 24))
    let keyPair = try TonSwift.Mnemonic.mnemonicToPrivateKey(
      mnemonicArray: mnemonic.mnemonicWords
    )
    let walletIdentity = WalletIdentity(
      network: .mainnet,
      kind: .Regular(keyPair.publicKey, .v4R2)
    )
    let wallet = Wallet(
      id: UUID().uuidString,
      identity: walletIdentity,
      metaData: metaData,
      setupSettings: WalletSetupSettings(backupDate: nil)
    )
    
    try await mnemonicsRepository.saveMnemonic(mnemonic, wallet: wallet, password: passcode)
    try walletsStoreUpdate.addWallets([wallet])
    
    try walletsStoreUpdate.makeWalletActive(wallet)
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
        emoji: metaData.emoji
      )
      
      let walletIdentity = WalletIdentity(
        network: network,
        kind: .Regular(keyPair.publicKey, revision)
      )
      
      return Wallet(
        id: UUID().uuidString,
        identity: walletIdentity,
        metaData: revisionMetaData,
        setupSettings: WalletSetupSettings(backupDate: Date()))
    }
    
    try await mnemonicsRepository.saveMnemonic(
      mnemonic,
      wallets: wallets,
      password: passcode
    )
    try walletsStoreUpdate.addWallets(wallets)
    try walletsStoreUpdate.makeWalletActive(wallets[0])
  }
  
  public func importWatchOnlyWallet(resolvableAddress: ResolvableAddress,
                                    metaData: WalletMetaData) throws {
    let wallet = Wallet(
      id: UUID().uuidString,
      identity: WalletIdentity(network: .mainnet, kind: .Watchonly(resolvableAddress)),
      metaData: metaData,
      setupSettings: WalletSetupSettings(backupDate: nil)
    )
    try walletsStoreUpdate.addWallets([wallet])
    try walletsStoreUpdate.makeWalletActive(wallet)
  }
  
  public func importSignerWallet(publicKey: TonSwift.PublicKey,
                                 revisions: [WalletContractVersion],
                                 metaData: WalletMetaData,
                                 isDevice: Bool) throws {
    let addPostfix = revisions.count > 1
    
    let wallets = revisions.map { revision in
      let label = addPostfix ? "\(metaData.label) \(revision.rawValue)" : metaData.label
      let revisionMetaData = WalletMetaData(
        label: label,
        tintColor: metaData.tintColor,
        emoji: metaData.emoji
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
        setupSettings: WalletSetupSettings(backupDate: Date()))
    }

    try walletsStoreUpdate.addWallets(wallets)
    try walletsStoreUpdate.makeWalletActive(wallets[0])
  }
  
  public func importLedgerWallet(publicKey: TonSwift.PublicKey,
                                 revisions: [WalletContractVersion],
                                 metaData: WalletMetaData) throws {
    let addPostfix = revisions.count > 1
    
    let wallets = revisions.map { revision in
      let label = addPostfix ? "\(metaData.label) \(revision.rawValue)" : metaData.label
      let revisionMetaData = WalletMetaData(
        label: label,
        tintColor: metaData.tintColor,
        emoji: metaData.emoji
      )
      
      
      let identity = WalletIdentity(
        network: .mainnet,
        kind: .Ledger(publicKey, revision)
      )
      
      return Wallet(
        id: UUID().uuidString,
        identity: identity,
        metaData: revisionMetaData,
        setupSettings: WalletSetupSettings(backupDate: Date()))
    }

    try walletsStoreUpdate.addWallets(wallets)
    try walletsStoreUpdate.makeWalletActive(wallets[0])
  }
}
