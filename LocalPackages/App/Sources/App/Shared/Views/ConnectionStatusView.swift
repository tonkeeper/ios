import UIKit
import TKUIKit

final class ConnectionStatusView: UIView, ConfigurableView {
  
  private let titleLabel = UILabel()
  private let loaderView = TKLoaderView(size: .xSmall, style: .secondary)
  private let loaderViewContrainer: UIView = {
    let view = UIView()
    view.isHidden = true
    return view
  }()
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.spacing = 4
    return stackView
  }()
  
  private let containerView = UIView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - ConfigurableView
  
  struct Model {
    let title: String
    let titleColor: UIColor
    let isLoading: Bool
  }
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title.withTextStyle(
      .body2,
      color: model.titleColor,
      alignment: .center,
      lineBreakMode: .byWordWrapping
    )
    loaderViewContrainer.isHidden = !model.isLoading
    if loaderView.isLoading != model.isLoading {
      loaderView.isLoading = model.isLoading
    }
  }
}

private extension ConnectionStatusView {
  func setup() {
    addSubview(containerView)
    containerView.addSubview(stackView)
    loaderViewContrainer.addSubview(loaderView)
    stackView.addArrangedSubview(titleLabel)
    stackView.addArrangedSubview(loaderViewContrainer)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    titleLabel.setContentHuggingPriority(.required, for: .horizontal)
    
    containerView.translatesAutoresizingMaskIntoConstraints = false
    stackView.translatesAutoresizingMaskIntoConstraints = false
    loaderView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      containerView.topAnchor.constraint(equalTo: topAnchor),
      containerView.leftAnchor.constraint(equalTo: leftAnchor),
      containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
      containerView.rightAnchor.constraint(equalTo: rightAnchor),
      
      stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
      stackView.leftAnchor.constraint(greaterThanOrEqualTo: containerView.leftAnchor),
      stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
      stackView.rightAnchor.constraint(lessThanOrEqualTo: containerView.rightAnchor),
      stackView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
      
      loaderView.leftAnchor.constraint(equalTo: loaderViewContrainer.leftAnchor),
      loaderView.rightAnchor.constraint(equalTo: loaderViewContrainer.rightAnchor),
      loaderView.centerYAnchor.constraint(equalTo: loaderViewContrainer.centerYAnchor, constant: 0),
    ])
  }
}
