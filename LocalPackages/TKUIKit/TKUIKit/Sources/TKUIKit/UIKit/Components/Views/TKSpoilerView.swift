import UIKit

public final class TKSpoilerView: TKEmitterView {
  
  public var isOn = false {
    didSet {
      if isOn {
        emitterLayer.beginTime = CACurrentMediaTime()
      }
      emitterLayer.birthRate = isOn ? 1 : 0
    }
  }
  
  public var spoilerColor: UIColor = .Constant.white {
    didSet {
      setEmitterCell()
    }
  }
  
  public override func setup() {
    super.setup()
    setEmitterCell()
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    emitterLayer.emitterCells?.forEach {
      $0.birthRate = Float((bounds.width * bounds.height) / 3)
    }
  }
  
  private func setEmitterCell() {
    let emitterCell = CAEmitterCell()
    emitterCell.contents = UIImage.TKUIKit.Images.text_spoiler.cgImage
    emitterCell.color = spoilerColor.cgColor
    emitterCell.contentsScale = 1.8
    emitterCell.emissionRange = .pi * 2
    emitterCell.lifetime = 1
    emitterCell.scale = 0.5
    emitterCell.velocityRange = 20
    emitterCell.alphaRange = 1
    
    emitterLayer.emitterShape = .rectangle
    emitterLayer.emitterCells = [emitterCell]
  }
}

public class TKEmitterView: TKView {
  public override class var layerClass: AnyClass {
    CAEmitterLayer.self
  }
  
  var emitterLayer: CAEmitterLayer {
    layer as! CAEmitterLayer
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    emitterLayer.emitterPosition = CGPoint(
      x: bounds.size.width / 2,
      y: bounds.size.height / 2
    )
    emitterLayer.emitterSize = bounds.size
  }
}
