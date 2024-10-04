import UIKit
import TKUIKit

final class StoriesPageViewController: UIViewController {
  
  private let stackView = UIStackView()
  private let backgroundImageView = UIImageView()
  private let titleLabel = UILabel()
  private let descriptionLabel = UILabel()
  private let button = TKButton()
  private let buttonContainer = UIView()
  
  private let model: StoriesPageModel
  
  init(model: StoriesPageModel) {
    self.model = model
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
    setupContent()
  }
  
  private func setupContent() {
    backgroundImageView.image = model.backgroundImage
    titleLabel.attributedText = model.title.withTextStyle(.h1, color: .Constant.white)
    descriptionLabel.attributedText = model.description.withTextStyle(.body1, color: .Constant.white)
    if let button = model.button {
      buttonContainer.isHidden = false
      self.button.configuration.content = TKButton.Configuration.Content(title: .plainString(button.title))
      self.button.configuration.action = button.action
    } else {
      buttonContainer.isHidden = true
    }
  }
  
  private func setup() {
    button.configuration = .actionButtonConfiguration(category: .overlay, size: .medium)
    titleLabel.numberOfLines = 0
    descriptionLabel.numberOfLines = 0
    
    backgroundImageView.contentMode = .scaleAspectFill
    
    stackView.axis = .vertical
    stackView.spacing = 8
    
    view.addSubview(backgroundImageView)
    view.addSubview(stackView)
    
    let labelsStackView = UIStackView()
    labelsStackView.axis = .vertical
    labelsStackView.spacing = 8
    labelsStackView.addArrangedSubview(titleLabel)
    labelsStackView.addArrangedSubview(descriptionLabel)
    
    stackView.addArrangedSubview(labelsStackView)
    
    let labelsStackViewContainer = UIView()
    labelsStackViewContainer.addSubview(labelsStackView)
    labelsStackView.snp.makeConstraints { make in
      make.edges.equalTo(labelsStackViewContainer).inset(UIEdgeInsets(top: 28, left: 32, bottom: 28, right: 32))
    }
    stackView.addArrangedSubview(labelsStackViewContainer)
    
    buttonContainer.addSubview(button)
    button.snp.makeConstraints { make in
      make.top.equalTo(buttonContainer)
      make.left.bottom.equalTo(buttonContainer).inset(32)
      make.right.lessThanOrEqualTo(buttonContainer).offset(-32)
    }
    stackView.addArrangedSubview(buttonContainer)

    backgroundImageView.snp.makeConstraints { make in
      make.edges.equalTo(view)
    }
    stackView.snp.makeConstraints { make in
      make.left.bottom.right.equalTo(view)
    }
  }
}
