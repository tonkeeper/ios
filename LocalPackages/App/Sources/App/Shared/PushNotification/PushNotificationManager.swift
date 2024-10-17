import UIKit
import UserNotifications
import TKCore
import KeeperCore
import TonSwift

final class PushNotificationManager {
  
  private var deferedActions = [(String) -> Void]()
  
  private let queue = DispatchQueue(label: "PushNotificationManagerQueue", qos: .userInitiated)
  private var notificationsUpdateTask = [Wallet: Task<Void, Never>]()
  
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
    walletNotificationsStore.addObserver(self) { observer, event in
      observer.queue.async {
        observer.didGetNotificationsStoreEvent(event)
      }
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
  
  private func didGetNotificationsStoreEvent(_ event: WalletNotificationStore.Event) {
    switch event {
    case .didUpdateNotificationsIsOn(let wallet):
      notificationsUpdateTask[wallet]?.cancel()
      let isOn = walletNotificationsStore.getState()[wallet]?.isOn ?? false
      if isOn {
        subscribePushNotifications(wallet: wallet)
      } else {
        unsubscribePushNotifications(wallet: wallet)
      }
    case .didUpdateDappNotificationsIsOn(wallet: let wallet):
      // TODO: send notification
      break
    }
  }
  
  private func subscribePushNotifications(wallet: Wallet) {
    let action: (String) -> Void = { [appSettings, pushNotificationAPI] token in
      Task {
        _ = try await pushNotificationAPI.subscribeNotifications(
          subscribeData: PushNotificationsAPI.SubscribeData(
            token: token,
            device: appSettings.installDeviceID,
            accounts: [PushNotificationsAPI.SubscribeData.Account(address: wallet.friendlyAddress.toString())],
            locale: Locale.current.languageCode ?? "en"
          )
        )
      }
    }
    
    let task = Task {
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
    notificationsUpdateTask[wallet] = task
  }
  
  private func unsubscribePushNotifications(wallet: Wallet) {
    let action: (String) -> Void = { [appSettings, pushNotificationAPI] token in
      Task {
        _ = try await pushNotificationAPI.unsubscribeNotifications(
          unsubscribeData: PushNotificationsAPI.UnsubscribeData(
            device: appSettings.installDeviceID,
            accounts: [PushNotificationsAPI.UnsubscribeData.Account(address: wallet.friendlyAddress.toString())]
          )
        )
      }
    }
    
    let task = Task {
      guard let token = await pushNotificationTokenProvider.getToken() else {
        await MainActor.run {
          deferedActions.append(action)
        }
        return
      }
      
      action(token)
    }
    notificationsUpdateTask[wallet] = task
  }
  
  private func performDefferedActions(token: String) {
    deferedActions.forEach {
      $0(token)
    }
  }
}
