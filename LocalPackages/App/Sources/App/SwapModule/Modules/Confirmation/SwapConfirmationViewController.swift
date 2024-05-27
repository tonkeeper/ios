import UIKit
import TKUIKit

final class SwapConfirmationViewController: GenericViewViewController<SwapConfirmationView> {
  
  private let viewModel: SwapConfirmationViewModel
  
  init(viewModel: SwapConfirmationViewModel) {
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
    setupViewEvents()
    self.viewModel.viewDidLoad()
  }

  private func setup() {
    customView.confirmButton.configuration.content = TKButton.Configuration.Content(title: .plainString("Confirm"))
    customView.cancelButton.configuration.content = TKButton.Configuration.Content(title: .plainString("Cancel"))
    customView.headerLabel.attributedText = "Confirm swap".withTextStyle(
      .h3, color: .Text.primary, alignment: .center
    )
  }

  private func setupBindings() {
    viewModel.didUpdateModel = { [weak self] model in
      guard let self else { return }

      self.customView.sendView.chooseTokenView.token = model.send.token
      self.customView.sendView.chooseTokenView.isUserInteractionEnabled = false
      self.customView.sendView.amountTextField.text = model.send.amount
      self.customView.sendView.updateTotalBalance(model.send.balance)
      
      self.customView.receiveView.chooseTokenView.token = model.receive.token
      self.customView.receiveView.chooseTokenView.isUserInteractionEnabled = false
      self.customView.receiveView.amountTextField.text = model.receive.amount
      self.customView.receiveView.updateTotalBalance(model.receive.balance)

      self.customView.detailsView.update(items: model.swapDetails, oneTokenPrice: model.oneTokenPrice)
    }
  }

  private func setupViewEvents() {
    customView.cancelButton.configuration.action = { [weak viewModel] in
      viewModel?.didTapCancel()
    }
    customView.confirmButton.configuration.action = { [weak viewModel] in
      viewModel?.didTapConfirm()
    }
  }
}
