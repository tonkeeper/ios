import Foundation
import TKUIKit
import SignerCore

protocol MainViewModel: AnyObject {
  var titleUpdate: ((NSAttributedString) -> Void)? { get set }
  var didUpdateButtons: ((MainHeaderButtonsView.Model) -> Void)? { get set }
  var itemsListUpdate: (([TKUIListItemCell.Configuration]) -> Void)? { get set }
  
  func viewDidLoad()
  func didSelectKeyItem(index: Int)
}

protocol MainModuleOutput: AnyObject {
  var didTapScanButton: (() -> Void)? { get set }
  var didTapAddWallet: (() -> Void)? { get set }
  var didTapSettings: (() -> Void)? { get set }
  var didSelectKey: ((WalletKey) -> Void)? { get set }
}

final class MainViewModelImlementation: MainViewModel, MainModuleOutput {
  
  // MARK: - MainModuleOutput
  
  var didTapScanButton: (() -> Void)?
  var didTapAddWallet: (() -> Void)?
  var didTapSettings: (() -> Void)?
  var didSelectKey: ((WalletKey) -> Void)?
  
  // MARK: - MainViewModel
  
  var titleUpdate: ((NSAttributedString) -> Void)?
  var didUpdateButtons: ((MainHeaderButtonsView.Model) -> Void)?
  var itemsListUpdate: (([TKUIListItemCell.Configuration]) -> Void)?
  
  func viewDidLoad() {
    listController.didUpdateKeys = { [weak self] walletKeys in
      guard let self else { return }
      self.walletKeys = walletKeys
    }
    
    didUpdateButtons?(createHeaderButtonsModel())
    
    titleUpdate?(createTitleString())
    
    listController.start()
  }
  
  func didSelectKeyItem(index: Int) {
    didSelectKey?(walletKeys[index])
  }
  
  // MARK: - State
  
  private var walletKeys = [WalletKey]() {
    didSet {
      didUpdateWalletKeys(walletKeys: walletKeys)
    }
  }
  
  private let listController: WalletKeysListController
  
  init(listController: WalletKeysListController) {
    self.listController = listController
  }
}

private extension MainViewModelImlementation {
  func createTitleString() -> NSAttributedString {
    let ton = "Signer".withTextStyle(.h3, color: .Text.primary)
    return ton
  }
  
  func didUpdateWalletKeys(walletKeys: [WalletKey]) {
    let items = walletKeys.map { key in
      let title = key.name.withTextStyle(
        .label1,
        color: .Text.primary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
      let subtitle = key.publicKeyShortHexString.withTextStyle(
        .body2,
        color: .Text.secondary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
      
      let listItemConfiguration = TKUIListItemView.Configuration(
        iconConfiguration: .init(iconConfiguration: .none, alignment: .center),
        contentConfiguration: TKUIListItemContentView.Configuration(
          leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
            title: title,
            tagViewModel: nil,
            subtitle: subtitle,
            description: nil
          ),
          rightItemConfiguration: nil
        ),
        accessoryConfiguration: .image(
          .init(
            image: .TKUIKit.Icons.Size16.chevronRight,
            tintColor: .Text.tertiary,
            padding: .zero
          )
        )
      )
      
      return TKUIListItemCell.Configuration(
        id: key.id,
        listItemConfiguration: listItemConfiguration,
        selectionClosure: nil)
    }
    itemsListUpdate?(items)
  }
  
  func createHeaderButtonsModel() -> MainHeaderButtonsView.Model {
    return MainHeaderButtonsView.Model(
      scanButton: MainHeaderButtonsView.Model.Button(
        title: "Scan",
        icon: .TKUIKit.Icons.Size28.qrViewFinderThin,
        isEnabled: true,
        action: { [weak self] in
          self?.didTapScanButton?()
        }
      ),
      addKeyButton: MainHeaderButtonsView.Model.Button(
        title: "Add Key",
        icon: .TKUIKit.Icons.Size28.plusThin,
        isEnabled: true,
        action: { [weak self] in
          self?.didTapAddWallet?()
        }
      ),
      settingsButton: MainHeaderButtonsView.Model.Button(
        title: "Settings",
        icon: .TKUIKit.Icons.Size28.gearOutline,
        isEnabled: true,
        action: { [weak self] in
          self?.didTapSettings?()
        }
      )
    )
  }
}
