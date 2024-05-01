import Foundation
import TKUIKit
import TKCore
import KeeperCore
import TKLocalize

public protocol ChooseWalletToAddModuleOutput: AnyObject {
  var didSelectRevisions: (([WalletContractVersion]) -> Void)? { get set }
}

protocol ChooseWalletToAddViewModel: AnyObject {
  var didUpdateModel: ((ChooseWalletToAddView.Model) -> Void)? { get set }
  var didUpdateTitleDescriptionModel: ((TKTitleDescriptionView.Model) -> Void)? { get set }
  var didUpdateList: (([ChooseWalletToAddCollectionController.Section]) -> Void)? { get set }
  var didSelectItems: (([IndexPath]) -> Void)? { get set }
  
  func viewDidLoad()
  func select(at indexPath: IndexPath)
  func deselect(at indexPath: IndexPath)
}

final class ChooseWalletToAddViewModelImplementation: ChooseWalletToAddViewModel, ChooseWalletToAddModuleOutput {
  
  // MARK: - ChooseWalletToAddModuleOutput
  
  var didSelectRevisions: (([WalletContractVersion]) -> Void)?
  
  // MARK: - ChooseWalletToAddViewModel
  
  var didUpdateModel: ((ChooseWalletToAddView.Model) -> Void)?
  var didUpdateTitleDescriptionModel: ((TKTitleDescriptionView.Model) -> Void)?
  var didUpdateList: (([ChooseWalletToAddCollectionController.Section]) -> Void)?
  var didSelectItems: (([IndexPath]) -> Void)?
  
  func viewDidLoad() {
    let models = controller.models
    setSelectedIndexes(models: models)
    
    didUpdateModel?(createModel())
    didUpdateTitleDescriptionModel?(createTitleDescriptionModel())
    didUpdateList?([createListSection(models: models)])
    didSelectItems?(selectedIndexes.map { IndexPath(item: $0, section: 0) })
  }
  
  private var selectedIndexes = Set<Int>()
  
  private let controller: ChooseWalletsController
  
  init(controller: ChooseWalletsController) {
    self.controller = controller
  }
  
  func select(at indexPath: IndexPath) {
    selectedIndexes.insert(indexPath.item)
    didUpdateModel?(createModel())
  }
  
  func deselect(at indexPath: IndexPath) {
    selectedIndexes.remove(indexPath.item)
    didUpdateModel?(createModel())
  }
}

private extension ChooseWalletToAddViewModelImplementation {
  func createModel() -> ChooseWalletToAddView.Model {
    ChooseWalletToAddView.Model(
      continueButtonModel: TKUIActionButton.Model(title: TKLocales.Actions.continue_action),
      continueButtonAction: { [weak self] in
        guard let self = self else { return }
        let revisions = self.controller.revisions(indexes: Array(selectedIndexes.sorted(by: >)))
        self.didSelectRevisions?(revisions)
      },
      isContinueButtonEnabled: !selectedIndexes.isEmpty
    )
  }
  
  func createListSection(models: [ChooseWalletsController.WalletModel]) -> ChooseWalletToAddCollectionController.Section {
    let items = models.map { mapWalletModel($0) }
    return .wallets(items)
  }
  
  func createTitleDescriptionModel() -> TKTitleDescriptionView.Model {
    TKTitleDescriptionView.Model(
      title: TKLocales.ChooseWallets.title,
      bottomDescription: TKLocales.ChooseWallets.description
    )
  }
  
  func mapWalletModel(_ model: ChooseWalletsController.WalletModel) -> ChooseWalletToAddCell.Model {
    let cellModel = ChooseWalletToAddCell.Model(
      identifier: model.identifier,
      contentViewModel: ChooseWalletToAddCellContentView.Model(
        textContentModel: TKListItemTextContentView.Model(
          textWithTagModel: TKTextWithTagView.Model(
            title: model.address),
          subtitle: model.subtitle)
      )
    )
    return cellModel
  }
  
  func setSelectedIndexes(models: [ChooseWalletsController.WalletModel]) {
    selectedIndexes = Set(models.enumerated().compactMap { index, model in
      model.isSelected ? index : nil
    })
  }
}
