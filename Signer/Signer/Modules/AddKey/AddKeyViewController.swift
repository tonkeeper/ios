import UIKit
import TKUIKit

final class AddKeyViewController: GenericViewViewController<AddKeyView>, TKBottomSheetContentViewController {
  
  var didTapCreateNewKey: (() -> Void)?
  var didTapImportKey: (() -> Void)?
  
  // MARK: - TKBottomSheetContentViewController
  
  var headerItem: TKUIKit.TKPullCardHeaderItem?
  
  var didUpdatePullCardHeaderItem: ((TKUIKit.TKPullCardHeaderItem) -> Void)?
  
  func calculateHeight(withWidth width: CGFloat) -> CGFloat {
    return customView.systemLayoutSizeFitting(CGSize(width: width, height: 0)).height
  }
  
  var didUpdateHeight: (() -> Void)?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    customView.titleDescriptionView.configure(
      model: TKTitleDescriptionView.Model(
        title: "Add Key",
        bottomDescription: "Create a new key or add an existing one.")
    )
    
    var createButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
      category: .primary,
      size: .large
    )
    createButtonConfiguration.content = TKButton.Configuration.Content(title: .plainString("Create New Key"))
    createButtonConfiguration.action = { [weak self] in
      self?.didTapCreateNewKey?()
    }
    customView.createButton.configuration = createButtonConfiguration
    
    var importButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
      category: .secondary,
      size: .large
    )
    importButtonConfiguration.content = TKButton.Configuration.Content(title: .plainString("Import Existing Key"))
    importButtonConfiguration.action = { [weak self] in
      self?.didTapImportKey?()
    }
    customView.importButton.configuration = importButtonConfiguration
  }
}
