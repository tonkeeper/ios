import UIKit

final class ConnectionStatusView: UIView, ConfigurableView {
  
  private let titleLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 1
    return label
  }()
  
  private let loaderView: LoaderView = {
    let loaderView = LoaderView(size: .xSmall)
    loaderView.isHidden = false
    loaderView.color = .Icon.secondary
    loaderView.innerColor = .Icon.tertiary
    return loaderView
  }()
  
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
    titleLabel.attributedText = model.title.attributed(with: .body2, alignment: .center, color: model.titleColor)
    loaderViewContrainer.isHidden = !model.isLoading
    model.isLoading ? loaderView.startAnimation() : loaderView.stopAnimation()
  }
}

private extension ConnectionStatusView {
  func setup() {
    addSubview(stackView)
    loaderViewContrainer.addSubview(loaderView)
    stackView.addArrangedSubview(titleLabel)
    stackView.addArrangedSubview(loaderViewContrainer)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.translatesAutoresizingMaskIntoConstraints = false
    loaderView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor),
      stackView.leftAnchor.constraint(equalTo: leftAnchor),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
      stackView.rightAnchor.constraint(equalTo: rightAnchor),
      
      loaderView.leftAnchor.constraint(equalTo: loaderViewContrainer.leftAnchor),
      loaderView.rightAnchor.constraint(equalTo: loaderViewContrainer.rightAnchor),
      loaderView.centerYAnchor.constraint(equalTo: loaderViewContrainer.centerYAnchor, constant: 2),
    ])
  }
}
