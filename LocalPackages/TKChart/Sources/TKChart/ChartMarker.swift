//
//  ChartMarker.swift
//
//
//  Created by Grigory on 22.9.23..
//

import UIKit
import TKUIKit
import DGCharts

class ChartMarker: Marker {
  var offset: CGPoint = .zero
  var color: UIColor = .Accent.blue
  
  func offsetForDrawing(atPoint: CGPoint) -> CGPoint { .zero }
  
  func refreshContent(entry: DGCharts.ChartDataEntry, highlight: DGCharts.Highlight) {}
  
  func draw(context: CGContext, point: CGPoint) {
    UIColor.clear.setStroke()
    
    let bigCircle = UIBezierPath(ovalIn: CGRect(
      x: point.x - .bigDiameter/2,
      y: point.y - .bigDiameter/2,
      width: .bigDiameter,
      height: .bigDiameter))
    
    let smallCircle = UIBezierPath(ovalIn: CGRect(
      x: point.x - .smallDiameter/2,
      y: point.y - .smallDiameter/2,
      width: .smallDiameter,
      height: .smallDiameter))
    
    color.withAlphaComponent(.bigCircleAlpha).setFill()
    bigCircle.fill()
    bigCircle.stroke()
    
    color.setFill()
    smallCircle.fill()
    smallCircle.stroke()
  }
}
 
private extension CGFloat {
  static let bigDiameter: CGFloat = 40
  static let smallDiameter: CGFloat = 16
  static let bigCircleAlpha: CGFloat = 0.24
}

