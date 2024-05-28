import UIKit
import TKUIKit
import SnapKit

final class SwapAmountHeaderView: UIView, ConfigurableView {
  
  let leftTitleLabel = UILabel()
  let rightTitleLabel = UILabel()
  let actionButton = TKButton(configuration: .headerAccentButtonConfiguration())
  
  private let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    return stackView
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    struct Button {
      let title: String
      let action: (() -> Void)?
    }
    
    let leftTitle: NSAttributedString
    let rightTitle: NSAttributedString?
    let button: Button?
    
    init(leftTitle: NSAttributedString,
         rightTitle: NSAttributedString? = nil,
         button: Button? = nil) {
      self.leftTitle = leftTitle
      self.rightTitle = rightTitle
      self.button = button
    }
  }
  
  func configure(model: Model) {
    leftTitleLabel.setTitle(model.leftTitle)
    rightTitleLabel.setTitle(model.rightTitle)
    
    if let button = model.button {
      let title = button.title.withTextStyle(.label2, color: .Text.accent)
      actionButton.configuration.content.title = .attributedString(title)
      actionButton.configuration.action = button.action
      actionButton.configuration.padding = .zero
      actionButton.configuration.contentPadding = .zero
      actionButton.isHidden = false
    } else {
      actionButton.isHidden = true
    }
  }
}

private extension SwapAmountHeaderView {
  func setup() {
    contentStackView.addArrangedSubview(leftTitleLabel)
    contentStackView.addArrangedSubview(rightTitleLabel)
    contentStackView.setCustomSpacing(.horizontalSpacing, after: rightTitleLabel)
    contentStackView.addArrangedSubview(actionButton)
    
    addSubview(contentStackView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    leftTitleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    rightTitleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
    actionButton.setContentHuggingPriority(.required, for: .horizontal)
    
    contentStackView.snp.makeConstraints { make in
      make.height.equalTo(CGFloat.headerItemsHeight)
      make.left.right.equalTo(self)
      make.bottom.equalTo(self).inset(CGFloat.verticalSpacing)
    }
  }
}

private extension UILabel {
  func setTitle(_ title: NSAttributedString?) {
    attributedText = title
    isHidden = title == nil
  }
}

private extension CGFloat {
  static let headerItemsHeight: CGFloat = 20
  static let verticalSpacing: CGFloat = 8
  static let horizontalSpacing: CGFloat = 8
}
