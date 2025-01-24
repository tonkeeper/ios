import Foundation

public protocol NotificationsService {
  func turnOnDappNotifications(wallet: Wallet, 
                               manifest: TonConnectManifest,
                               sessionId: String?,
                               token: String) async throws -> Bool
  func turnOffDappNotifications(wallet: Wallet, 
                                manifest: TonConnectManifest,
                                sessionId: String?,
                                token: String) async throws -> Bool
}

final class NotificationsServiceImplementation: NotificationsService {
  
  enum Error: Swift.Error {
    case invalidDapp(String)
  }
  
  private let pushNotificationAPI: PushNotificationsAPI
  private let walletNotificationsStore: WalletNotificationStore
  private let tonConnectAppsStore: TonConnectAppsStore
  private let tonProofTokenService: TonProofTokenService
  
  init(pushNotificationAPI: PushNotificationsAPI, 
       walletNotificationsStore: WalletNotificationStore,
       tonConnectAppsStore: TonConnectAppsStore,
       tonProofTokenService: TonProofTokenService) {
    self.pushNotificationAPI = pushNotificationAPI
    self.walletNotificationsStore = walletNotificationsStore
    self.tonConnectAppsStore = tonConnectAppsStore
    self.tonProofTokenService = tonProofTokenService
  }
  
  func turnOnDappNotifications(wallet: Wallet,
                               manifest: TonConnectManifest,
                               sessionId: String?, 
                               token: String) async throws -> Bool {
  let apps = try tonConnectAppsStore.connectedApps(forWallet: wallet)
    let tonProof = try tonProofTokenService.getWalletToken(wallet)
    let isPushNotificationsOn = walletNotificationsStore.getState()[wallet]?.isOn ?? false
    
    let data = PushNotificationsAPI.DappSubscribeData(
      token: token,
      appURL: manifest.url.absoluteString,
      account: try wallet.address.toRaw(),
      tonProof: tonProof,
      sessionId: sessionId,
      commercial: true,
      silent: !isPushNotificationsOn
    )
    let result = try await pushNotificationAPI.subscribeDappNotifications(subscribeData: data)
    return result
  }
  
  func turnOffDappNotifications(wallet: Wallet,
                                manifest: TonConnectManifest,
                                sessionId: String?,
                                token: String) async throws -> Bool {
    let apps = try tonConnectAppsStore.connectedApps(forWallet: wallet)
    let tonProof = try tonProofTokenService.getWalletToken(wallet)
    let isPushNotificationsOn = walletNotificationsStore.getState()[wallet]?.isOn ?? false
    
    let data = PushNotificationsAPI.DappUnsubscribeData(
      token: token,
      appURL: manifest.url.absoluteString,
      account: try wallet.address.toRaw(),
      tonProof: tonProof)
    
    let result = try await pushNotificationAPI.unsubscribeDappNotifications(unsubscribeData: data)
    return result
  }
}
