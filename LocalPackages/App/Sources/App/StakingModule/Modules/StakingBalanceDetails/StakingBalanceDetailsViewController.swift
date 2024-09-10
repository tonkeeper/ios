import UIKit
import TKUIKit

final class StakingBalanceDetailsViewController: GenericViewViewController<StakingBalanceDetailsView>, KeyboardObserving {
  private let viewModel: StakingBalanceDetailsViewModel
  private let amountInputViewController = AmountInputViewController()
  
  init(viewModel: StakingBalanceDetailsViewModel) {
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
  
  public override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    navigationController?.setNavigationBarHidden(false, animated: true)
  }
}

private extension StakingBalanceDetailsViewController {

  func setup() {
    navigationItem.title = viewModel.title
  }
  
  func setupBindings() {
    viewModel.didUpdateListViewModel = { [weak self] model in
      self?.customView.listView.configure(model: model)
    }
    viewModel.didUpdateLinksViewModel = { [weak self] model in
      self?.customView.linksView.configure(model: model)
    }
    
    viewModel.didUpdateInformationView = { [weak self] model in
      self?.customView.informationView.configure(model: model)
    }
    
    viewModel.didUpdateDescription = { [weak self] description in
      self?.customView.descriptionLabel.attributedText = description
    }
    
    viewModel.didUpdateJettonItemView = { [weak self] configuration in
      if let configuration {
        self?.customView.jettonButtonContainer.isHidden = false
        self?.customView.jettonButtonDescriptionContainer.isHidden = false
        self?.customView.jettonButton.configuration = configuration
      } else {
        self?.customView.jettonButtonContainer.isHidden = true
        self?.customView.jettonButtonDescriptionContainer.isHidden = true
      }
    }
    
    viewModel.didUpdateJettonButtonDescription = { [weak self] description in
      self?.customView.jettonButtonDescriptionLabel.attributedText = description
    }
    
    viewModel.didUpdateStakeStateView = { [weak self] configuration in
      if let configuration {
        self?.customView.stakeStateButtonContainer.isHidden = false
        self?.customView.stakeStateButton.configuration = configuration
      } else {
        self?.customView.stakeStateButtonContainer.isHidden = true
      }
    }
    
    viewModel.didUpdateButtonsView = { [weak self] model in
      self?.customView.buttonsView.configure(model: model)
    }
  }
  
  func setupViewEvents() {
  
  }
}
