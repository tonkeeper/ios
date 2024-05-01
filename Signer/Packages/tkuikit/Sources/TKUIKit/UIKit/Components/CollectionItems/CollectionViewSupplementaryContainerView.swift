import UIKit

public final class CollectionViewSupplementaryContainerView: UICollectionReusableView {
  public static var reuseIdentifier: String {
    String(describing: Self.self)
  }
  
  private var contentView: UIView?
  
  public func setContentView(_ contentView: UIView?) {
    self.contentView?.removeFromSuperview()
    self.contentView = contentView
    
    guard let contentView = contentView else {
      return
    }
    addSubview(contentView)
    contentView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      contentView.topAnchor.constraint(equalTo: topAnchor),
      contentView.leftAnchor.constraint(equalTo: leftAnchor),
      contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
      contentView.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
}
