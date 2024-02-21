import UIKit
import TKUIKit

final class TonConnectConnectViewController: UIViewController, TKBottomSheetScrollContentViewController {
  private let viewModel: TonConnectConnectViewModel
  
  private let modalCardViewController = TKModalCardViewController()
  
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
    
    modalCardViewController.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      modalCardViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
      modalCardViewController.view.leftAnchor.constraint(equalTo: view.leftAnchor),
      modalCardViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      modalCardViewController.view.rightAnchor.constraint(equalTo: view.rightAnchor)
    ])
  }

  func setupBindings() {
    viewModel.headerView = { address, iconUrl in
      let headerView = TonConnectModalHeaderView()
      headerView.configure(
        model: TonConnectModalHeaderView.Model(walletAddress: address ?? "", appImage: iconUrl)
      )
      return headerView
    }
    
    viewModel.walletPickerView = { walletModel in
      let view = TonConnectConnectWalletButton()
      view.contentView.configure(
        model: TonConnectConnectWalletButtonContentView.Model(
          emoji: walletModel.emoji,
          backgroundColor: .Tint.color(with: walletModel.colorIdentifier),
          walletName: walletModel.name,
          address: walletModel.address
        )
      )
      return view
    }
    
    viewModel.didUpdateConfiguration = { [weak self] configuration in
      self?.modalCardViewController.configuration = configuration
      self?.didUpdateHeight?()
    }
  }
}
