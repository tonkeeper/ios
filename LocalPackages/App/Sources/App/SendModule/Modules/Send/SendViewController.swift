import UIKit
import TKUIKit
import TKLocalize

final class SendViewController: GenericViewViewController<SendView> {
  private let viewModel: SendViewModel
  
  init(viewModel: SendViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Send"
    view.backgroundColor = .Background.page
    
    setup()
    setupBindings()
    viewModel.viewDidLoad()
  }
}

private extension SendViewController {
  func setup() {
    customView.commentView.placeholder = "Comment"
    
    var continueButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
      category: .primary,
      size: .large
    )
    continueButtonConfiguration.content.title = .plainString(TKLocales.Actions.continue_action)
    continueButtonConfiguration.action = { [weak viewModel] in
      viewModel?.didTapContinueButton()
    }
    customView.continueButton.configuration = continueButtonConfiguration
  }
  
  func setupBindings() {
    viewModel.didUpdateWalletPickerItems = { [weak self] items in
      self?.customView.walletPickerView.items = items
    }
    
    viewModel.didUpdateWalletPickerSelectedItemIndex = { [weak self] index in
      self?.customView.walletPickerView.selectItem(at: index)
    }
    
    viewModel.didUpdateRecipientPickerItems = { [weak self] items in
      self?.customView.recipientPickerView.items = items
    }

    viewModel.didUpdateContinueButtonIsEnabled = { [weak self] isEnabled in
      self?.customView.continueButton.isEnabled = isEnabled
    }
    
    viewModel.didUpdateSendItem = { [weak self] sendItemModel in
      self?.customView.updateSendItemView(with: sendItemModel)
    }
    
    viewModel.didUpdateComment = { [weak self] in
      self?.customView.commentView.text = $0 ?? ""
    }
    
    customView.walletPickerView.didScrollToItem = { [weak self] index in
      self?.viewModel.didSelectFromWalletAtIndex(index)
    }
    
    customView.recipientPickerView.didScrollToItem = { [weak self] index in
      self?.viewModel.didSelectRecipientAtIndex(index)
    }
    
    customView.recipientPickerView.didTapItem = { [weak self] indexPath in
      guard indexPath.item == 0 else { return }
      self?.viewModel.didTapRecipientItem()
    }
    
    customView.walletPickerView.didTapAmount = { [weak self] indexPath in
      self?.viewModel.didTapWalletTokenPicker(index: indexPath.item)
    }
    
    customView.recipientPickerView.shouldHighlightItem = { indexPath in
      indexPath.item == 0
    }
    
    customView.didTapAmount = { [weak self] in
      self?.viewModel.didTapAmountButton()
    }
    
    customView.didTapComment = { [weak self] in
      self?.viewModel.didTapCommentButton()
    }
  }
}
