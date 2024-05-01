import UIKit

public final class TKHeaderButtonTitleContent: UIView, TKHeaderButtonContent {
  private let label = UILabel()
  private var foregroundColor: UIColor = .Button.secondaryForeground
  
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
    .init(top: 6, leading: 12, bottom: 6, trailing: 12)
  }
  
  public func setForegroudColor(_ color: UIColor) {
    self.foregroundColor = color
    label.attributedText = label.text?.withTextStyle(.label2, color: color, alignment: .center)
  }
  
  // MARK: - ConfigurableView
  
  public struct Model {
    let title: String
    
    public init(title: String) {
      self.title = title
    }
  }
  
  public func configure(model: Model) {
    label.attributedText = model.title
      .withTextStyle(.label2, color: foregroundColor, alignment: .center)
  }
}

private extension TKHeaderButtonTitleContent {
  func setup() {
    addSubview(label)
    setupConstraints()
  }
  
  func setupConstraints() {
    label.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      label.topAnchor.constraint(equalTo: topAnchor),
      label.leftAnchor.constraint(equalTo: leftAnchor),
      label.bottomAnchor.constraint(equalTo: bottomAnchor).withPriority(.defaultHigh),
      label.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
}
