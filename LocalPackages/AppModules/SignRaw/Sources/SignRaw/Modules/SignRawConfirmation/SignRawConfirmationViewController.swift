import UIKit
import TKUIKit

final class SignRawConfirmationViewController: GenericViewViewController<SignRawConfirmationView>, TKBottomSheetScrollContentViewController {
  private let viewModel: SignRawConfirmationViewModel
  
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
  
  init(viewModel: SignRawConfirmationViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setup()
    setupBindings()
    viewModel.viewDidLoad()
  }
  
  private func setup() {
    setupContent()
  }
  
  private func setupBindings() {
    viewModel.didUpdateHeader = { [weak self] in
      self?.didUpdatePullCardHeaderItem?($0)
    }
    viewModel.didUpdateConfiguration = { [weak self] in
      self?.popUpViewController.configuration = $0
      self?.didUpdateHeight?()
    }
  }
  
  func setupContent() {
    addChild(popUpViewController)
    customView.embedContent(popUpViewController.view)
    popUpViewController.didMove(toParent: self)
  }
}
