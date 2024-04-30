import Foundation

public struct TonConnectConnectModel {
  public struct Wallet {
    public let name: String
    public let address: String?
    public let emoji: String
    public let tintColor: WalletTintColor
  }
  
  public let name: String
  public let host: String
  public let address: String?
  public let wallet: Wallet
  public let appImageURL: URL?
}

public final class TonConnectConnectController {
  private let parameters: TonConnectParameters
  private let manifest: TonConnectManifest
  private let walletsStore: WalletsStore
  private let tonConnectAppsStore: TonConnectAppsStore
  public private(set) var selectedWallet: Wallet
  
  init(parameters: TonConnectParameters, 
       manifest: TonConnectManifest,
       walletsStore: WalletsStore,
       tonConnectAppsStore: TonConnectAppsStore) {
    self.parameters = parameters
    self.manifest = manifest
    self.walletsStore = walletsStore
    self.tonConnectAppsStore = tonConnectAppsStore
    
    self.selectedWallet = walletsStore.activeWallet
  }
  
  public func getModel() -> TonConnectConnectModel {
    return TonConnectConnectModel(
      name: manifest.name,
      host: manifest.host,
      address: try? selectedWallet.address.toString(bounceable: false),
      wallet: TonConnectConnectModel.Wallet(
        name: selectedWallet.metaData.label,
        address: try? selectedWallet.address.toShortString(bounceable: false),
        emoji: selectedWallet.metaData.emoji,
        tintColor: selectedWallet.metaData.tintColor
      ),
      appImageURL: manifest.iconUrl
    )
  }
  
  public func connect() async throws {
    try await tonConnectAppsStore.connect(
      wallet: selectedWallet,
      parameters: parameters,
      manifest: manifest
    )
  }
  
  public func needToShowWalletPicker() -> Bool {
    !walletsStore.wallets.isEmpty
  }
  
  public func setWallet(_ wallet: Wallet) {
    selectedWallet = wallet
  }
}
