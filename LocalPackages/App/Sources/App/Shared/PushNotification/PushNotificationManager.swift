import UIKit
import UserNotifications
import TKCore
import KeeperCore
import TonSwift

final class PushNotificationManager {
  
  private var deferedActions = [(String) -> Void]()
  
  private let appSettings: AppSettings
  private let pushNotificationTokenProvider: PushNotificationTokenProvider
  private let pushNotificationAPI: PushNotificationsAPI
  private let walletNotificationsStore: WalletNotificationStore
  
  init(appSettings: AppSettings, 
       pushNotificationTokenProvider: PushNotificationTokenProvider,
       pushNotificationAPI: PushNotificationsAPI,
       walletNotificationsStore: WalletNotificationStore) {
    self.appSettings = appSettings
    self.pushNotificationTokenProvider = pushNotificationTokenProvider
    self.pushNotificationAPI = pushNotificationAPI
    self.walletNotificationsStore = walletNotificationsStore
  }
  
  func setup() {
    pushNotificationTokenProvider.setup()
    walletNotificationsStore.addObserver(
      self,
      notifyOnAdded: false) { observer, newState, oldState in
        observer.handleNotificationsStoreStateUpdate(newState: newState, oldState: oldState)
      }
    
    pushNotificationTokenProvider.didUpdateToken = { [appSettings] token in
      guard appSettings.fcmToken != token else {
        return
      }
      appSettings.fcmToken = token
      // resubscribe all wallets
    }
    Task {
      await registerForPushNotificationsIfNeeded()
    }
  }
  
  private func registerForPushNotificationsIfNeeded() async {
    let notificationCenter = UNUserNotificationCenter.current()
    switch await notificationCenter.notificationSettings().authorizationStatus {
    case .authorized:
      await registerForPushNotifications()
    default:
      break
    }
  }
  
  private func registerForPushNotifications() async {
    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
    do {
      guard try await UNUserNotificationCenter.current().requestAuthorization(options: authOptions) else {
        return
      }
      await UIApplication.shared.registerForRemoteNotifications()
    } catch {
      print("Log 🪵: PushNotificationManager — failed to register for remote notifications")
    }
  }
  
  private func handleNotificationsStoreStateUpdate(newState: [FriendlyAddress: Bool],
                                                   oldState: [FriendlyAddress: Bool]) {
    newState.keys.forEach { address in
      guard newState[address] != oldState[address] else {
        return
      }
      if newState[address] == true {
        subscribePushNotifications(address: address)
      } else {
        unsubscribePushNotifications(address: address)
      }
    }
  }
  
  private func subscribePushNotifications(address: FriendlyAddress) {
    let action: (String) -> Void = { [appSettings, pushNotificationAPI] token in
      Task {
        _ = try await pushNotificationAPI.subscribeNotifications(
          subscribeData: PushNotificationsAPI.SubscribeData(
            token: token,
            device: appSettings.installDeviceID,
            accounts: [PushNotificationsAPI.SubscribeData.Account(address: address.toString())],
            locale: Locale.current.languageCode ?? "en"
          )
        )
      }
    }
    
    Task {
      switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
      case .authorized:
        break
      default:
        await registerForPushNotifications()
      }
      guard let token = await pushNotificationTokenProvider.getToken() else {
        await MainActor.run {
          deferedActions.append(action)
        }
        return
      }
      
      action(token)
    }
  }
  
  private func unsubscribePushNotifications(address: FriendlyAddress) {
    let action: (String) -> Void = { [appSettings, pushNotificationAPI] token in
      Task {
        _ = try await pushNotificationAPI.unsubscribeNotifications(
          unsubscribeData: PushNotificationsAPI.UnsubscribeData(
            device: appSettings.installDeviceID,
            accounts: [PushNotificationsAPI.UnsubscribeData.Account(address: address.toString())]
          )
        )
      }
    }
    
    Task {
      guard let token = await pushNotificationTokenProvider.getToken() else {
        await MainActor.run {
          deferedActions.append(action)
        }
        return
      }
      
      action(token)
    }
  }
  
  private func performDefferedActions(token: String) {
    deferedActions.forEach {
      $0(token)
    }
  }
}
