import UIKit
import TKUIKit
import KeeperCore
import TKLocalize

final class SettingsListSecurityConfigurator: SettingsListConfigurator {
  
  var didRequirePasscode: (() async -> String?)?
  var didTapChangePasscode: (() -> Void)?
  
  // MARK: - SettingsListV2Configurator
  
  var didUpdateState: ((SettingsListState) -> Void)?
  var didShowPopupMenu: (([TKPopupMenuItem], Int?) -> Void)?
  
  var title: String { TKLocales.Security.title }
  var isSelectable: Bool { false }
  
  func getInitialState() -> SettingsListState {
    createState()
  }
  
  // MARK: - Dependencies
 
  private let securityStore: SecurityStore
  private let mnemonicsRepository: MnemonicsRepository
  private let biometryProvider: BiometryProvider
  
  // MARK: - Init
  
  init(securityStore: SecurityStore,
       mnemonicsRepository: MnemonicsRepository,
       biometryProvider: BiometryProvider) {
    self.securityStore = securityStore
    self.mnemonicsRepository = mnemonicsRepository
    self.biometryProvider = biometryProvider
    
    securityStore.addObserver(self) { observer, event in
      switch event {
      case .didUpdateIsBiometryEnabled, .didUpdateIsLockScreen:
        DispatchQueue.main.async {
          let state = observer.createState()
          observer.didUpdateState?(state)
        }
      }
    }
  }
  
  private func createState() -> SettingsListState {
    let sections = [
      createBiometrySection(),
      createLockscreenSection(),
      createChangePasscodeSection()
    ]
    
    return SettingsListState(
      sections: sections
    )
  }
  
  private func createBiometrySection() -> SettingsListSection {
    let items = [createBiometryItem()]
    return SettingsListSection.listItems(SettingsListItemsSection(
      items: items,
      topPadding: 0,
      bottomPadding: 0,
      footerConfiguration: SettingsListSectionFooterView.Configuration(text: TKLocales.Security.useBiometryDescription)
    ))
  }
  
  private func createLockscreenSection() -> SettingsListSection {
    let items = [createLockScreenItem()]
    return SettingsListSection.listItems(SettingsListItemsSection(
      items: items,
      topPadding: 16,
      bottomPadding: 0,
      footerConfiguration: SettingsListSectionFooterView.Configuration(text: TKLocales.Security.lockScreenDescription)
    ))
  }
  
  private func createChangePasscodeSection() -> SettingsListSection {
    let items = [createChangePasscodeItem()]
    return SettingsListSection.listItems(SettingsListItemsSection(
      items: items,
      topPadding: 16,
      bottomPadding: 16
    ))
  }
  
  private func createBiometryItem() -> SettingsListItem {
    let state = biometryProvider
      .getBiometryState(policy: .deviceOwnerAuthenticationWithBiometrics)
    let isOn: Bool
    let isEnable: Bool
    let title: String
    switch state {
    case .success(let state):
      switch state {
      case .none:
        title = TKLocales.Security.unavailableError
        isEnable = false
        isOn = false
      case .faceID:
        title = TKLocales.Security.use(String.faceId)
        isEnable = true
        isOn = securityStore.getState().isBiometryEnable
      case .touchID:
        title = TKLocales.Security.use(String.touchId)
        isEnable = true
        isOn = securityStore.getState().isBiometryEnable
      }
    case .failure:
      title = TKLocales.Security.unavailableError
      isEnable = false
      isOn = false
    }

    let action: (Bool) -> Void = { [weak self] isOn in
      guard let self else { return }
      Task {
        do {
          if isOn {
            guard let passcode = await self.didRequirePasscode?() else {
              await MainActor.run {
                let state = self.createState()
                self.didUpdateState?(state)
              }
              return
            }
            try self.mnemonicsRepository.savePassword(passcode)
            await self.securityStore.setIsBiometryEnable(true)
          } else {
            try self.mnemonicsRepository.deletePassword()
            await self.securityStore.setIsBiometryEnable(false)
          }
        } catch {
          await MainActor.run {
            let state = self.createState()
            self.didUpdateState?(state)
          }
        }
      }
    }
    
    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(
            title: title
          )
        )
      )
    )
    
    return SettingsListItem(
      id: .biometryItemIdentifier,
      cellConfiguration: cellConfiguration,
      accessory: .switch(
        TKListItemSwitchAccessoryView.Configuration(
          isOn: isOn,
          isEnable: isEnable,
          action: action
        )
      ),
      onSelection: {
        _ in
        action(!isOn)
      }
    )
  }
  
  private func createLockScreenItem() -> SettingsListItem {

    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(
            title: TKLocales.Security.lockScreen
          )
        )
      )
    )
    
    return SettingsListItem(
      id: .locksreenItemIdentifier,
      cellConfiguration: cellConfiguration,
      accessory: .switch(
        TKListItemSwitchAccessoryView.Configuration(
          isOn: securityStore.getState().isLockScreen,
          isEnable: true,
          action: { _ in
            
          }
        )
      ),
      onSelection: { _ in
      }
    )
  }
  
  private func createChangePasscodeItem() -> SettingsListItem {

    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(
            title: TKLocales.Security.changePasscode
          )
        )
      )
    )
    
    return SettingsListItem(
      id: .changePasscodeItemIdentifier,
      cellConfiguration: cellConfiguration,
      accessory: .icon(TKListItemIconAccessoryView.Configuration(icon: .TKUIKit.Icons.Size28.lock, tintColor: .Accent.blue)),
      onSelection: { [weak self] _ in
        self?.didTapChangePasscode?()
      }
    )
  }
}
private extension String {
  static let biometryItemIdentifier = "BiometryItem"
  static let locksreenItemIdentifier = "LockScreenItem"
  static let changePasscodeItemIdentifier = "ChangePasscodeItem"
}

private extension String {
  static let faceId = TKLocales.SettingsListSecurityConfigurator.faceId
  static let touchId = TKLocales.SettingsListSecurityConfigurator.touchId
}

