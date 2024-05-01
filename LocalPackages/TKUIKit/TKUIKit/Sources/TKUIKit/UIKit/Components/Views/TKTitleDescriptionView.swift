import UIKit

public final class TKTitleDescriptionView: UIView, ConfigurableView {
  
  public enum Size {
    case big
    case medium
    
    var titleTextStyle: TKTextStyle {
      switch self {
      case .big:
        return .h2
      case .medium:
        return .h3
      }
    }
  }
  
  public var size: Size {
    didSet {
      didUpdateSize()
    }
  }
  
  public var padding: NSDirectionalEdgeInsets = .zero {
    didSet {
      stackViewTopAnchor?.constant = padding.top
      stackViewLeftAnchor?.constant = padding.leading
      stackViewBottomAnchor?.constant = -padding.bottom
      stackViewRightAnchor?.constant = -padding.trailing
      stackViewWidthAnchor?.constant = -(padding.leading + padding.trailing)
    }
  }
  
  private let titleLabel = UILabel()
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  private var stackViewTopAnchor: NSLayoutConstraint?
  private var stackViewLeftAnchor: NSLayoutConstraint?
  private var stackViewBottomAnchor: NSLayoutConstraint?
  private var stackViewRightAnchor: NSLayoutConstraint?
  private var stackViewWidthAnchor: NSLayoutConstraint?

  public init(size: Size) {
    self.size = size
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - ConfigurableView
  
  public struct Model {
    let title: String
    let topDescription: String?
    let bottomDescription: String?
    
    public init(title: String,
                topDescription: String? = nil,
                bottomDescription: String? = nil) {
      self.title = title
      self.topDescription = topDescription
      self.bottomDescription = bottomDescription
    }
  }
  
  public func configure(model: Model) {
    stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    
    if let topDescription = model.topDescription {
      let topDescriptionLabel = UILabel()
      topDescriptionLabel.numberOfLines = 0
      topDescriptionLabel.attributedText = topDescription
        .withTextStyle(.body1, color: .Text.secondary, alignment: .center)
      stackView.addArrangedSubview(topDescriptionLabel)
      stackView.setCustomSpacing(4, after: topDescriptionLabel)
    }
    
    titleLabel.attributedText = model.title
      .withTextStyle(size.titleTextStyle, color: .Text.primary, alignment: .center, lineBreakMode: .byWordWrapping)
    stackView.addArrangedSubview(titleLabel)
    
    if let bottomDescription = model.bottomDescription {
      let bottomDescriptionLabel = UILabel()
      bottomDescriptionLabel.numberOfLines = 0
      bottomDescriptionLabel.attributedText = bottomDescription
        .withTextStyle(.body1, color: .Text.secondary, alignment: .center)
      stackView.addArrangedSubview(bottomDescriptionLabel)
      stackView.setCustomSpacing(4, after: titleLabel)
    }
    setNeedsLayout()
    invalidateIntrinsicContentSize()
  }
}

private extension TKTitleDescriptionView {
  func setup() {
    titleLabel.numberOfLines = 0
    
    addSubview(stackView)
    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.translatesAutoresizingMaskIntoConstraints = false
    
    stackView.setContentCompressionResistancePriority(.required, for: .vertical)
    stackView.setContentHuggingPriority(.required, for: .vertical)
    
    stackViewTopAnchor = stackView.topAnchor.constraint(equalTo: topAnchor)
    stackViewLeftAnchor = stackView.leftAnchor.constraint(equalTo: leftAnchor)
    stackViewRightAnchor = stackView.rightAnchor.constraint(equalTo: rightAnchor)
      .withPriority(.defaultHigh)
    stackViewBottomAnchor = stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
      .withPriority(.defaultHigh)
    stackViewWidthAnchor = stackView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor)

    stackViewTopAnchor?.isActive = true
    stackViewLeftAnchor?.isActive = true
    stackViewRightAnchor?.isActive = true
    stackViewBottomAnchor?.isActive = true
    stackViewWidthAnchor?.isActive = true
  }
  
  func didUpdateSize() {
    titleLabel.attributedText = titleLabel.text?
      .withTextStyle(size.titleTextStyle, color: .Text.primary)
  }
}

