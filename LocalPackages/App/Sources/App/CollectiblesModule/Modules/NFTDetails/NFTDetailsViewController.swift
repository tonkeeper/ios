import UIKit
import TKUIKit

final class NFTDetailsViewController: GenericViewViewController<NFTDetailsView> {
  private let viewModel: NFTDetailsViewModel
  
  init(viewModel: NFTDetailsViewModel) {
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
    setupNavigationBar()
  }
  
  private func setupNavigationBar() {
    customView.navigationBar.leftViews = [
      TKUINavigationBar.createSwipeDownButton(action: { [weak self] in
        self?.viewModel.didTapClose()
      })
    ]
  }
  
  private func setupBindings() {
    viewModel.didUpdateTitleView = { [weak self] model in
      self?.customView.titleView.configure(model: model)
    }
    
    viewModel.didUpdateInformationView = { [weak self] model in
      self?.customView.informationView.configure(model: model)
    }
    
    viewModel.didUpdateButtonsView = { [weak self] model in
      if let model {
        self?.customView.buttonsView.isHidden = false
        self?.customView.buttonsView.configure(model: model)
      } else {
        self?.customView.buttonsView.isHidden = true
      }
    }
    
    viewModel.didUpdateDetailsView = { [weak self] model in
      self?.customView.detailsView.configure(model: model)
    }
    
    viewModel.didUpdatePropertiesView = { [weak self] model in
      if let model {
        self?.customView.propertiesView.isHidden = false
        self?.customView.propertiesView.configure(model: model)
      } else {
        self?.customView.propertiesView.isHidden = true
      }
    }

    viewModel.didUpdateMenuItems = { [weak self] items in
      self?.customView.navigationBar.rightViews = [
        TKUINavigationBar.createMoreButton(action: { targetView in
          TKPopupMenuController.show(
            sourceView: targetView,
            position: .bottomRight(inset: 8),
            width: 0,
            items: items,
            isSelectable: false,
            selectedIndex: nil)
        })
      ]
    }
  }
}
