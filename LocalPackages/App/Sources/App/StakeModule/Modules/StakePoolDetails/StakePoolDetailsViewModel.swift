import UIKit
import TKUIKit
import KeeperCore

protocol StakePoolDetailsModuleOutput: AnyObject {
  var didTapLink: ((TitledURL) -> Void)? { get set }
  var didChoosePool: ((StakePool) -> Void)? { get set }
}

protocol StakePoolDetailsModuleInput: AnyObject {
  
}

protocol StakePoolDetailsViewModel: AnyObject {
  var didUpdateModel: ((StakePoolDetailsView.Model) -> Void)? { get set }
  var didUpdateListItems: (([TKUIListItemCell.Configuration], [IconButtonCell.Configuration]) -> Void)? { get set }
  
  func viewDidLoad()
}

final class StakePoolDetailsViewModelImplementation: StakePoolDetailsViewModel, StakePoolDetailsModuleOutput, StakePoolDetailsModuleInput {
  
  // MARK: - StakePoolDetailsModuleOutput
  
  var didTapLink: ((TitledURL) -> Void)?
  var didChoosePool: ((StakePool) -> Void)?
  
  // MARK: - StakePoolDetailsModuleInput
  
  // MARK: - StakePoolDetailsViewModel
  
  var didUpdateModel: ((StakePoolDetailsView.Model) -> Void)?
  var didUpdateListItems: (([TKUIListItemCell.Configuration], [IconButtonCell.Configuration]) -> Void)?
  
  func viewDidLoad() {
    updateWithInitialData()
  }
  
  // MARK: - Mapper
  
  private let itemMapper = StakePoolDetailsListItemMapper()
  
  // MARK: - Dependencies
  
  private let stakePoolDetailsController: StakePoolDetailsController
  private let stakePool: StakePool
  
  // MARK: - Init
  
  init(stakePoolDetailsController: StakePoolDetailsController, stakePool: StakePool) {
    self.stakePoolDetailsController = stakePoolDetailsController
    self.stakePool = stakePool
  }
  
  deinit {
    print("\(Self.self) deinit")
  }
}

// MARK: - Private

private extension StakePoolDetailsViewModelImplementation {
  func updateWithInitialData() {
    let detailsItems = itemMapper.mapStakePool(stakePool)
    let linksItems = stakePool.links.compactMap { [weak self] link in
      self?.itemMapper.mapStakePoolLink(link) {
        self?.didTapLink?(link.titledUrl)
      }
    }
    
    didUpdateListItems?(detailsItems, linksItems)
    update()
  }
  
  func update() {
    let model = createModel()
    didUpdateModel?(model)
  }
  
  func createModel() -> StakePoolDetailsView.Model {
    StakePoolDetailsView.Model(
      title: ModalTitleView.Model(title: stakePool.title),
      button: StakePoolDetailsView.Model.Button(
        title: "Choose",
        action: { [weak self] in
          guard let self else { return }
          self.didChoosePool?(self.stakePool)
        }
      )
    )
  }
}
