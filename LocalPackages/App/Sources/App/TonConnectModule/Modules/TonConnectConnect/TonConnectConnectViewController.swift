import UIKit
import TKUIKit

final class TonConnectConnectViewController: UIViewController, TKBottomSheetScrollContentViewController {
  private let viewModel: TonConnectConnectViewModel
  
  private let modalCardViewController = TKPopUp.ViewController()
  
  // MARK: - Init
  
  init(viewModel: TonConnectConnectViewModel) {
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
  
  // MARK: - TKBottomSheetScrollContentViewController
  
  var scrollView: UIScrollView {
    modalCardViewController.scrollView
  }
  
  var didUpdateHeight: (() -> Void)?
  
  var headerItem: TKUIKit.TKPullCardHeaderItem?
  
  var didUpdatePullCardHeaderItem: ((TKUIKit.TKPullCardHeaderItem) -> Void)?
  
  func calculateHeight(withWidth width: CGFloat) -> CGFloat {
    modalCardViewController.calculateHeight(withWidth: width)
  }
}

// MARK: - Private

private extension TonConnectConnectViewController {
  func setup() {
    addChild(modalCardViewController)
    view.addSubview(modalCardViewController.view)
    modalCardViewController.didMove(toParent: self)
    
    modalCardViewController.view.snp.makeConstraints { make in
      make.edges.equalTo(view)
    }
  }

  func setupBindings() {
//    viewModel.headerView = { address, iconUrl in
//      let headerView = TonConnectModalHeaderView()
//      headerView.configure(
//        model: TonConnectModalHeaderView.Model(walletAddress: address ?? "", appImage: iconUrl)
//      )
//      return headerView
//    }
//    
    viewModel.walletPickerView = { model in
      let view = TonConnectConnectWalletButton()
      view.contentView.configure(
        configuration: model
      )
      return view
    }
    
    viewModel.didUpdateConfiguration = { [weak self] configuration in
      self?.modalCardViewController.configuration = configuration
      self?.didUpdateHeight?()
    }
  }
}
