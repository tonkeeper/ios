import UIKit
import TKUIKit

final class HistoryListPaginationCell: UICollectionViewCell, ConfigurableView {
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
  private let retryButton = TKButton(configuration: .actionButtonConfiguration(category: .tertiary, size: .small))
    
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

private extension HistoryListPaginationCell {
  func setup() {
    contentView.addSubview(loaderView)
    contentView.addSubview(retryButton)
    
    setupConstraints()
    
    didChangeState()
  }
  
  func setupConstraints() {
    retryButton.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      retryButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
      retryButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
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
      retryButton.configuration.content.title = .plainString(title ?? "")
      retryButton.configuration.action = retryButtonAction
    }
    setNeedsLayout()
  }
}

