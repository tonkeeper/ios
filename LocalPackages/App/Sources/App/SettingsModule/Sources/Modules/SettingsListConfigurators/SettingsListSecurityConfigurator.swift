import UIKit
import TKUIKit
import KeeperCore
import TKLocalize

final class SettingsListSecurityConfigurator: SettingsListV2Configurator {
  
  var didRequirePasscode: (() async -> String?)?
  var didTapChangePasscode: (() -> Void)?
  
  // MARK: - SettingsListV2Configurator
  
  var didUpdateState: ((SettingsListV2State) -> Void)?
  var didShowPopupMenu: (([TKPopupMenuItem], Int?) -> Void)?
  
  var title: String { TKLocales.Security.title }
  var isSelectable: Bool { false }
  
  func getState() -> SettingsListV2State {
    createState()
  }
  
  // MARK: - Dependencies
 
  private let securityStore: SecurityStoreV2
  private let mnemonicsRepository: MnemonicsRepository
  private let biometryProvider: BiometryProvider
  
  // MARK: - Init
  
  init(securityStore: SecurityStoreV2,
       mnemonicsRepository: MnemonicsRepository,
       biometryProvider: BiometryProvider) {
    self.securityStore = securityStore
    self.mnemonicsRepository = mnemonicsRepository
    self.biometryProvider = biometryProvider
  }
}

private extension SettingsListSecurityConfigurator {
  func createState() -> SettingsListV2State {
    var sections = [SettingsListV2Section]()
    
    sections.append(createBiometrySection())
    sections.append(createLockscreenSection())
    sections.append(createChangePasscodeSection())
    
    return SettingsListV2State(
      sections: sections,
      selectedItem: nil
    )
  }
  
  func createBiometrySection() -> SettingsListV2Section {
    var items = [AnyHashable]()
    
    let biometryItem: TKUIListItemCell.Configuration = {
      let state = biometryProvider
        .getBiometryState(policy: .deviceOwnerAuthenticationWithBiometrics)
      let isEnable: Bool
      let isOn: Bool
      let title: String
      switch state {
      case .success(let state):
        switch state {
        case .none:
          title = TKLocales.Security.unavailable_error
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
        title = TKLocales.Security.unavailable_error
        isEnable = false
        isOn = false
      }
      
      let action: (Bool) async -> Bool = {[weak self] isOn in
        guard let self else { return !isOn }
        return await Task { @MainActor in
          do {
            if isOn {
              guard let passcode = await self.didRequirePasscode?() else {
                return !isOn
              }
              try self.mnemonicsRepository.savePassword(passcode)
              await self.securityStore.setIsBiometryEnable(true)
            } else {
              try self.mnemonicsRepository.deletePassword()
              await self.securityStore.setIsBiometryEnable(false)
            }
            return isOn
          } catch {
            return !isOn
          }
        }.value
      }
      
      return TKUIListItemCell.Configuration.createSettingsItem(
        id: .biometryItemIdentifier,
        title: .string(
          title
        ),
        accessory: .switchControl(
          isOn: isOn,
          isEnable: isEnable,
          action: action
        ),
        selectionClosure: nil
      )
    }()
    
    items.append(biometryItem)
    
    return SettingsListV2Section.items(
      topPadding: 16,
      items: items,
      bottomDescription: SettingsTextDescriptionView.Model(
        padding: UIEdgeInsets(top: 12, left: 1, bottom: 0, right: 1),
        text: TKLocales.Security.use_biometry_description
      )
    )
  }
  
  func createChangePasscodeSection() -> SettingsListV2Section {
    let items = [
      TKUIListItemCell.Configuration.createSettingsItem(
        id: .changePasscodeItemIdentifier,
        title: .string(TKLocales.Security.change_passcode),
        accessory: .icon(.TKUIKit.Icons.Size28.lock, .Accent.blue),
        selectionClosure: { [didTapChangePasscode] in
          didTapChangePasscode?()
        }
      )
    ]
    
    return SettingsListV2Section.items(
      topPadding: 16,
      items: items
    )
  }
  
  func createLockscreenSection() -> SettingsListV2Section {
    var items = [AnyHashable]()
    
    let biometryItem: TKUIListItemCell.Configuration = {
      let action: (Bool) async -> Bool = { [weak self] isOn in
        await self?.securityStore.setIsLockScreen(isOn)
        return true
      }
      
      return TKUIListItemCell.Configuration.createSettingsItem(
        id: .biometryItemIdentifier,
        title: .string(
          TKLocales.Security.lock_screen
        ),
        accessory: .switchControl(
          isOn: securityStore.getState().isLockScreen,
          isEnable: true,
          action: action
        ),
        selectionClosure: nil
      )
    }()
    
    items.append(biometryItem)
    
    return SettingsListV2Section.items(
      topPadding: 16,
      items: items,
      bottomDescription: SettingsTextDescriptionView.Model(
        padding: UIEdgeInsets(top: 12, left: 1, bottom: 0, right: 1),
        text: TKLocales.Security.lock_screen_description
      )
    )
  }
}

private extension String {
  static let biometryItemIdentifier = "BiometryItem"
  static let locksreenItemIdentifier = "LockScreenItem"
  static let changePasscodeItemIdentifier = "ChangePasscodeItem"
}

private extension String {
  static let faceId = "Face ID"
  static let touchId = "Touch ID"
}

