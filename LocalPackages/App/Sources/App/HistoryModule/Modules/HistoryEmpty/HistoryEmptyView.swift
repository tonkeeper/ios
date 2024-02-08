import UIKit
import TKUIKit

final class HistoryEmptyView: UIView, ConfigurableView {
  
  struct Model {
    let title: NSAttributedString
    let description: NSAttributedString
    let buyButtonModel: TKUIActionButton.Model
    let buyButtonAction: () -> Void
    let receiveButtonModel: TKUIActionButton.Model
    let receiveButtonAction: () -> Void
  }
  
  let titleLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 0
    return label
  }()
  
  let descriptionLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 0
    return label
  }()
  
  let buyButton = TKUIActionButton(category: .secondary, size: .medium)
  let receiveButton = TKUIActionButton(category: .secondary, size: .medium)
  
  private let contentContainer: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  private let buttonsStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.spacing = .interButtonSpace
    return stackView
  }()

  // MARK: - Init

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - ConfigurableView
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title
    descriptionLabel.attributedText = model.description
    
    buyButton.configure(model: model.buyButtonModel)
    buyButton.addTapAction(model.buyButtonAction)
    
    receiveButton.configure(model: model.receiveButtonModel)
    receiveButton.addTapAction(model.receiveButtonAction)
  }
}

// MARK: - Private

private extension HistoryEmptyView {
  func setup() {
    backgroundColor = .Background.page
    
    addSubview(contentContainer)
    
    contentContainer.addArrangedSubview(titleLabel)
    contentContainer.addArrangedSubview(descriptionLabel)
    contentContainer.addArrangedSubview(buttonsStackView)
    
    contentContainer.setCustomSpacing(.titleBottomSpace, after: titleLabel)
    contentContainer.setCustomSpacing(.descriptionBottomSpace, after: descriptionLabel)
    
    buttonsStackView.addArrangedSubview(buyButton)
    buttonsStackView.addArrangedSubview(receiveButton)
    
    contentContainer.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      contentContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
      contentContainer.centerYAnchor.constraint(equalTo: centerYAnchor)
    ])
  }
}

private extension CGFloat {
  static let interButtonSpace: CGFloat = 12
  static let titleBottomSpace: CGFloat = 4
  static let descriptionBottomSpace: CGFloat = 24
}
