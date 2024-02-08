import UIKit
import TKUIKit

final class HistoryListFooterView: UICollectionReusableView, ReusableView, TKCollectionViewSupplementaryContainerViewContentView {
  enum State {
    case none
    case loading
    case error(title: String?, retryButtonAction: () -> Void)
  }
  
  var state: State = .none {
    didSet {
      didChangeState()
    }
  }

  private let loaderView = TKLoaderView(size: .medium, style: .primary)
  private let retryButton = TKUIActionButton(category: .tertiary, size: .small)
    
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    loaderView.sizeToFit()
    loaderView.center = CGPoint(x: bounds.midX, y: bounds.midY)
  }
  
  struct Model {
    let state: State
  }
  
  func configure(model: Model) {
    self.state = model.state
  }
}

private extension HistoryListFooterView {
  func setup() {
    addSubview(loaderView)
    addSubview(retryButton)
    
    setupConstraints()
    
    didChangeState()
  }
  
  func setupConstraints() {
    retryButton.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      retryButton.centerXAnchor.constraint(equalTo: centerXAnchor),
      retryButton.centerYAnchor.constraint(equalTo: centerYAnchor),
    ])
  }
  
  func didChangeState() {
    switch state {
    case .none:
      loaderView.isLoading = false
      loaderView.isHidden = true
      retryButton.isHidden = true
    case .loading:
      loaderView.isLoading = true
      loaderView.isHidden = false
      retryButton.isHidden = true
    case .error(let title, let retryButtonAction):
      loaderView.isLoading = false
      loaderView.isHidden = true
      retryButton.isHidden = false
      retryButton.configure(model: TKUIButtonTitleIconContentView.Model(title: title))
      retryButton.addTapAction(retryButtonAction)
    }
    setNeedsLayout()
  }
}

