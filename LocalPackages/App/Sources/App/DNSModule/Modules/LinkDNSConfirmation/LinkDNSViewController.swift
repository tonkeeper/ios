import UIKit
import TKUIKit
import TKLocalize

final class LinkDNSViewController: BasicViewController, TKBottomSheetScrollContentViewController {
  private let viewModel: LinkDNSViewModel
  
  private let modalCardViewController = TKModalCardViewController()
  
  init(viewModel: LinkDNSViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setup()
    setupBindings()
    viewModel.viewDidLoad()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - TKBottomSheetScrollContentViewController
  
  var scrollView: UIScrollView {
    modalCardViewController.scrollView
  }
  
  var didUpdateHeight: (() -> Void)?
  
  var headerItem: TKUIKit.TKPullCardHeaderItem? {
    TKUIKit.TKPullCardHeaderItem(title: .title(title: viewModel.title, subtitle: nil))
  }
  
  var didUpdatePullCardHeaderItem: ((TKUIKit.TKPullCardHeaderItem) -> Void)?
  
  func calculateHeight(withWidth width: CGFloat) -> CGFloat {
    modalCardViewController.calculateHeight(withWidth: width)
  }
}

private extension LinkDNSViewController {
  func setup() {
    addChild(modalCardViewController)
    view.addSubview(modalCardViewController.view)
    modalCardViewController.didMove(toParent: self)
    
    modalCardViewController.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      modalCardViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
      modalCardViewController.view.leftAnchor.constraint(equalTo: view.leftAnchor),
      modalCardViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      modalCardViewController.view.rightAnchor.constraint(equalTo: view.rightAnchor)
    ])
    
    modalCardViewController.successTitle = TKLocales.Result.success
    modalCardViewController.errorTitle = TKLocales.Result.failure
  }
  
  func setupBindings() {
    viewModel.didUpdateConfiguration = { [weak self] configuration in
      self?.modalCardViewController.configuration = configuration
    }
  }
}
