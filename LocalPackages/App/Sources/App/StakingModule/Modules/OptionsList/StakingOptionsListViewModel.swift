import UIKit
import Foundation
import TKUIKit
import TKCore
import BigInt
import TonSwift
import KeeperCore

protocol StakingOptionsListModuleOutput: AnyObject {
  var didChooseStakingPool: ((StakingPool) -> Void)? { get set }
  var didTapPoolImplementation: ((StakingOptionsListModel, Address?) -> Void)? { get set }
  var didTapOptionDetails: ((StakingPool) -> Void)? { get set }
}

protocol StakingOptionsListViewModel: AnyObject {
  var didUpdateSections: (([StakingOptionSection]) -> Void)? { get set }
  
  func viewDidLoad()
  func selectItem(section: StakingOptionSection, index: Int)
}

final class StakingOptionsListViewModelImplementation: StakingOptionsListViewModel, StakingOptionsListModuleOutput {
  
  // MARK: - StakingOptionsModulOutput
  
  var didTapOptionDetails: ((StakingPool) -> Void)?
  var didChooseStakingPool: ((StakingPool) -> Void)?
  var didTapPoolImplementation: ((StakingOptionsListModel, Address?) -> Void)?
  
  // MARK: - StakingViewModel
  
  var didUpdateSections: (([StakingOptionSection]) -> Void)?
  
  func viewDidLoad() {
    setupControllerBindings()
    
    controller.start()
  }
  
  func selectItem(section: StakingOptionSection, index: Int) {
    section.items[index].selectionClosure?()
  }
  
  // MARK: - Dependencies
  private let controller: StakingOptionsListController
  private let mapper: StakingOptionListItemMapper
  
  init(controller: StakingOptionsListController, mapper: StakingOptionListItemMapper) {
    self.controller = controller
    self.mapper = mapper
  }
}

// MARK: - Private methods

private extension StakingOptionsListViewModelImplementation {
  
  func setupControllerBindings() {
    
    controller.didUpdateItemGroups = { [weak self] groups in
      guard let self else { return }
      
      var sections: [StakingOptionSection] = []
      for group in groups {
        let section: StakingOptionSection = .init(
          title: group.id,
          items: group.items.map { item in
            self.mapper.mapOptionItem(item) { id in
              self.controller.didSelectExactPool(id: id)
              guard let selectedStakingPool = self.controller.getSelectedStakingPool() else {
                return
              }
              
              self.didChooseStakingPool?(selectedStakingPool)
            } selectionClosure: {
              if item.canSelect {
                guard let pool = self.controller.getStakingPool(item.id) else {
                  return
                }
                self.didTapOptionDetails?(pool)
              } else {
                let model = self.controller.createInputModel(id: item.id)
                let address = self.controller.selectedPoolAddress
                self.didTapPoolImplementation?(model, address)
              }
            }
          }
        )
        sections.append(section)
      }
      
      didUpdateSections?(sections)
    }
  }
}

private extension String {
  static let liquidStakingSectionTitle = "Liquid Staking"
  static let otherOptionsSectionTitle = "Other"
}
