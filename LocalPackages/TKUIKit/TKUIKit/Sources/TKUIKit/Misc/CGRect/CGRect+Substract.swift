import CoreGraphics

public extension CGRect {
  func substract(rect: CGRect, edge: CGRectEdge) -> CGRect {
    guard self.intersects(rect) else { return self }
    let intersection = self.intersection(rect)
    let chopAmount: CGFloat
    switch edge {
    case .minXEdge, .maxXEdge:
      chopAmount = intersection.size.width
    case .minYEdge, .maxYEdge:
      chopAmount = intersection.size.height
    }
    let result = self.divided(atDistance: chopAmount, from: edge)
    return result.remainder
  }
}
