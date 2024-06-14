import UIKit
import TKUIKit
import TKCore
import KeeperCore
import TKLocalize

final class SettingsSecurityListItemsProvider: SettingsListItemsProvider {
  
  var didRequirePasscode: (() async -> String?)?
  var didTapChangePasscode: (() -> Void)?
  
  private let securityStore: SecurityStore
  private let mnemonicsRepository: MnemonicsRepository
  private let biometryProvider: BiometryProvider

  init(securityStore: SecurityStore,
       mnemonicsRepository: MnemonicsRepository,
       biometryProvider: BiometryProvider) {
    self.securityStore = securityStore
    self.mnemonicsRepository = mnemonicsRepository
    self.biometryProvider = biometryProvider
    
    Task {
      await securityStore.addEventObserver(self) { observer, event in
        observer.didUpdateSections?()
      }
    }
  }
  
  var didUpdateSections: (() -> Void)?
  
  var title: String { .title }
  
  func getSections() async -> [SettingsListSection] {
    await setupSettingsSections()
  }
  
  func cell(collectionView: UICollectionView, indexPath: IndexPath, itemIdentifier: AnyHashable) -> UICollectionViewCell? {
    nil
  }
  
  func selectItem(section: SettingsListSection, index: Int) {}
}

private extension SettingsSecurityListItemsProvider {
  func setupSettingsSections() async -> [SettingsListSection] {
    [
      await createBiometrySection(),
      createBiometryDescriptionSection(),
      createPasscodeSection()
    ]
  }
  
  func createBiometrySection() async -> SettingsListSection {
    let isEnable: Bool
    let isOn: Bool
    let title: String
    
    switch biometryProvider.getBiometryState(policy: .deviceOwnerAuthenticationWithBiometrics) {
    case .success(let state):
      switch state {
      case .none:
        title = .biometryUnavailable
        isEnable = false
        isOn = false
      case .faceID:
        title = TKLocales.Security.use(String.faceId)
        isEnable = true
        isOn = await securityStore.isBiometryEnabled
      case .touchID:
        title = TKLocales.Security.use(String.touchId)
        isEnable = true
        isOn = await securityStore.isBiometryEnabled
      }
    case .failure:
      title = .biometryUnavailable
      isEnable = false
      isOn = false
    }
    
    let switchModel: TKListItemSwitchView.Model = {
      return TKListItemSwitchView.Model(
        isOn: isOn,
        isEnabled: isEnable,
        action: { [weak self] isOn in
          guard let self else { return !isOn }
          return await Task { @MainActor in
            do {
              if isOn {
                guard let passcode = await self.didRequirePasscode?() else {
                  return !isOn
                }
                try self.mnemonicsRepository.savePassword(passcode)
                try await self.securityStore.setIsBiometryEnabled(true)
              } else {
                try self.mnemonicsRepository.deletePassword()
                try await self.securityStore.setIsBiometryEnabled(false)
              }
              return isOn
            } catch {
              return !isOn
            }
          }.value
        }
      )
    }()
    
    return SettingsListSection(
      padding: NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 0, trailing: 16),
      items: [
        SettingsCell.Model(
          identifier: "biometry",
          isHighlightable: false,
          cellContentModel: SettingsCellContentView.Model(
            title: title,
            switchValue: switchModel
          )
        )
      ]
    )
  }
  
  func createBiometryDescriptionSection() -> SettingsListSection {
    SettingsListSection(
      padding: NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 16, trailing: 16),
      items: [
        SettingsTextCell.Model(
          id: "biometry_description",
          padding: .zero,
          text: String.biometryDescription.withTextStyle(
            .body2,
            color: .Text.secondary,
            alignment: .left,
            lineBreakMode: .byWordWrapping
          ),
          numberOfLines: 0
        )
      ]
    )
  }
  
  func createPasscodeSection() -> SettingsListSection {
    SettingsListSection(
      padding: NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
      items: [
        SettingsCell.Model(
          identifier: "change_passcode",
          selectionHandler: { [weak self] in
            self?.didTapChangePasscode?()
          },
          cellContentModel: SettingsCellContentView.Model(
            title: .changePasscodeTitle,
            icon: .TKUIKit.Icons.Size28.lock,
            tintColor: .Accent.blue
          )
        )
      ]
    )
  }
}

private extension String {
  static let title = TKLocales.Security.title
  static let use = TKLocales.Security.use
  static let faceId = "Face ID"
  static let touchId = "Touch ID"
  static let biometryUnavailable = TKLocales.Security.unavailable_error
  static let biometryDescription = TKLocales.Security.use_biometry_description
  
  static let changePasscodeTitle = TKLocales.Security.change_passcode
}
