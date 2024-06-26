import UIKit
import TKUIKit

final class SendCommentViewController: GenericViewViewController<SendCommentView> {
  private let viewModel: SendCommentViewModel
  
  init(viewModel: SendCommentViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Comment"
    view.backgroundColor = .Background.page
    
    setup()
    setupBindings()
    setupViewEventsBinding()
    viewModel.viewDidLoad()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    customView.commentTextField.becomeFirstResponder()
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    viewModel.viewWillDisappear()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    viewModel.viewDidAppear()
  }
}

private extension SendCommentViewController {
  func setup() {
    var configuration = TKButton.Configuration.titleHeaderButtonConfiguration(category: .tertiary)
    configuration.content.title = .plainString("Paste")
    configuration.action = { [weak viewModel] in
      viewModel?.didTapPasteButton()
    }
    customView.pasteButton.configuration = configuration
  }
  
  func setupBindings() {
    viewModel.didUpdateComment = { [weak self] text in
      DispatchQueue.main.async {
        self?.customView.commentTextField.text = text
      }
    }
    
    viewModel.didUpdatePlaceholder = { [weak customView] in
      customView?.commentTextField.placeholder = $0
    }
    
    viewModel.didUpdateDescription = { [weak customView] in
      customView?.descriptionLabel.attributedText = $0
    }
    
    viewModel.didUpdateDescriptionVisibility = { [weak customView] in
      customView?.descriptionLabel.isHidden = !$0
    }
  }
  
  func setupViewEventsBinding() {
    customView.commentTextField.didUpdateText = { [weak viewModel] text in
      viewModel?.didEditComment(text)
    }
  }
}
