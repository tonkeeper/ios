import Foundation
import TKUIKit
import TKLocalize

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
    let title = TKLocales.History.Placeholder.title
      .withTextStyle(
        .h2,
        color: .Text.primary,
        alignment: .center,
        lineBreakMode: .byWordWrapping
      )
    let description = TKLocales.History.Placeholder.subtitle
      .withTextStyle(
        .body1,
        color: .Text.secondary,
        alignment: .center,
        lineBreakMode: .byWordWrapping
      )
    
    let buyButtonModel = TKUIActionButton.Model(title: TKLocales.History.Placeholder.Buttons.buy)
    let buyButtonAction: () -> Void = { [weak self] in
      self?.didTapBuy?()
    }
    
    let receiveButtonModel = TKUIActionButton.Model(title: TKLocales.History.Placeholder.Buttons.receive)
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
