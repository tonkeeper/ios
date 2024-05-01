import UIKit

public final class TKPullableCardHeaderView: UIView, ConfigurableView {
  
  var didTapCloseButton: (() -> Void)?
  
  private let titleLabel = UILabel()
  private let subtitleLabel = UILabel()
  private let closeButton = TKButton.iconHeaderButton()
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
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
  
  public struct Model {
    let title: String
    let subtitle: NSAttributedString
    
    public init(title: String, subtitle: NSAttributedString) {
      self.title = title
      self.subtitle = subtitle
    }
    
    public init(title: String, subtitle: String) {
      self.title = title
      self.subtitle = subtitle.withTextStyle(.body2, color: .Text.secondary, alignment: .left)
    }
  }
  
  public func configure(model: Model) {
    titleLabel.attributedText = model.title.withTextStyle(
      .h3, 
      color: .Text.primary,
      alignment: .left
    )
    subtitleLabel.attributedText = model.subtitle
  }
}

private extension TKPullableCardHeaderView {
  func setup() {
    closeButton.configure(
      model: TKHeaderButton<TKHeaderButtonIconContent>.Model(
        contentModel: TKHeaderButtonIconContent.Model(
          image: .TKUIKit.Icons.Button.Header.close
        ),
        action: { [weak self] in
          self?.didTapCloseButton?()
        }
      )
    )
    
    addSubview(closeButton)
    addSubview(stackView)
    
    stackView.addArrangedSubview(titleLabel)
    stackView.addArrangedSubview(subtitleLabel)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.translatesAutoresizingMaskIntoConstraints = false
    closeButton.translatesAutoresizingMaskIntoConstraints = false
    
    stackView.setContentHuggingPriority(.defaultLow, for: .horizontal)
    titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
    subtitleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
    
    NSLayoutConstraint.activate([
      closeButton.topAnchor.constraint(equalTo: topAnchor, constant: 16),
      closeButton.rightAnchor.constraint(equalTo: rightAnchor, constant: -16),
      closeButton.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor).withPriority(.defaultHigh),
      closeButton.widthAnchor.constraint(equalToConstant: 32),
      closeButton.heightAnchor.constraint(equalToConstant: 32),
      closeButton.bottomAnchor.constraint(equalTo: bottomAnchor)
        .withPriority(.defaultHigh),
      
      stackView.topAnchor.constraint(equalTo: topAnchor, constant: 18),
      stackView.leftAnchor.constraint(equalTo: leftAnchor, constant: 16),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18),
      stackView.rightAnchor.constraint(equalTo: closeButton.leftAnchor, constant: -24).withPriority(.defaultHigh)
    ])
  }
}
