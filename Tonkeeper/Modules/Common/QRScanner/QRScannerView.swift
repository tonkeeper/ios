//
//  QRScannerView.swift
//  Tonkeeper
//
//  Created by Grigory on 24.5.23..
//

import UIKit

final class QRScannerView: UIView {
  
  let videoContainerView = UIView()
  let overlayView = UIView()
  
  private let maskLayer = CAShapeLayer()
  private let cornersLayer = CAShapeLayer()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    videoContainerView.frame = bounds
    videoContainerView.layer.sublayers?.forEach { $0.frame = bounds }
    overlayView.frame = bounds
    
    let holeRect = calculateHoleRect(bounds: bounds)
    let holePath = holePath(bounds: bounds, holeRect: holeRect)
    maskLayer.path = holePath.cgPath
    
    cornersLayer.frame = holeRect
    cornersLayer.path = cornersPath(holeRect: holeRect)
  }
  
  func setVideoPreviewLayer(_ layer: CALayer) {
    videoContainerView.layer.insertSublayer(layer, at: 0)
  }
}

private extension QRScannerView {
  func setup() {
    addSubview(videoContainerView)
    videoContainerView.addSubview(overlayView)
    layer.addSublayer(cornersLayer)
    
    overlayView.backgroundColor = .black.withAlphaComponent(0.72)
    
    cornersLayer.strokeColor = UIColor.white.cgColor
    cornersLayer.fillColor = UIColor.clear.cgColor
    cornersLayer.lineWidth = 3
    cornersLayer.lineCap = .round
    
    maskLayer.fillRule = .evenOdd
    overlayView.layer.mask = maskLayer
  }
  
  func calculateHoleRect(bounds: CGRect) -> CGRect {
    let side = bounds.width - (.holeSideOffset * 2)
    let x: CGFloat = .holeSideOffset
    let y: CGFloat = bounds.height/2 - side/2
    let rect = CGRect(x: x, y: y,
                      width: side, height: side)
    return rect
  }
  
  func holePath(bounds: CGRect, holeRect: CGRect) -> UIBezierPath {
    let path = UIBezierPath(rect: bounds)
    path.append(.init(roundedRect: holeRect, cornerRadius: .cornerRadius))
    return path
  }

  func cornersPath(holeRect: CGRect) -> CGPath {
    let path = CGMutablePath()
    addCorner(path: path,
              start: .init(x: 0, y: .cornerSide),
              end: .init(x: .cornerSide, y: 0),
              corner: .init(x: 0, y: 0))
    addCorner(path: path,
              start: .init(x: holeRect.width - .cornerSide, y: 0),
              end: .init(x: holeRect.width, y: .cornerSide),
              corner: .init(x: holeRect.width, y: 0))
    addCorner(path: path,
              start: .init(x: holeRect.width, y: holeRect.height - .cornerSide),
              end: .init(x: holeRect.width - .cornerSide, y: holeRect.height),
              corner: .init(x: holeRect.width, y: holeRect.height))
    addCorner(path: path,
              start: .init(x: .cornerSide, y: holeRect.height),
              end: .init(x: 0, y: holeRect.height - .cornerSide),
              corner: .init(x: 0, y: holeRect.height))
    return path
  }
  
  func addCorner(path: CGMutablePath,
                 start: CGPoint,
                 end: CGPoint,
                 corner: CGPoint) {
    path.move(to: start)
    path.addArc(tangent1End: corner,
                tangent2End: end,
                radius: .cornerRadius)
    path.addLine(to: end)
  }
}

private extension CGFloat {
  static let holeSideOffset: CGFloat = 56
  static let cornerRadius: CGFloat = 8
  static let cornerSide: CGFloat = 24
  static let cornerWidth: CGFloat = 3
}
