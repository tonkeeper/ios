import UIKit

extension TKModalCardViewController {
  final class ActionBar: UIView, ConfigurableView {
    private weak var viewController: UIViewController?
    private let contentStackView: UIStackView = {
      let stackView = UIStackView()
      stackView.axis = .vertical
      return stackView
    }()
    private let backgroundView: UIView = {
      let view = UIView()
      view.backgroundColor = .Background.page
      return view
    }()
    private let loaderView = TKLoaderView(size: .medium, style: .secondary)
    private let resultView = TKResultView(state: .success)
    
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
    
    func configure(model: Configuration.ActionBar) {
      contentStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
      guard let viewController = viewController else { return }
      let views = TKModalCardViewBuilder.buildViews(
        items: model.items,
        viewController: viewController) { [weak self] state in
          switch state {
          case .none:
            self?.hideLoader()
            self?.hideResult()
            self?.showContent()
          case .activity:
            self?.hideResult()
            self?.hideContent()
            self?.showLoader()
          case .result(let isSuccess):
            self?.hideLoader()
            self?.hideContent()
            self?.showResult(isSuccess: isSuccess)
          }
        }
      views.forEach { view in
        contentStackView.addArrangedSubview(view)
      }
    }
  }
}

private extension TKModalCardViewController.ActionBar {
  func setup() {
    addSubview(backgroundView)
    addSubview(contentStackView)
    addSubview(loaderView)
    addSubview(resultView)
    
    loaderView.isHidden = true
    resultView.isHidden = true
    
    setupConstraints()
  }
  
  func setupConstraints() {
    contentStackView.translatesAutoresizingMaskIntoConstraints = false
    backgroundView.translatesAutoresizingMaskIntoConstraints = false
    loaderView.translatesAutoresizingMaskIntoConstraints = false
    resultView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      backgroundView.topAnchor.constraint(equalTo: topAnchor),
      backgroundView.leftAnchor.constraint(equalTo: leftAnchor),
      backgroundView.rightAnchor.constraint(equalTo: rightAnchor),
      backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
      
      contentStackView.topAnchor.constraint(equalTo: topAnchor),
      contentStackView.leftAnchor.constraint(equalTo: leftAnchor),
      contentStackView.rightAnchor.constraint(equalTo: rightAnchor).withPriority(.defaultHigh),
      contentStackView.bottomAnchor.constraint(equalTo: bottomAnchor).withPriority(.defaultHigh),
      
      loaderView.topAnchor.constraint(equalTo: contentStackView.topAnchor),
      loaderView.leftAnchor.constraint(equalTo: contentStackView.leftAnchor),
      loaderView.bottomAnchor.constraint(equalTo: contentStackView.bottomAnchor),
      loaderView.rightAnchor.constraint(equalTo: contentStackView.rightAnchor),
      
      resultView.topAnchor.constraint(equalTo: contentStackView.topAnchor),
      resultView.leftAnchor.constraint(equalTo: contentStackView.leftAnchor),
      resultView.bottomAnchor.constraint(equalTo: contentStackView.bottomAnchor),
      resultView.rightAnchor.constraint(equalTo: contentStackView.rightAnchor)
    ])
  }
  
  func showContent() {
    contentStackView.isHidden = false
  }
  
  func hideContent() {
    contentStackView.isHidden = true
  }
  
  func showLoader() {
    loaderView.isLoading = true
    loaderView.isHidden = false
  }
  
  func hideLoader() {
    loaderView.isLoading = false
    loaderView.isHidden = true
  }
  
  func showResult(isSuccess: Bool) {
    resultView.isHidden = false
    resultView.state = isSuccess ? .success : .failure
  }
  
  func hideResult() {
    resultView.isHidden = true
  }
}
