import UIKit
import TKUIKit

final class AddKeyViewController: GenericViewViewController<AddKeyView>, TKPullableCardContent {
  
  var didTapCreateNewKey: (() -> Void)?
  var didTapImportKey: (() -> Void)?
  
  // MARK: - TKPullableCardContent
  
  var height: CGFloat {
    return customView
      .systemLayoutSizeFitting(
        CGSize(width: view.bounds.width, height: 0)
      )
      .height
  }
  
  var didUpdateHeight: (() -> Void)?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    customView.titleDescriptionView.configure(
      model: TKTitleDescriptionHeaderView.Model(
        title: "Add Key",
        bottomDescription: "Create a new key or add an existing one.")
    )
    
    customView.createButton.configure(
      model: TKButtonControl<ButtonTitleContentView>.Model(
        contentModel: ButtonTitleContentView.Model(title: "Create New Key"), action: { [weak self] in
          self?.didTapCreateNewKey?()
        }
      )
    )
    
    customView.importButton.configure(
      model: TKButtonControl<ButtonTitleContentView>.Model(
        contentModel: ButtonTitleContentView.Model(title: "Import Existing Key"), action: { [weak self] in
          self?.didTapImportKey?()
        }
      )
    )
  }
}
