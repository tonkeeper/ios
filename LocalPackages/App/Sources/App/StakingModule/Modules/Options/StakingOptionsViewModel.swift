import UIKit
import Foundation
import TKUIKit
import TKCore
import BigInt
import TonSwift
import KeeperCore

protocol StakingOptionsModuleOutput: AnyObject {
  var didTapOptionDetails: ((OptionItem) -> Void)? { get set }
  var didChooseOption: ((OptionItem) -> Void)? { get set }
}

protocol StakingOptionsViewModel: AnyObject {
  var didUpdateSections: (([StakingOptionSection]) -> Void)? { get set }
  
  func viewDidLoad()
  func selectItem(section: StakingOptionSection, index: Int)
}

final class StakingOptionsViewModelImplementation: StakingOptionsViewModel, StakingOptionsModuleOutput {
  
  // MARK: - StakingOptionsModulOutput
  
  var didTapOptionDetails: ((OptionItem) -> Void)?
  var didChooseOption: ((OptionItem) -> Void)?
  

  // MARK: - StakingViewModel
  
  var didUpdateSections: (([StakingOptionSection]) -> Void)?
  
  func viewDidLoad() {
    controller.didUpdateItems = { [weak self] items in
      guard let self else { return }
      
      let liquidItems = items.filter { $0.isPrefferable }
      let otherItems = items.filter { !$0.isPrefferable }
      
      let liquidSectionItems = liquidItems.map { item in
        self.mapper.mapOptionItem(item) { id, _ in
          self.controller.didSelectPreferableItem(id: id)
          self.didChooseOption?(item)
        } selClosure: {
          self.didTapOptionDetails?(item)
          self.didChooseOption?(item)
        }
      }
      
      let otherSectionItems = otherItems.map { item in
        self.mapper.mapOptionItem(item) { id, _ in
          self.controller.didSelectPreferableItem(id: id)
        } selClosure: {
          self.didTapOptionDetails?(item)
        }
      }
      
      let sections: [StakingOptionSection] = [
        .init(title: .liquidStakingSectionTitle, items: liquidSectionItems),
        .init(title: .otherOptionsSectionTitle, items: otherSectionItems)
      ]
      
      self.didUpdateSections?(sections)
    }
    
    controller.start()
  }
  
  func selectItem(section: StakingOptionSection, index: Int) {
    section.items[index].selectionClosure?()
  }
  
  // MARK: - Dependencies
  let controller: StakingOptionsController = .init()
  let mapper: StakingOptionListItemMapper = .init()
}

// MARK: - Private methods

private extension StakingOptionsViewModelImplementation {
  
}

private extension String {
  static let liquidStakingSectionTitle = "Liquid Staking"
  static let otherOptionsSectionTitle = "Other"
}
