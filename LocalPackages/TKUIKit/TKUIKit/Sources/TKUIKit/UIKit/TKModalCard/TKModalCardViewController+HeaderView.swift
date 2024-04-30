import UIKit

extension TKModalCardViewController {
  final class HeaderView: UIView, ConfigurableView {
    private weak var viewController: UIViewController?
    
    private let stackView: UIStackView = {
      let stackView = UIStackView()
      stackView.axis = .vertical
      return stackView
    }()
    
    // MARK: - Init
    
    init(viewController: UIViewController) {
      self.viewController = viewController
      super.init(frame: .zero)
      setup()
    }
    
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - ConfigurableView
    
    func configure(model: Configuration.Header) {
      stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
      guard let viewController = viewController else { return }
      TKModalCardViewBuilder.buildViews(items: model.items, viewController: viewController).forEach { view in
        stackView.addArrangedSubview(view)
      }
    }
  }
}

private extension TKModalCardViewController.HeaderView {
  func setup() {
    addSubview(stackView)
    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor),
      stackView.leftAnchor.constraint(equalTo: leftAnchor),
      stackView.rightAnchor.constraint(equalTo: rightAnchor),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])
  }
}

private extension CGFloat {
  static let descriptionBottomSpace: CGFloat = 4
}
