import TKUIKit
import UIKit

final class EthenaStakingDetailsViewController: GenericViewViewController<EthenaStakingDetailsView>, KeyboardObserving {
    private let viewModel: EthenaStakingDetailsViewModel

    init(viewModel: EthenaStakingDetailsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationBar()
        setupBindings()
        viewModel.viewDidLoad()
    }
}

private extension EthenaStakingDetailsViewController {
    func setupBindings() {
        viewModel.didUpdateTitleView = { [weak self] model in
            self?.customView.titleView.configure(model: model)
        }
        viewModel.didUpdateLinksViewModel = { [weak self] model in
            if let model {
                self?.customView.linksView.configure(model: model)
                self?.customView.linksView.isHidden = false
            } else {
                self?.customView.linksView.isHidden = true
            }
        }

        viewModel.didUpdateInformationView = { [weak self] model in
            self?.customView.informationView.configure(model: model)
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

        viewModel.didUpdateJettonButtonDescription = {
            [weak self] description, actions in
            if let description {
                self?.customView.jettonButtonDescriptionLabel.setAttributedText(
                    description,
                    actionItems: actions
                )
            } else {
                self?.customView.jettonButtonDescriptionLabel.isHidden = true
            }
        }

        viewModel.didUpdateButtonsView = { [weak self] model in
            if let model {
                self?.customView.buttonsView.configure(model: model)
                self?.customView.buttonsView.isHidden = false
            } else {
                self?.customView.buttonsView.isHidden = true
            }
        }

        viewModel.didUpdateStakingInfoView = { [weak self] configuration in
            if let configuration {
                self?.customView.stakingInfoView.isHidden = false
                self?.customView.stakingInfoView.configuration = configuration
            } else {
                self?.customView.stakingInfoView.isHidden = true
            }
        }
    }

    private func setupNavigationBar() {
        guard let navigationController,
              !navigationController.viewControllers.isEmpty
        else {
            return
        }
        customView.navigationBar.leftViews = [
            TKUINavigationBar.createBackButton {
                navigationController.popViewController(animated: true)
            },
        ]
    }
}
