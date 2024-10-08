import UIKit
import TKUIKit
import TKCore

class BuyListPopUpViewController: GenericViewViewController<BuyListPopUpView>, TKBottomSheetScrollContentViewController {
  
  // MARK: - Module

  private let viewModel: BuyListPopUpViewModel
  
  // MARK: - Child
  
  private let popUpViewController = TKPopUp.ViewController()
  
  // MARK: - TKBottomSheetScrollContentViewController
  
  var scrollView: UIScrollView {
    popUpViewController.scrollView
  }
  
  var didUpdateHeight: (() -> Void)?
  
  var headerItem: TKUIKit.TKPullCardHeaderItem?
  
  var didUpdatePullCardHeaderItem: ((TKUIKit.TKPullCardHeaderItem) -> Void)?
  
  func calculateHeight(withWidth width: CGFloat) -> CGFloat {
    popUpViewController.calculateHeight(withWidth: width)
  }
  
  // MARK: - Init

  init(viewModel: BuyListPopUpViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - View Life cycle

  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
    setupBindings()
    viewModel.viewDidLoad()
  }
}

// MARK: - Private

private extension BuyListPopUpViewController {
  func setup() {
    addChild(popUpViewController)
    customView.embedContent(popUpViewController.view)
    popUpViewController.didMove(toParent: self)
  }
  
  func setupBindings() {
    viewModel.didUpdateConfiguration = { [weak popUpViewController, weak self] configuration in
      popUpViewController?.configuration = configuration
      self?.didUpdateHeight?()
    }
    
    viewModel.headerImageView = { model in
      let view = HistoryEventDetailsNFTHeaderImageView()
      view.imageLoader = ImageLoader()
      view.configure(model: model)
      return view
    }
    
    viewModel.descriptionView = { model in
      let view = TKDetailsDescriptionView()
      view.configure(model: model)
      return view
    }
    
    viewModel.doNotShowView = { model in
      let view = TKDetailsTickView()
      view.configure(model: model)
      return view
    }
  }
}
