import UIKit

public final class TKBackgroundView: UIView {

  public enum State {
    case separate
    case topMerge
    case bottomMerge
    case bothMerge
  }

  private var state: TKBackgroundView.State = .separate

  public func setState(_ state: TKBackgroundView.State, animated: Bool = true) {
    self.state = state
    let topPath = createTopPath(for: state)
    let bottomPath = createBottomPath(for: state)

    if animated {
      animatePath(path: topPath, shape: topShape)
      animatePath(path: bottomPath, shape: bottomShape)
    } else {
      topShape.path = topPath
      bottomShape.path = bottomPath
    }
  }

  private lazy var topShape: CAShapeLayer = {
    let shape = CAShapeLayer()
    shape.fillColor = UIColor.Background.content.cgColor
    return shape
  }()

  private lazy var bottomShape: CAShapeLayer = {
    let shape = CAShapeLayer()
    shape.fillColor = UIColor.Background.content.cgColor
    return shape
  }()

  private let topView = UIView()
  private let centerView = UIView()
  private let bottomView = UIView()

  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public override func layoutSubviews() {
    super.layoutSubviews()
    topShape.path = createTopPath(for: state)
    topView.frame = CGRectMake(0, 0, bounds.width, 8)

    centerView.frame = CGRectMake(0, 8, bounds.width, bounds.height - 16)

    bottomShape.path = createBottomPath(for: state)
    bottomView.frame = CGRectMake(0, bounds.height - 8, bounds.width, 8)
  }

  private func setup() {
    addSubview(topView)
    addSubview(centerView)
    addSubview(bottomView)

    centerView.backgroundColor = .Background.content
    
    topView.layer.addSublayer(topShape)
    bottomView.layer.addSublayer(bottomShape)
  }
  
  private func createTopPath(for state: TKBackgroundView.State) -> CGPath {
    let path = UIBezierPath()
    let radius: CGFloat = 8
    path.move(to: .init(x: 0, y: radius))
    
    if state == .topMerge || state == .bothMerge {
      path.addLine(to: .init(x: 0, y: 0))
      path.addLine(to: .init(x: radius, y: 0))
      path.addLine(to: .init(x: frame.maxX - radius, y: 0))
      path.addLine(to: .init(x: frame.maxX, y: 0))
      path.addLine(to: .init(x: frame.maxX, y: radius))
    } else {
      path.addArc(withCenter: .init(x: radius, y: radius), radius: radius, startAngle: .pi, endAngle: .pi * 3/2, clockwise: true)
      path.addLine(to: .init(x: frame.maxX - radius, y: 0))
      path.addArc(withCenter: .init(x: frame.maxX - radius, y: radius), radius: radius, startAngle: -.pi / 2, endAngle: 0, clockwise: true)
    }
    path.close()
    return path.cgPath
  }

  private func createBottomPath(for state: TKBackgroundView.State) -> CGPath {
    let path = UIBezierPath()
    let radius: CGFloat = 8
    path.move(to: .init(x: frame.maxX, y: 0))
    
    if state == .bottomMerge || state == .bothMerge {
      path.addLine(to: .init(x: frame.maxX, y: radius))
      path.addLine(to: .init(x: frame.maxX - radius, y: radius))
      path.addLine(to: .init(x: radius, y: radius))
      path.addLine(to: .init(x: 0, y: radius))
      path.addLine(to: .init(x: 0, y: 0))
    } else {
      path.addArc(withCenter: .init(x: frame.maxX - radius, y: 0), radius: radius, startAngle: 0, endAngle: .pi / 2, clockwise: true)
      path.addLine(to: .init(x: radius, y: radius))
      path.addArc(withCenter: .init(x: radius, y: 0), radius: radius, startAngle: .pi / 2 , endAngle: .pi, clockwise: true)
    }
    path.close()
    return path.cgPath
  }

  private func animatePath(path: CGPath, shape: CAShapeLayer) {
    let animation = CABasicAnimation(keyPath: "path")
    animation.duration = 0.5
    animation.fromValue = (shape.presentation())?.path ?? shape.path
    animation.toValue = path
    animation.timingFunction = .init(name: .easeIn)
    animation.isRemovedOnCompletion = true
    animation.fillMode = .forwards
    shape.add(animation, forKey: "path")
    shape.path = path
  }
}
