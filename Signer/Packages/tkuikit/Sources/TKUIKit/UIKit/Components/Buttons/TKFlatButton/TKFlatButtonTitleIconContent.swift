import UIKit

public final class TKFlatButtonTitleIconContent: UIView, TKFlatButtonContent {

  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = 4
    stackView.directionalLayoutMargins = .init(top: 16, leading: 12, bottom: 16, trailing: 12)
    stackView.isLayoutMarginsRelativeArrangement = true
    return stackView
  }()
  
  let titleLabel = UILabel()
  let iconImageView = UIImageView()

  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - TKFlatButtonContent
  
  public var buttonState: TKButtonState = .normal {
    didSet {
      didUpdateState()
    }
  }

  // MARK: - ConfigurableView
  
  public struct Model {
    let title: String
    let image: UIImage?
    
    public init(title: String,
                image: UIImage?) {
      self.title = title
      self.image = image
    }
  }
  
  public func configure(model: Model) {
    titleLabel.attributedText = model.title
      .withTextStyle(.label3, color: .Text.secondary, alignment: .center)
    iconImageView.image = model.image
  }
}

private extension TKFlatButtonTitleIconContent {
  func setup() {
    iconImageView.contentMode = .center
    iconImageView.tintColor = .Icon.primary
    
    addSubview(stackView)
    stackView.addArrangedSubview(iconImageView)
    stackView.addArrangedSubview(titleLabel)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor),
      stackView.leftAnchor.constraint(equalTo: leftAnchor),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor).withPriority(.defaultHigh),
      stackView.rightAnchor.constraint(equalTo: rightAnchor).withPriority(.defaultHigh)
    ])
  }
  
  func didUpdateState() {
    switch buttonState {
    case .normal:
      stackView.alpha = 1
    case .highlighted:
      stackView.alpha = 0.45
    case .disabled:
      stackView.alpha = 0.45
    }
  }
}
