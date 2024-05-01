import Foundation
import UIKit
import TKUIKit
import SignerCore

protocol KeyDetailsViewModel: AnyObject {
  var titleUpdate: ((String) -> Void)? { get set }
  var itemsListUpdate: (([KeyDetailsListSection]) -> Void)? { get set }
  var didSelectDelete: (() -> Void)? { get set }
  var didOpenUrl: ((URL) -> Void)? { get set }
  var didCopied: (() -> Void)? { get set }
  
  func viewDidLoad()
  func didConfirmDelete()
}

protocol KeyDetailsModuleOutput: AnyObject {
  var didTapEdit: (() -> Void)? { get set }
  var didTapOpenRecoveryPhrase: (() -> Void)? { get set }
  var didDeleteKey: (() -> Void)? { get set }
}

final class KeyDetailsViewModelImplementation: KeyDetailsViewModel, KeyDetailsModuleOutput {

  // MARK: - KeyDetailsModuleOutput
  
  var didTapEdit: (() -> Void)?
  var didTapOpenRecoveryPhrase: (() -> Void)?
  var didDeleteKey: (() -> Void)?
  var didOpenUrl: ((URL) -> Void)?
  var didCopied: (() -> Void)?
  
  // MARK: - KeyDetailsViewModel
  
  var titleUpdate: ((String) -> Void)?
  var itemsListUpdate: (([KeyDetailsListSection]) -> Void)?
  var didSelectDelete: (() -> Void)?
  
  func viewDidLoad() {
    keyDetailsController.didUpdateWalletKey = { [weak self] walletKey in
      guard let self else { return }
      self.titleUpdate?(walletKey.name)
      itemsListUpdate?(createListSections())
    }
    keyDetailsController.start()
  }
  
  func didConfirmDelete() {
    do {
      try keyDetailsController.deleteKey()
      didDeleteKey?()
    } catch {}
  }
  
  // MARK: - State
  
  private var qrCodeImage: UIImage?
  
  // MARK: - Dependencies
  
  private let keyDetailsController: WalletKeyDetailsController
  
  // MARK: - Init
  
  init(keyDetailsController: WalletKeyDetailsController) {
    self.keyDetailsController = keyDetailsController
  }
}

private extension KeyDetailsViewModelImplementation {
  func createListSections() -> [KeyDetailsListSection] {
    return [
      createAnotherDeviceExportSection(),
      createSameDeviceExportSection(),
      createActionSection(),
      createDeleteSection()
    ]
  }
  
  func createAnotherDeviceExportSection() -> KeyDetailsListSection {
    let items = [
      KeyDetailsListKeyItem(
        id: UUID().uuidString,
        model: TwoLinesListItemView.Model(
          title: "Export to another device",
          subtitle: "Open Tonkeeper » Import Existing Wallet » Pair Tonsign"
        ),
        isHighlightable: false
      ),
      KeyDetailsListKeyItem(
        id: UUID().uuidString,
        model: KeyDetailsQRCodeItemView.Model(url: keyDetailsController.exportDeeplinkUrl()),
        isHighlightable: false
      )
    ]
    return .anotherDeviceExport(items)
  }
  
  func createSameDeviceExportSection() -> KeyDetailsListSection {
      let items = [
        KeyDetailsListKeyItem(
          id: UUID().uuidString,
          model: AccessoryListItemView<TwoLinesListItemView>.Model(
            contentViewModel: TwoLinesListItemView.Model(
              title: "Export to Tonkeeper on this device",
              subtitle: "Tonkeeper must be installed"
            ),
            accessoryModel: .disclosure),
          action: { [weak self] in
            self?.sameDeviceExportAction()
          }
        )
      ]
    return .sameDeviceExport(items)
  }
  
  func createActionSection() -> KeyDetailsListSection {
    let items = [
      KeyDetailsListKeyItem(
        id: UUID().uuidString,
        model: AccessoryListItemView<TwoLinesListItemView>.Model(
          contentViewModel: TwoLinesListItemView.Model(
            title: "Name",
            subtitle: keyDetailsController.walletKey.name
          ),
          accessoryModel: .icon(.TKUIKit.Icons.List.Accessory.edit, .Accent.blue)),
        action: { [weak self] in
          self?.didTapEdit?()
        }
      ),
      KeyDetailsListKeyItem(
        id: UUID().uuidString,
        model: AccessoryListItemView<TwoLinesListItemView>.Model(
          contentViewModel: TwoLinesListItemView.Model(
            title: "Hex Address",
            subtitle: keyDetailsController.walletKey.publicKeyShortHexString
          ),
          accessoryModel: .icon(.TKUIKit.Icons.List.Accessory.copy, .Accent.blue)),
        action: { [weak self] in
          guard let self = self else { return }
          UIPasteboard.general.string = self.keyDetailsController.walletKey.publicKeyHexString
          self.didCopied?()
        }
      ),
      KeyDetailsListKeyItem(
        id: UUID().uuidString,
        model: AccessoryListItemView<TwoLinesListItemView>.Model(
          contentViewModel: TwoLinesListItemView.Model(
            title: "Recovery Phrase"
          ),
          accessoryModel: .icon(.TKUIKit.Icons.List.Accessory.key, .Accent.blue)),
        action: { [weak self] in
          self?.didTapOpenRecoveryPhrase?()
        }
      )
    ]
    return .actions(items)
  }
  
  func createDeleteSection() -> KeyDetailsListSection {
    let items = [
      KeyDetailsListKeyItem(
        id: UUID().uuidString,
        model: AccessoryListItemView<TwoLinesListItemView>.Model(
          contentViewModel: TwoLinesListItemView.Model(
            title: "Delete Key"
          ),
          accessoryModel: .icon(.TKUIKit.Icons.List.Accessory.delete, .Accent.blue)),
        action: { [weak self] in
          self?.didSelectDelete?()
        }
      )
    ]
    return .actions(items)
  }
  
  private func sameDeviceExportAction() {
    guard let url = keyDetailsController.exportDeeplinkUrl() else { return }
    didOpenUrl?(url)
  }
}
