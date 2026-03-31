import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

final class SettingsListConnectedAppsConfigurator: SettingsListConfigurator {
    var title: String {
        TKLocales.Settings.ConnectedApps.title
    }

    var didUpdateState: ((SettingsListState) -> Void)?

    var didRequestShowAlert: ((_ title: String, _ actions: [UIAlertAction]) -> Void)?

    private let connectedAppsStore: ConnectedAppsStore

    init(connectedAppsStore: ConnectedAppsStore) {
        self.connectedAppsStore = connectedAppsStore

        setupBindings()
    }

    private func setupBindings() {
        connectedAppsStore.addObserver(self) { observer, event in
            switch event {
            case .didUpdateApps:
                let apps = observer.connectedAppsStore.getState().unique
                observer.didUpdateState?(observer.composeState(apps: apps))
            }
        }
    }

    func getInitialState() -> SettingsListState {
        composeState(apps: connectedAppsStore.getState().unique)
    }

    private func composeState(apps: [TonConnectApp]) -> SettingsListState {
        guard !apps.isEmpty else {
            let caption = TKLocales.Settings.ConnectedApps.Empty.title
            let emptyModel = TKEmptyViewController.Model(title: nil, caption: caption, buttons: [])
            return SettingsListState(state: .empty(emptyModel), sections: [])
        }

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
        buttonConfiguration.action = { [weak self, apps, connectedAppsStore] in
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
                apps.forEach { connectedAppsStore.deleteApp($0) }
            }

            self?.didRequestShowAlert?(title, [cancelAction, disconnectAction])
        }
        let cellConfiguration = TKButtonCollectionViewCell.Configuration(
            buttonConfiguration: buttonConfiguration
        )
        return .button(
            SettingsButtonListItem(
                id: UUID().uuidString,
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
            ) { [weak self, app, connectedAppsStore] in
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
                    connectedAppsStore.deleteApp(app)
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
                items: items.map(SettingsListItemsSectionItem.listItem)
            )
        )
    }
}
