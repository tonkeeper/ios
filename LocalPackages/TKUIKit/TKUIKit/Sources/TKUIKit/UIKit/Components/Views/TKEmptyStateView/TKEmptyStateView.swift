import UIKit
import SnapKit

public final class TKEmptyStateView: UIView, ConfigurableView {
  let titleLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 0
    return label
  }()
  
  let captionLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 0
    return label
  }()
  
  private let containerView = UIView()
  
  private let textContainer: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = 4
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.directionalLayoutMargins = .textContainerPadding
    return stackView
  }()
  
  private let contentContainer: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = 4
    stackView.isLayoutMarginsRelativeArrangement = true
    return stackView
  }()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - ConfigurableView
  
  public struct Model {
    let title: NSAttributedString
    let caption: NSAttributedString?
    let leftButton: TKButton.Configuration?
    let rightButton: TKButton.Configuration?
    
    public init(title: String,
                caption: String?,
                leftButton: TKButton.Configuration?,
                rightButton: TKButton.Configuration?) {
      self.title = title.withTextStyle(
        .h2,
        color: .Text.primary,
        alignment: .center,
        lineBreakMode: .byWordWrapping
      )
      self.caption = caption?.withTextStyle(
        .body1,
        color: .Text.secondary,
        alignment: .center,
        lineBreakMode: .byWordWrapping
      )
      self.leftButton = leftButton
      self.rightButton = rightButton
    }
  }
  
  public func configure(model: Model) {
    titleLabel.attributedText = model.title
    captionLabel.attributedText = model.caption
  }
}

private extension TKEmptyStateView {
  func setup() {
    backgroundColor = .Background.page
    
    addSubview(containerView)
    containerView.addSubview(contentContainer)
    contentContainer.addArrangedSubview(textContainer)
    textContainer.addArrangedSubview(titleLabel)
    textContainer.addArrangedSubview(captionLabel)

    setupConstraints()
  }
  
  func setupConstraints() {
    containerView.snp.makeConstraints { make in
      make.left.right.equalTo(self)
      make.top.bottom.equalTo(safeAreaLayoutGuide)
    }
    
    contentContainer.snp.makeConstraints { make in
      make.left.right.equalTo(containerView)
      make.centerY.equalTo(containerView)
    }
  }
}

private extension NSDirectionalEdgeInsets {
  static var textContainerPadding = NSDirectionalEdgeInsets(
    top: 0,
    leading: 32,
    bottom: 16,
    trailing: 32
  )
}
//
//  struct Model {
//    let title: NSAttributedString
//    let description: NSAttributedString
//    let buyButtonModel: TKUIActionButton.Model
//    let buyButtonAction: () -> Void
//    let receiveButtonModel: TKUIActionButton.Model
//    let receiveButtonAction: () -> Void
//  }
//  
//  let titleLabel: UILabel = {
//    let label = UILabel()
//    label.numberOfLines = 0
//    return label
//  }()
//  
//  let descriptionLabel: UILabel = {
//    let label = UILabel()
//    label.numberOfLines = 0
//    return label
//  }()
//  
//  let buyButton = TKUIActionButton(category: .secondary, size: .medium)
//  let receiveButton = TKUIActionButton(category: .secondary, size: .medium)
//  
//  private let contentContainer: UIStackView = {
//    let stackView = UIStackView()
//    stackView.axis = .vertical
//    return stackView
//  }()
//  
//  private let buttonsStackView: UIStackView = {
//    let stackView = UIStackView()
//    stackView.axis = .horizontal
//    stackView.spacing = .interButtonSpace
//    return stackView
//  }()
//
//  // MARK: - Init
//
//  override init(frame: CGRect) {
//    super.init(frame: frame)
//    setup()
//  }
//  
//  required init?(coder: NSCoder) {
//    fatalError("init(coder:) has not been implemented")
//  }
//  
//  // MARK: - ConfigurableView
//  
//  func configure(model: Model) {
//    titleLabel.attributedText = model.title
//    descriptionLabel.attributedText = model.description
//    
//    buyButton.configure(model: model.buyButtonModel)
//    buyButton.addTapAction(model.buyButtonAction)
//    
//    receiveButton.configure(model: model.receiveButtonModel)
//    receiveButton.addTapAction(model.receiveButtonAction)
//  }
//}
//
//// MARK: - Private
//
//private extension HistoryEmptyView {
//  func setup() {
//    backgroundColor = .Background.page
//    
//    addSubview(contentContainer)
//    
//    contentContainer.addArrangedSubview(titleLabel)
//    contentContainer.addArrangedSubview(descriptionLabel)
//    contentContainer.addArrangedSubview(buttonsStackView)
//    
//    contentContainer.setCustomSpacing(.titleBottomSpace, after: titleLabel)
//    contentContainer.setCustomSpacing(.descriptionBottomSpace, after: descriptionLabel)
//    
//    buttonsStackView.addArrangedSubview(buyButton)
//    buttonsStackView.addArrangedSubview(receiveButton)
//    
//    contentContainer.translatesAutoresizingMaskIntoConstraints = false
//    NSLayoutConstraint.activate([
//      contentContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
//      contentContainer.centerYAnchor.constraint(equalTo: centerYAnchor)
//    ])
//  }
//}
//
//private extension CGFloat {
//  static let interButtonSpace: CGFloat = 12
//  static let titleBottomSpace: CGFloat = 4
//  static let descriptionBottomSpace: CGFloat = 24
//}
