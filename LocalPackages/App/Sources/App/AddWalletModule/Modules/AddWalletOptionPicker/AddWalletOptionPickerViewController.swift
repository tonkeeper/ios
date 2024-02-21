import UIKit
import TKUIKit

final class AddWalletOptionPickerViewController: GenericViewViewController<AddWalletOptionPickerView>, TKBottomSheetScrollContentViewController {
  private let viewModel: AddWalletOptionPickerViewModel
  
  private lazy var collectionController = AddWalletOptionPickerCollectionController(
    collectionView: customView.collectionView,
    headerViewProvider: { [customView] in customView.titleDescriptionView }
  )
  
  init(viewModel: AddWalletOptionPickerViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setupBindings()
    viewModel.viewDidLoad()
  }
  
  // MARK: - TKPullCardScrollableContent
  
  var scrollView: UIScrollView {
    customView.collectionView
  }
  var didUpdateHeight: (() -> Void)?
  var didUpdatePullCardHeaderItem: ((TKPullCardHeaderItem) -> Void)?
  var headerItem: TKUIKit.TKPullCardHeaderItem?
  func calculateHeight(withWidth width: CGFloat) -> CGFloat {
    scrollView.contentSize.height
  }
}

private extension AddWalletOptionPickerViewController {
  func setupBindings() {
    viewModel.didUpdateModel = { [weak self] model in
      guard let self = self else { return }
      
      self.customView.titleDescriptionView.configure(model: model.titleDescriptionModel)
      self.collectionController.setOptionSections(model.optionSections)
    }
    
    collectionController.didSelect = { [weak viewModel] section, _ in
      viewModel?.didSelectOption(in: section)
    }
  }
}
