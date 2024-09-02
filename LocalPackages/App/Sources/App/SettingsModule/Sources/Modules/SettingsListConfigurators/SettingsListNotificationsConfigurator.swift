import UIKit
import TKUIKit
import TKCore
import TKLocalize
import KeeperCore
import UserNotifications

final class SettingsListNotificationsConfigurator: SettingsListConfigurator {
  // MARK: - SettingsListV2Configurator
  
  var didUpdateState: ((SettingsListState) -> Void)?
  var didShowPopupMenu: (([TKPopupMenuItem], Int?) -> Void)?
  
  var title: String { TKLocales.Settings.Notifications.title }
  var isSelectable: Bool { false }
  
  func getInitialState() -> SettingsListState {
    updateIsPushAvaiable()
    return createState()
  }
  
  // MARK: - State
  
  private var isPushAvailable = true {
    didSet {
      didUpdateIsPushAvailable()
    }
  }
  
  private var notificationToken: NSObjectProtocol?
  
  // MARK: - Dependencies
  
  private let wallet: Wallet
  private let walletNotificationStore: WalletNotificationStore
  private let urlOpener: URLOpener
  
  // MARK: - Init
  init(wallet: Wallet,
       walletNotificationStore: WalletNotificationStore,
       urlOpener: URLOpener) {
    self.wallet = wallet
    self.walletNotificationStore = walletNotificationStore
    self.urlOpener = urlOpener
    
    notificationToken = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main, using: { [weak self] _ in
      self?.updateIsPushAvaiable()
    })
  }
  
  deinit {
    notificationToken = nil
  }
  
  private func createState() -> SettingsListState {
    var sections = [SettingsListSection]()
    if !isPushAvailable {
      sections.append(createNotificationsNotAvailableSection())
    }
    sections.append(createPushNotificationsSection())
    return SettingsListState(sections: sections)
  }
  
  private func didUpdateIsPushAvailable() {
    let state = createState()
    didUpdateState?(state)
  }
  
  private func createPushNotificationsSection() -> SettingsListSection {
    let items = [createPushNotificationsItem()]
    return SettingsListSection.listItems(SettingsListItemsSection(
      items: items,
      topPadding: 0,
      bottomPadding: 16
    ))
  }
  
  private func createNotificationsNotAvailableSection() -> SettingsListSection {
    let items = [createNotificationsNotAvailableItem()]
    return SettingsListSection.listItems(SettingsListItemsSection(
      items: items,
      topPadding: 0,
      bottomPadding: 16
    ))
  }
  
  private func createPushNotificationsItem() -> SettingsListItem {
    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentViewV2.Configuration(
        textContentViewConfiguration: TKListItemTextContentViewV2.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(
            title: TKLocales.Settings.Notifications.NotificationsItem.title
          ),
          captionViewsConfigurations: [
            TKListItemTextView.Configuration(
              text: TKLocales.Settings.Notifications.NotificationsItem.caption,
              color: .Text.secondary,
              textStyle: .body2,
              numberOfLines: 0
            )
          ]
        )
      )
    )
    
    let isOn: Bool = {
      guard let address = try? wallet.friendlyAddress else { return false }
      guard let isOn = walletNotificationStore.getState()[address] else { return false }
      return isOn
    }()
    
    let action: (Bool) -> Void = { [weak self] isOn in
      guard let self else { return }
      
      Task {
        await self.walletNotificationStore.setNotificationIsOn(isOn, wallet: self.wallet)
      }
    }
    
    return SettingsListItem(
      id: .walletNotificationsIdentifier,
      cellConfiguration: cellConfiguration,
      accessory: .switch(
        TKListItemSwitchAccessoryView.Configuration(
          isOn: isOn,
          isEnable: isPushAvailable,
          action: action
        )
      ),
      onSelection: { _ in
        action(!isOn)
      }
    )
  }
  
  private func createNotificationsNotAvailableItem() -> SettingsNotificationBannerListItem {
    SettingsNotificationBannerListItem(
      id: .notificationsNotAvailableBannerIdentifier,
      cellConfiguration: NotificationBannerCell.Configuration(
        bannerViewConfiguration: NotificationBannerView.Model(
          title: "Notifications are disabled",
          caption: "You turned off notifications in your phone’s settings. To activate notifications, go to Settings on this device.",
          appearance: .accentYellow,
          actionButton: NotificationBannerView.Model.ActionButton(
            title: "Settings",
            action: { [urlOpener] in
              guard let url = URL(string: UIApplication.openSettingsURLString),
                    urlOpener.canOpen(url: url) else {
                return
              }
              urlOpener.open(url: url)
            }
          ),
          closeButton: nil
        )
      )
    )
  }
  
  private func updateIsPushAvaiable() {
    Task {
      let center = UNUserNotificationCenter.current()
      let isPushAvailable: Bool
      switch await center.notificationSettings().authorizationStatus {
      case .authorized: isPushAvailable = true
      case .denied: isPushAvailable = false
      case .ephemeral: isPushAvailable = false
      case .notDetermined: isPushAvailable = true
      case .provisional: isPushAvailable = false
      @unknown default:
        isPushAvailable = false
      }
      await MainActor.run {
        self.isPushAvailable = isPushAvailable
      }
    }
  }
}

private extension String {
  static let walletNotificationsIdentifier = "WalletNotificationsIdentifier"
  static let notificationsNotAvailableBannerIdentifier = "NotificationsNotAvailableBannerIdentifier"
}
