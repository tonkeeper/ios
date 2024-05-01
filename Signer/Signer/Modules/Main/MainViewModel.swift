import Foundation
import TKUIKit
import SignerCore

class MainListKeyItem: Identifiable, Hashable {
  let id: String
  let model: AccessoryListItemView<TwoLinesListItemView>.Model
  
  init(id: String, model: AccessoryListItemView<TwoLinesListItemView>.Model) {
    self.id = id
    self.model = model
  }
  
  static func ==(lhs: MainListKeyItem, rhs: MainListKeyItem) -> Bool {
    lhs.id == rhs.id
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

protocol MainViewModel: AnyObject {
  var titleUpdate: ((NSAttributedString) -> Void)? { get set }
  var buttonsBarModelUpdate: ((MainViewButtonsBarView.Model) -> Void)? { get set }
  var itemsListUpdate: (([MainListKeyItem]) -> Void)? { get set }
  
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
  var buttonsBarModelUpdate: ((MainViewButtonsBarView.Model) -> Void)?
  var itemsListUpdate: (([MainListKeyItem]) -> Void)?
  
  func viewDidLoad() {
    listController.didUpdateKeys = { [weak self] walletKeys in
      guard let self else { return }
      self.walletKeys = walletKeys
    }
    
    buttonsBarModelUpdate?(.init(buttons: createButtonsModels()))
    
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
  
  func createButtonsModels() -> [TKFlatButtonControl<TKFlatButtonTitleIconContent>.Model] {
    let scanButtonModel = TKFlatButtonControl<TKFlatButtonTitleIconContent>.Model(
      contentModel: TKFlatButtonTitleIconContent.Model(
        title: "Scan",
        image: .TKUIKit.Icons.Button.Flat.scan
      ),
      action: { [weak self] in
        self?.didTapScanButton?()
      }
    )
    let addButtonModel = TKFlatButtonControl<TKFlatButtonTitleIconContent>.Model(
      contentModel: TKFlatButtonTitleIconContent.Model(
        title: "Add Key",
        image: .TKUIKit.Icons.Button.Flat.add
      ),
      action: { [weak self] in
        self?.didTapAddWallet?()
      }
    )
    let settingsButtonModel = TKFlatButtonControl<TKFlatButtonTitleIconContent>.Model(
      contentModel: TKFlatButtonTitleIconContent.Model(
        title: "Settings",
        image: .TKUIKit.Icons.Button.Flat.settings
      ),
      action: { [weak self] in
        self?.didTapSettings?()
      }
    )
    return [scanButtonModel, addButtonModel, settingsButtonModel]
  }
  
  func didUpdateWalletKeys(walletKeys: [WalletKey]) {
    let items = walletKeys.map { key in
      MainListKeyItem(
        id: key.id,
        model: AccessoryListItemView<TwoLinesListItemView>.Model(
          contentViewModel: TwoLinesListItemView.Model(title: key.name,
                                                       subtitle: key.publicKeyShortHexString),
          accessoryModel: .disclosure
        )
      )
    }
    itemsListUpdate?(items)
  }
}
