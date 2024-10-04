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
    setupViewEvents()
    setupBindings()
    viewModel.viewDidLoad()
  }
}

private extension StakingPoolDetailsViewController {

  func setup() {
    navigationItem.title = viewModel.title
    
    var configuration = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)
    configuration.content = TKButton.Configuration.Content(title: .plainString(viewModel.buttonTitle))
    configuration.action = { [weak viewModel] in
      viewModel?.didTapChooseButton()
    }
    customView.continueButton.configuration = configuration
    
    customView.listView.configure(model: viewModel.listViewModel)
    customView.descriptionLabel.attributedText = viewModel.description
    customView.linksView.configure(model: viewModel.linksViewModel)
  }
  
  func setupBindings() {
    
  }
  
  func setupViewEvents() {
  
  }
}
