import UIKit
import TKUIKit

final class SendEditButtonsView: UIView {
  
  var didTapBackButton: (() -> Void)?
  var didTapNextButton: (() -> Void)?
  
  lazy var backButton: TKButton = {
    var configuration = TKButton.Configuration.actionButtonConfiguration(
      category: .tertiary,
      size: .large
    )
    configuration.action = { [weak self] in
      self?.didTapBackButton?()
    }
    return TKButton(configuration: configuration)
  }()
  lazy var nextButton: TKButton = {
    var configuration = TKButton.Configuration.actionButtonConfiguration(
      category: .primary,
      size: .large
    )
    configuration.action = { [weak self] in
      self?.didTapNextButton?()
    }
    return TKButton(configuration: configuration)
  }()
  private let stackView = UIStackView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let contentSize = stackView.systemLayoutSizeFitting(
      CGSize(width: size.width, height: 0),
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .defaultLow
    )
    return CGSize(width: contentSize.width, height: contentSize.height)
  }
  
  private func setup() {
    backgroundColor = .Background.page
    
    stackView.spacing = 16
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
      top: 16,
      leading: 16,
      bottom: 16,
      trailing: 16
    )
    stackView.distribution = .fillEqually
    
    addSubview(stackView)
    stackView.addArrangedSubview(backButton)
    stackView.addArrangedSubview(nextButton)
    
    stackView.snp.makeConstraints { make in
      make.top.left.right.equalTo(self).priority(.high)
      make.bottom.equalTo(self).priority(.high)
    }
  }
}
