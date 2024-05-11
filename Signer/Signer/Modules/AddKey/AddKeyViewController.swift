import UIKit
import TKUIKit
import SignerLocalize

final class AddKeyViewController: GenericViewViewController<AddKeyView>, TKBottomSheetContentViewController {
  
  var didTapCreateNewKey: (() -> Void)?
  var didTapImportKey: (() -> Void)?
  
  // MARK: - TKBottomSheetContentViewController
  
  var headerItem: TKUIKit.TKPullCardHeaderItem?
  
  var didUpdatePullCardHeaderItem: ((TKUIKit.TKPullCardHeaderItem) -> Void)?
  
  func calculateHeight(withWidth width: CGFloat) -> CGFloat {
    return customView.systemLayoutSizeFitting(
      CGSize(width: width, height: 0),
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .fittingSizeLevel
    ).height
  }
  
  var didUpdateHeight: (() -> Void)?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    customView.titleDescriptionView.configure(
      model: TKTitleDescriptionView.Model(
        title: SignerLocalize.AddKey.title,
        bottomDescription: SignerLocalize.AddKey.caption)
    )
    
    var createButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
      category: .primary,
      size: .large
    )
    createButtonConfiguration.content = TKButton.Configuration.Content(title: .plainString(SignerLocalize.AddKey.Buttons.create_new))
    createButtonConfiguration.action = { [weak self] in
      self?.didTapCreateNewKey?()
    }
    customView.createButton.configuration = createButtonConfiguration
    
    var importButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
      category: .secondary,
      size: .large
    )
    importButtonConfiguration.content = TKButton.Configuration.Content(title: .plainString(SignerLocalize.AddKey.Buttons.import_existing))
    importButtonConfiguration.action = { [weak self] in
      self?.didTapImportKey?()
    }
    customView.importButton.configuration = importButtonConfiguration
  }
}
