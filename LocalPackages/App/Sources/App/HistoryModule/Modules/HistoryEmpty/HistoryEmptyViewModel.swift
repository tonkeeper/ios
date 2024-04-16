import Foundation
import TKUIKit

protocol HistoryEmptyModuleOutput: AnyObject {
  var didTapReceive: (() -> Void)? { get set }
  var didTapBuy: (() -> Void)? { get set }
}

protocol HistoryEmptyViewModel: AnyObject {
  var didUpdateModel: ((HistoryEmptyView.Model) -> Void)? { get set }
  
  func viewDidLoad()
}

final class HistoryEmptyViewModelImplementation: HistoryEmptyViewModel, HistoryEmptyModuleOutput {
  
  // MARK: - HistoryEmptyModuleOutput
  
  var didTapReceive: (() -> Void)?
  var didTapBuy: (() -> Void)?
  
  // MARK: - HistoryEmptyViewModel
  
  var didUpdateModel: ((HistoryEmptyView.Model) -> Void)?
  
  func viewDidLoad() {
    didUpdateModel?(createModel())
  }
}

private extension HistoryEmptyViewModelImplementation {
  func createModel() -> HistoryEmptyView.Model {
    let title = "Your history\nwill be shown here".withTextStyle(
      .h2,
      color: .Text.primary,
      alignment: .center,
      lineBreakMode: .byWordWrapping
    )
    let description = "Make your first transaction!".withTextStyle(
      .body1,
      color: .Text.secondary,
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

    return HistoryEmptyView.Model(
      title: title,
      description: description,
      buyButtonModel: buyButtonModel,
      buyButtonAction: buyButtonAction,
      receiveButtonModel: receiveButtonModel,
      receiveButtonAction: receiveButtonAction
    )
  }
}
