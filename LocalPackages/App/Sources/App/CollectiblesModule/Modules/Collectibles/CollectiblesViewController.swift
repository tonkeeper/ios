import UIKit
import TKUIKit
import TKCoordinator
import TKLocalize

final class CollectiblesViewController: ContentListEmptyViewController {

  private let viewModel: CollectiblesViewModel
  private let collectiblesListViewController: CollectiblesListViewController
  
  init(viewModel: CollectiblesViewModel,
       collectiblesListViewController: CollectiblesListViewController) {
    self.viewModel = viewModel
    self.collectiblesListViewController = collectiblesListViewController
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
    
    viewModel.viewDidLoad()
  }
  
  override func scrollToTop() {
    collectiblesListViewController.scrollToTop()
  }
}

private extension CollectiblesViewController {

  func setup() {
    configureNavigationBar()

    emptyViewController.configure(model: TKEmptyViewController.Model(
      title: TKLocales.Purchases.emptyPlaceholder,
      caption: nil,
      buttons: []
    ))
    
    setListViewController(collectiblesListViewController)

    setupBindings()
  }

  func configureNavigationBar() {
    customView.navigationBarView.title = TKLocales.Collectibles.title
  }

  func setupBindings() {
    viewModel.didUpdateIsLoading = { [weak self] isLoading in
      self?.customView.navigationBarView.isConnecting = isLoading
    }
    
    viewModel.didUpdateIsEmpty = { [weak self] isEmpty in
      if isEmpty {
        self?.setState(.empty, animated: false)
      } else {
        self?.setState(.list, animated: false)
      }
    }

    viewModel.didUpdateNavigationRightButtonVisibility = { [weak self] isHidden in
      var buttonItems = [TKNavigationBar.HeaderButtonItem]()
      if !isHidden {
        let rightButtonModel = TKNavigationBar.HeaderButtonItem(
          model: TKUIHeaderIconButton.Model(image: .TKUIKit.Icons.Size16.sliders)
        ) {
          self?.viewModel.didTapDetailsButton?()
        }
        buttonItems.append(rightButtonModel)
      }


      self?.customView.navigationBarView.configuration = .init(rightButtonItems: buttonItems)
    }
  }
}
