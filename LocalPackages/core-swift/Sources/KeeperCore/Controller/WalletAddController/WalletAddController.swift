import Foundation
import CoreComponents
import TonSwift
import TonTransport

public final class WalletAddController {

  private let walletsStoreUpdater: WalletsStoreUpdater
  private let mnemonicsRepository: MnemonicsRepository
  
  init(walletsStoreUpdater: WalletsStoreUpdater,
       mnemonicsRepositoty: MnemonicsRepository) {
    self.walletsStoreUpdater = walletsStoreUpdater
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
    await walletsStoreUpdater.addWallets([wallet])
    await walletsStoreUpdater.setWalletActive(wallet)
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
        setupSettings: WalletSetupSettings(backupDate: Date()))
    }
    
    try await mnemonicsRepository.saveMnemonic(
      mnemonic,
      wallets: wallets,
      password: passcode
    )
    await walletsStoreUpdater.addWallets(wallets)
    await walletsStoreUpdater.setWalletActive(wallets[0])
  }
  
  public func importWatchOnlyWallet(resolvableAddress: ResolvableAddress,
                                    metaData: WalletMetaData) async throws {
    let wallet = Wallet(
      id: UUID().uuidString,
      identity: WalletIdentity(network: .mainnet, kind: .Watchonly(resolvableAddress)),
      metaData: metaData,
      setupSettings: WalletSetupSettings(backupDate: nil)
    )
    await walletsStoreUpdater.addWallets([wallet])
    await walletsStoreUpdater.setWalletActive(wallet)
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
        setupSettings: WalletSetupSettings(backupDate: Date()))
    }

    await walletsStoreUpdater.addWallets(wallets)
    await walletsStoreUpdater.setWalletActive(wallets[0])
  }
  
  public func importLedgerWallets(accounts: [LedgerAccount],
                                  deviceId: String,
                                  deviceProductName: String,
                                  metaData: WalletMetaData) throws {
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
        setupSettings: WalletSetupSettings(backupDate: Date()))
    }

    await walletsStoreUpdater.addWallets(wallets)
    await walletsStoreUpdater.setWalletActive(wallets[0])
  }
}
