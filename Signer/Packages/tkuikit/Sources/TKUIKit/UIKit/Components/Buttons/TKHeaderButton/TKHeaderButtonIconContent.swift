import UIKit

public final class TKHeaderButtonIconContent: UIView, TKHeaderButtonContent {
  private let imageView = UIImageView()
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - TKHeaderButtonContent
  
  public var padding: NSDirectionalEdgeInsets {
    .init(top: 8, leading: 8, bottom: 8, trailing: 8)
  }
  
  public func setForegroudColor(_ color: UIColor) {
    imageView.tintColor = color
  }
  
  // MARK: - ConfigurableView
  
  public struct Model {
    let image: UIImage?
    
    public init(image: UIImage?) {
      self.image = image
    }
  }
  
  public func configure(model: Model) {
    imageView.image = model.image
  }
}

private extension TKHeaderButtonIconContent {
  func setup() {
    setContentHuggingPriority(.required, for: .vertical)
    setContentHuggingPriority(.required, for: .horizontal)
    
    imageView.contentMode = .center
    addSubview(imageView)
    setupConstraints()
  }
  
  func setupConstraints() {
    imageView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      imageView.topAnchor.constraint(equalTo: topAnchor),
      imageView.leftAnchor.constraint(equalTo: leftAnchor),
      imageView.bottomAnchor.constraint(equalTo: bottomAnchor).withPriority(.defaultHigh),
      imageView.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
}
