import UIKit
import TKUIKit
import TKLocalize
import TKCore
import KeeperCore

final class SettingsListConnectedAppsConfigurator: SettingsListConfigurator {

  var title: String {
    TKLocales.Settings.ConnectedApps.title
  }

  var didUpdateState: ((SettingsListState) -> Void)?

  var didRequestShowAlert: ((_ title: String, _ actions: [UIAlertAction]) -> Void)?

  private let connectedAppsController: BrowserConnectedController

  private var connectedApps: [TonConnectApp] {
    connectedAppsController.getConnectedApps()
  }

  init(connectedController: BrowserConnectedController) {
    self.connectedAppsController = connectedController

    setupBindings()
  }

  private func setupBindings() {
    connectedAppsController.didUpdateApps = { [weak self] in
      guard let self else {
        return
      }

      self.didUpdateState?(composeState(apps: self.connectedApps))
    }
  }

  func getInitialState() -> SettingsListState { composeState(apps: connectedApps) }

  private func composeState(apps: [TonConnectApp]) -> SettingsListState {
    var sections = [SettingsListSection]()
    if let buttonSection = createDisconnectAllAppsButton(apps: apps) {
      sections.append(buttonSection)
    }
    sections.append(createConnectedAppsSection(apps: apps))
    return SettingsListState(sections: sections)
  }

  private func createDisconnectAllAppsButton(apps: [TonConnectApp]) -> SettingsListSection? {
    guard apps.count > 1 else { return nil }

    var buttonConfiguration: TKButton.Configuration = .actionButtonConfiguration(category: .secondary, size: .large)
    buttonConfiguration.content = .init(title: .plainString(TKLocales.Settings.ConnectedApps.disconnectAllApps))
    buttonConfiguration.action = { [weak self, apps, connectedAppsController] in
      let title = TKLocales.Settings.ConnectedApps.disconnectAllTitle
      let cancelAction = UIAlertAction(
        title: TKLocales.Settings.ConnectedApps.Actions.cancel,
        style: .cancel,
        handler: nil
      )
      let disconnectAction = UIAlertAction(
        title: TKLocales.Settings.ConnectedApps.Actions.disconnect,
        style: .destructive
      ) { _ in
        apps.forEach { connectedAppsController.deleteApp($0) }
      }

      self?.didRequestShowAlert?(title, [cancelAction, disconnectAction])
    }
    let cellConfiguration = TKButtonCollectionViewCell.Configuration(
      buttonConfiguration: buttonConfiguration
    )
    return .button(
      SettingsButtonListItem(
        id: "disconnectAllAppsButton",
        cellConfiguration: cellConfiguration
      )
    )
  }

  private func createConnectedAppsSection(apps: [TonConnectApp]) -> SettingsListSection {
    let items = apps.compactMap { app in
      let size = CGSize(width: 44, height: 44)
      let imageModel = TKImageView.Model(image: .urlImage(app.manifest.iconUrl), size: .size(size))
      let iconViewConfiguration = TKListItemIconView.Configuration(
        content: .image(imageModel),
        alignment: .center,
        cornerRadius: 12,
        backgroundColor: .clear,
        size: size
      )
      let captionViewConfigurations = TKListItemTextView.Configuration(
        text: app.manifest.host,
        color: .Text.secondary,
        textStyle: .body2
      )
      let textContentViewConfiguration = TKListItemTextContentView.Configuration(
        titleViewConfiguration: TKListItemTitleView.Configuration(title: app.manifest.name),
        captionViewsConfigurations: [captionViewConfigurations]
      )
      let listItemConfiguration = TKListItemContentView.Configuration(
        iconViewConfiguration: iconViewConfiguration,
        textContentViewConfiguration: textContentViewConfiguration
      )
      let cellConfiguration = TKListItemCell.Configuration(listItemContentViewConfiguration: listItemConfiguration)
      let buttonConfiguration = TKListItemButtonAccessoryView.Configuration(
        title: TKLocales.Settings.ConnectedApps.disconnect,
        category: .tertiary
      ) { [weak self, app, connectedAppsController] in
        let title = TKLocales.Settings.ConnectedApps.disconnectItemTitle(app.manifest.name)
        let cancelAction = UIAlertAction(
          title: TKLocales.Settings.ConnectedApps.Actions.cancel,
          style: .cancel,
          handler: nil
        )
        let disconnectAction = UIAlertAction(
          title: TKLocales.Settings.ConnectedApps.Actions.disconnect,
          style: .destructive
        ) { _ in
          connectedAppsController.deleteApp(app)
        }

        self?.didRequestShowAlert?(title, [cancelAction, disconnectAction])
      }
      return SettingsListItem(
        id: UUID().uuidString,
        cellConfiguration: cellConfiguration,
        accessory: .button(buttonConfiguration),
        onSelection: nil
      )
    }
    
    return .listItems(
      SettingsListItemsSection(
        items: items,
        topPadding: 16,
        bottomPadding: 0
      )
    )
  }
}
