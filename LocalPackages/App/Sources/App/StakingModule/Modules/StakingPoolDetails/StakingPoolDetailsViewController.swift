import UIKit
import TKUIKit

final class StakingPoolDetailsViewController: GenericViewViewController<StakingPoolDetailsView>, KeyboardObserving {
  private let viewModel: StakingPoolDetailsViewModel
  private let amountInputViewController = AmountInputViewController()
  
  init(viewModel: StakingPoolDetailsViewModel) {
    self.viewModel = viewModel
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
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    customView.navigationBar.layoutIfNeeded()
    customView.scrollView.contentInset.top = customView.navigationBar.bounds.height
    customView.scrollView.contentInset.bottom = customView.safeAreaInsets.bottom + 16
  }
}

private extension StakingPoolDetailsViewController {

  func setup() {
    customView.titleView.configure(
      model: TKUINavigationBarTitleView.Model(
        title: viewModel.title.withTextStyle(
          .h3,
          color: .Text.primary,
          alignment: .center,
          lineBreakMode: .byTruncatingTail
        )
      )
    )
    
    var configuration = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)
    configuration.content = TKButton.Configuration.Content(title: .plainString(viewModel.buttonTitle))
    configuration.action = { [weak viewModel] in
      viewModel?.didTapChooseButton()
    }
    customView.continueButton.configuration = configuration
    
    customView.listView.configure(model: viewModel.listViewModel)
    customView.descriptionLabel.attributedText = viewModel.description
    customView.linksView.configure(model: viewModel.linksViewModel)
    
    setupNavigationBar()
  }
  
  func setupNavigationBar() {
    guard let navigationController,
          !navigationController.viewControllers.isEmpty else {
      return
    }
    if navigationController.viewControllers.count > 1 {
      customView.navigationBar.leftViews = [
        TKUINavigationBar.createBackButton {
          navigationController.popViewController(animated: true)
        }
      ]
    }
    
    customView.navigationBar.rightViews = [
      TKUINavigationBar.createCloseButton { [weak self] in
        self?.viewModel.didTapCloseButton()
      }
    ]
  }
}
