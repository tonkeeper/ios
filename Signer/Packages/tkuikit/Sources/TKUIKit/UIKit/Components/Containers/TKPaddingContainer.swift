import UIKit

public final class TKPaddingContainer: UIView {
  
  public static func textInputContainer() -> TKPaddingContainer {
    TKPaddingContainer(padding: .init(top: 16, leading: 32, bottom: 16, trailing: 32))
  }
  
  public static func buttonContainer() -> TKPaddingContainer {
    TKPaddingContainer(padding: .init(top: 16, leading: 32, bottom: 32, trailing: 32))
  }
  
  public var padding: NSDirectionalEdgeInsets {
    get {
      directionalLayoutMargins
    }
    set {
      directionalLayoutMargins = newValue
    }
  }
  
  public var contentView: UIView? {
    didSet {
      didSetContentView()
    }
  }
  
  public init(padding: NSDirectionalEdgeInsets = .zero) {
    super.init(frame: .zero)
    directionalLayoutMargins = padding
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension TKPaddingContainer {
  func didSetContentView() {
    subviews.forEach { $0.removeFromSuperview() }
    guard let contentView = contentView else { return }
    addSubview(contentView)
    contentView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      contentView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
      contentView.leftAnchor.constraint(equalTo: layoutMarginsGuide.leftAnchor),
      contentView.rightAnchor.constraint(equalTo: layoutMarginsGuide.rightAnchor),
      contentView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor)
    ])
  }
}
