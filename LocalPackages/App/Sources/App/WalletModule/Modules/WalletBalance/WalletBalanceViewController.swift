import UIKit
import TKUIKit
import TKCoordinator

final class WalletBalanceViewController: GenericViewViewController<WalletBalanceView>, ScrollViewController {
  private let viewModel: WalletBalanceViewModel

  var collectionController: WalletBalanceCollectionController?

  init(viewModel: WalletBalanceViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    collectionController = WalletBalanceCollectionController(
      collectionView: customView.collectionView,
      headerViewProvider: { [customView] in customView.headerView }
    )
    
    collectionController?.isHighlightable = { [weak viewModel] section, index in
      viewModel?.isHighlightableItem(section: section, index: index) ?? true
    }
    
    setupBindings()
    viewModel.viewDidLoad()
  }
  
  func scrollToTop() {
    guard customView.collectionView.contentOffset.y > customView.collectionView.adjustedContentInset.top else { return }
    customView.collectionView.setContentOffset(
      CGPoint(x: 0,
              y: -customView.collectionView.adjustedContentInset.top),
      animated: true
    )
  }
}

private extension WalletBalanceViewController {
  func setupBindings() {
    viewModel.didUpdateHeader = { [weak customView] model in
      customView?.headerView.configure(model: model)
    }
    
    viewModel.didUpdateTonItems = { [weak collectionController] items in
      collectionController?.setTonItems(items)
    }
    
    viewModel.didUpdateJettonsItems = { [weak collectionController] items in
      collectionController?.setJettonsItems(items)
    }
    
    viewModel.didUpdateFinishSetupItems = { [weak collectionController] items, headerModel in
      collectionController?.setFinishSetupSection(items, headerModel: headerModel)
    }
    
    viewModel.didTapCopy = { address in
      UINotificationFeedbackGenerator().notificationOccurred(.warning)
      UIPasteboard.general.string = address
      ToastPresenter.showToast(configuration: .copied)
    }
    
    collectionController?.didSelect = { [weak viewModel] section, index in
      switch section {
      case .tonItems:
        viewModel?.didTapTonItem(at: index)
      case .jettonsItems:
        viewModel?.didTapJettonItem(at: index)
      case .finishSetup:
        viewModel?.didTapFinishSetupItem(at: index)
      }
    }
    
    collectionController?.didTapSectionHeaderButton = { [weak viewModel] section in
      viewModel?.didTapSectionHeaderButton(section: section)
    }
  }
}
