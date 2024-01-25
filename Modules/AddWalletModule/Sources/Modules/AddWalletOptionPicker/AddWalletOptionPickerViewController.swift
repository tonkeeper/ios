import UIKit
import TKUIKit

final class AddWalletOptionPickerViewController: GenericViewViewController<AddWalletOptionPickerView>, TKBottomSheetScrollContentViewController {
  private let viewModel: AddWalletOptionPickerViewModel
  
  private lazy var collectionController = TKCollectionController(
    collectionView: customView.collectionView,
    sectionPaddingProvider: { section in
      switch section {
      case .list:
        return NSDirectionalEdgeInsets(top: 0, leading: 32, bottom: 16, trailing: 32)
      }
    },
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
}

private extension AddWalletOptionPickerViewController {
  func setupBindings() {
    viewModel.didUpdateModel = { [weak self] model in
      guard let self = self else { return }
      
      self.customView.titleDescriptionView.configure(model: model.titleDescriptionModel)
      self.collectionController.setSections(model.listSections, animated: false)
    }
  }
}
