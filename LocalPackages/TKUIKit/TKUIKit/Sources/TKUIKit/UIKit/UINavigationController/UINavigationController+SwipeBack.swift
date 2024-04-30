import UIKit

public extension UINavigationController {
  func fixInteractivePopGestureRecognizer(delegate: UIGestureRecognizerDelegate) {
    guard
      let popGestureRecognizer = interactivePopGestureRecognizer,
      let targets = popGestureRecognizer.value(forKey: "targets") as? NSMutableArray,
      let gestureRecognizers = view.gestureRecognizers,
      targets.count > 0
    else { return }

    if viewControllers.count == 1 {
      for recognizer in gestureRecognizers where recognizer is PanDirectionGestureRecognizer {
        view.removeGestureRecognizer(recognizer)
        popGestureRecognizer.isEnabled = false
        recognizer.delegate = nil
      }
    } else {
      if gestureRecognizers.count == 1 {
        let gestureRecognizer = PanDirectionGestureRecognizer(axis: .horizontal, direction: .right)
        gestureRecognizer.cancelsTouchesInView = true
        gestureRecognizer.setValue(targets, forKey: "targets")
        gestureRecognizer.require(toFail: popGestureRecognizer)
        gestureRecognizer.delegate = delegate
        popGestureRecognizer.isEnabled = true

        view.addGestureRecognizer(gestureRecognizer)
      }
    }
  }
}

public enum PanAxis {
  case vertical
  case horizontal
}

public enum PanDirection {
  case left
  case right
  case up
  case down
  case normal
}

public class PanDirectionGestureRecognizer: UIPanGestureRecognizer {
  let axis: PanAxis
  let direction: PanDirection

  public init(axis: PanAxis, direction: PanDirection = .normal, target: AnyObject? = nil, action: Selector? = nil) {
    self.axis = axis
    self.direction = direction
    super.init(target: target, action: action)
  }

  override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
    super.touchesMoved(touches, with: event)

    if state == .began {
      let vel = velocity(in: view)
      switch axis {
      case .horizontal where abs(vel.y) > abs(vel.x):
        state = .cancelled
      case .vertical where abs(vel.x) > abs(vel.y):
        state = .cancelled
      default:
        break
      }

      let isIncrement = axis == .horizontal ? vel.x > 0 : vel.y > 0

      switch direction {
      case .left where isIncrement:
        state = .cancelled
      case .right where !isIncrement:
        state = .cancelled
      case .up where isIncrement:
        state = .cancelled
      case .down where !isIncrement:
        state = .cancelled
      default:
        break
      }
    }
  }
}

