import UIKit
import TKUIKit

final class ActivityLargeTitleView: UIView {
  
  var title: String? {
    get {
      label.text
    }
    set {
      label.text = newValue
    }
  }
  
  var isLoading = false {
    didSet {
      didUpdateIsLoading()
    }
  }
  
  private let label: UILabel = {
    let label = UILabel()
    label.font = TKTextStyle.h1.font
    label.textColor = .Text.primary
    return label
  }()
  private let loaderView = TKLoaderView(size: .medium, style: .secondary)
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension ActivityLargeTitleView {
  func setup() {
    loaderView.alpha = 0
    
    addSubview(label)
    addSubview(loaderView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    label.translatesAutoresizingMaskIntoConstraints = false
    loaderView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      label.leftAnchor.constraint(equalTo: leftAnchor),
      label.topAnchor.constraint(equalTo: topAnchor),
      label.bottomAnchor.constraint(equalTo: bottomAnchor),
      
      loaderView.centerYAnchor.constraint(equalTo: label.centerYAnchor, constant: 3),
      loaderView.leftAnchor.constraint(equalTo: label.rightAnchor, constant: 8),
      loaderView.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
  
  func didUpdateIsLoading() {
    let alpha: CGFloat = isLoading ? 1 : 0
    UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut) {
      self.loaderView.alpha = alpha
    } completion: { _ in
      self.loaderView.isLoading = self.isLoading
    }
  }
}
