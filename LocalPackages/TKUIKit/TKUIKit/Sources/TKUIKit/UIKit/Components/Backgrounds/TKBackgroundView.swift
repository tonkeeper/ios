import UIKit

public final class TKBackgroundView: UIView {

  public enum State {
    case separate
    case topMerge
    case bottomMerge
    case bothMerge
  }

  public var state: TKBackgroundView.State = .separate {
    didSet {
      let path = createPath(for: state)
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

  private lazy var shape: CAShapeLayer = {
    let shape = CAShapeLayer()
    shape.fillColor = UIColor.Background.content.cgColor
    return shape
  }()

  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public override func layoutSubviews() {
    super.layoutSubviews()
    shape.path = createPath(for: state)
  }

  private func setup() {
    layer.addSublayer(shape)
  }
  
  private func createPath(for state: TKBackgroundView.State) -> CGPath {
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
    path.addLine(to: .init(x: frame.maxX, y: frame.maxY - radius))
    if state == .bottomMerge || state == .bothMerge {
      path.addLine(to: .init(x: frame.maxX, y: frame.maxY))
      path.addLine(to: .init(x: frame.maxX - radius, y: frame.maxY))
      path.addLine(to: .init(x: radius, y: frame.maxY))
      path.addLine(to: .init(x: 0, y: frame.maxY))
      path.addLine(to: .init(x: 0, y: frame.maxY - radius))
    } else {
      path.addArc(withCenter: .init(x: frame.maxX - radius, y: frame.maxY - radius), radius: radius, startAngle: 0, endAngle: .pi / 2, clockwise: true)
      path.addLine(to: .init(x: radius, y: frame.maxY))
      path.addArc(withCenter: .init(x: radius, y: frame.maxY - radius), radius: radius, startAngle: .pi / 2 , endAngle: .pi, clockwise: true)
    }
    path.close()
    return path.cgPath
  }
}
