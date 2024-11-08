import UIKit
import TKUIKit
import SnapKit
import TKLocalize

final class UpdatePopupViewController: BasicViewController, TKBottomSheetContentViewController {
  private let viewModel: UpdatePopupViewModel
  
  private let modalCardViewController = TKModalCardViewController()
  
  // MARK: - Init
  
  init(viewModel: UpdatePopupViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - View Life Cycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
    setupBindings()
    viewModel.viewDidLoad()
  }
  
  // MARK: - TKBottomSheetContentViewController

  var didUpdateHeight: (() -> Void)?
  
  var headerItem: TKUIKit.TKPullCardHeaderItem?
  
  var didUpdatePullCardHeaderItem: ((TKUIKit.TKPullCardHeaderItem) -> Void)?
  
  func calculateHeight(withWidth width: CGFloat) -> CGFloat {
    modalCardViewController.calculateHeight(withWidth: width - .horizontalPadding * 2)
  }
}

// MARK: - Private

private extension UpdatePopupViewController {
  func setup() {
    addChild(modalCardViewController)
    view.addSubview(modalCardViewController.view)
    modalCardViewController.didMove(toParent: self)
    
    modalCardViewController.view.snp.makeConstraints { make in
      make.top.bottom.equalTo(self.view)
      make.left.right.equalTo(self.view).inset(CGFloat.horizontalPadding/2)
    }
    
    modalCardViewController.successTitle = TKLocales.Result.success
    modalCardViewController.errorTitle = TKLocales.Result.failure
  }

  func setupBindings() {
    viewModel.didUpdateConfiguration = { [weak self] configuration in
      self?.modalCardViewController.configuration = configuration
      self?.didUpdateHeight?()
    }
  }
}

private extension CGFloat {
  static let horizontalPadding: CGFloat = 32
}
