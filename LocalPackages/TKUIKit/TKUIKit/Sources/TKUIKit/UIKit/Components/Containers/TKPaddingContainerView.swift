import UIKit

public final class TKPaddingContainerView: UIView {
  
  public var padding: UIEdgeInsets = .zero {
    didSet {
      stackViewTopAnchor.constant = padding.top
      stackViewLeftAnchor.constant = padding.left
      stackViewBottomAnchor.constant = -padding.bottom
      stackViewRightAnchor.constant = -padding.right
      stackViewWidthAnchor.constant = -(padding.left + padding.right)
    }
  }
  
  public var spacing: CGFloat = 0 {
    didSet {
      stackView.spacing = spacing
    }
  }
  
  public var backgroundView: UIView? {
    didSet {
      oldValue?.removeFromSuperview()
      setupBackgroundView()
    }
  }
  
  let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = 16
    return stackView
  }()
  
  private lazy var stackViewTopAnchor: NSLayoutConstraint = {
    stackView.topAnchor.constraint(equalTo: topAnchor).withPriority(.defaultHigh)
  }()
  private lazy var stackViewLeftAnchor: NSLayoutConstraint = {
    stackView.leftAnchor.constraint(equalTo: leftAnchor).withPriority(.defaultHigh)
  }()
  private lazy var stackViewRightAnchor: NSLayoutConstraint = {
    stackView.rightAnchor.constraint(equalTo: rightAnchor).withPriority(.defaultHigh)
  }()
  private lazy var stackViewBottomAnchor: NSLayoutConstraint = {
    stackView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor).withPriority(.defaultHigh)
  }()
  private lazy var stackViewWidthAnchor: NSLayoutConstraint = {
    stackView.widthAnchor.constraint(equalTo: widthAnchor).withPriority(.defaultHigh)
  }()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public func setViews(_ views: [UIView]) {
    stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    
    views.forEach { stackView.addArrangedSubview($0) }
  }
}

private extension TKPaddingContainerView {
  func setup() {
    addSubview(stackView)
    
    stackView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      stackViewTopAnchor,
      stackViewLeftAnchor,
      stackViewBottomAnchor,
      stackViewRightAnchor,
      stackViewWidthAnchor
    ])
  }
  
  func setupBackgroundView() {
    guard let backgroundView = backgroundView else { return }
    insertSubview(backgroundView, belowSubview: stackView)
    backgroundView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      backgroundView.topAnchor.constraint(equalTo: topAnchor).withPriority(.defaultHigh),
      backgroundView.leftAnchor.constraint(equalTo: leftAnchor).withPriority(.defaultHigh),
      backgroundView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor).withPriority(.defaultHigh),
      backgroundView.rightAnchor.constraint(equalTo: rightAnchor).withPriority(.defaultHigh),
    ])
  }
}

public extension TKPaddingContainerView {
  static var buttonsContainerPadding: UIEdgeInsets {
    UIEdgeInsets(top: 16, left: 32, bottom: 32, right: 32)
  }
  static var buttonsContainerSpacing: CGFloat {
    16
  }
}
