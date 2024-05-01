import Foundation
import TKUIKit
import TKLocalize

protocol CollectiblesEmptyModuleOutput: AnyObject {
  var didTapReceive: (() -> Void)? { get set }
  var didTapBuy: (() -> Void)? { get set }
}

protocol CollectiblesEmptyViewModel: AnyObject {
  var didUpdateModel: ((CollectiblesEmptyView.Model) -> Void)? { get set }
  
  func viewDidLoad()
}

final class CollectiblesEmptyViewModelImplementation: CollectiblesEmptyViewModel, CollectiblesEmptyModuleOutput {
  
  // MARK: - CollectiblesEmptyModuleOutput
  
  var didTapReceive: (() -> Void)?
  var didTapBuy: (() -> Void)?
  
  // MARK: - CollectiblesEmptyViewModel
  
  var didUpdateModel: ((CollectiblesEmptyView.Model) -> Void)?
  
  func viewDidLoad() {
    didUpdateModel?(createModel())
  }
}

private extension CollectiblesEmptyViewModelImplementation {
  func createModel() -> CollectiblesEmptyView.Model {
    let title = TKLocales.Purchases.empty_placeholder.withTextStyle(
      .h2,
      color: .Text.primary,
      alignment: .center,
      lineBreakMode: .byWordWrapping
    )
    let buyButtonModel = TKUIActionButton.Model(title: "Buy Toncoin")
    let buyButtonAction: () -> Void = { [weak self] in
      self?.didTapBuy?()
    }
    
    let receiveButtonModel = TKUIActionButton.Model(title: "Receive")
    let receiveButtonAction: () -> Void = { [weak self] in
      self?.didTapReceive?()
    }

    return CollectiblesEmptyView.Model(
      title: title,
      description: nil,
      buyButtonModel: buyButtonModel,
      buyButtonAction: buyButtonAction,
      receiveButtonModel: receiveButtonModel,
      receiveButtonAction: receiveButtonAction
    )
  }
}
