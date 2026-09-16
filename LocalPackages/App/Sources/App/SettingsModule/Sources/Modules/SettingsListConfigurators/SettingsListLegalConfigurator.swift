import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

final class SettingsListLegalConfigurator: SettingsListConfigurator {
    var openUrl: ((URL) -> Void)?

    // MARK: - SettingsListConfigurator

    var didUpdateState: ((SettingsListState) -> Void)?

    var title: String {
        TKLocales.Settings.Legal.title
    }

    func getInitialState() -> SettingsListState {
        createState()
    }

    private func createState() -> SettingsListState {
        SettingsListState(sections: [createDocumentsSection()])
    }

    private func createDocumentsSection() -> SettingsListSection {
        .items(
            SettingsListItemsSection(
                items: [
                    .listItem(createTermsOfServiceItem()),
                    .listItem(createPrivacyPolicyItem()),
                ]
            )
        )
    }

    private func createTermsOfServiceItem() -> SettingsListItem {
        SettingsListItem(
            id: .termsOfServiceIdentifier,
            title: SettingsListItemTitle(TKLocales.Settings.Legal.Items.termsOfService),
            accessory: .chevron,
            onTap: { [weak self] _ in
                guard let url = InfoProvider.termsOfServiceURL() else { return }
                self?.openUrl?(url)
            }
        )
    }

    private func createPrivacyPolicyItem() -> SettingsListItem {
        SettingsListItem(
            id: .privacyPolicyIdentifier,
            title: SettingsListItemTitle(TKLocales.Settings.Legal.Items.privacyPolicy),
            accessory: .chevron,
            onTap: { [weak self] _ in
                guard let url = InfoProvider.privacyPolicyURL() else { return }
                self?.openUrl?(url)
            }
        )
    }
}

private extension String {
    static let termsOfServiceIdentifier = "termsOfServiceIdentifier"
    static let privacyPolicyIdentifier = "privacyPolicyIdentifier"
}
