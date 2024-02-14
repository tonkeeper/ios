import UIKit
import TKUIKit

final class HistoryEventDetailsView: UIView {
  
  private let modalContentContainer = UIView()
  
  // MARK: - Init

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - Content
  
  func embedContent(_ view: UIView) {
    modalContentContainer.addSubview(view)
    
    view.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      view.topAnchor.constraint(equalTo: modalContentContainer.topAnchor),
      view.leftAnchor.constraint(equalTo: modalContentContainer.leftAnchor),
      view.bottomAnchor.constraint(equalTo: modalContentContainer.bottomAnchor),
      view.rightAnchor.constraint(equalTo: modalContentContainer.rightAnchor)
    ])
  }
}

// MARK: - Private

private extension HistoryEventDetailsView {
  func setup() {
    addSubview(modalContentContainer)
    
    modalContentContainer.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      modalContentContainer.topAnchor.constraint(equalTo: topAnchor),
      modalContentContainer.leftAnchor.constraint(equalTo: leftAnchor),
      modalContentContainer.rightAnchor.constraint(equalTo: rightAnchor).withPriority(.defaultHigh),
      modalContentContainer.bottomAnchor.constraint(equalTo: bottomAnchor).withPriority(.defaultHigh)
    ])
  }
}
