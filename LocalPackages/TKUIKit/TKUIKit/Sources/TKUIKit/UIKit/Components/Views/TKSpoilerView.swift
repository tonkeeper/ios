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
  
  public override func setup() {
    super.setup()
    
    let emitterCell = CAEmitterCell()
    emitterCell.contents = UIImage.TKUIKit.Images.text_spoiler.cgImage
    emitterCell.color = UIColor.Text.primary.cgColor
    emitterCell.contentsScale = 1.8
    emitterCell.emissionRange = .pi * 2
    emitterCell.lifetime = 1
    emitterCell.scale = 0.5
    emitterCell.velocityRange = 20
    emitterCell.alphaRange = 1

    emitterLayer.emitterShape = .rectangle
    emitterLayer.emitterCells = [emitterCell]
    
    if #available(iOS 17.0, *) {
      registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (traitEnvironment: Self, previousTraitCollection: UITraitCollection) in
        emitterCell.color = UIColor.Text.primary.cgColor
      }
    }
  }
  
  public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    if #unavailable(iOS 17.0) {
      emitterLayer.emitterCells?.forEach {
        $0.color = UIColor.Text.primary.cgColor
      }
    }
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    emitterLayer.emitterCells?.forEach {
      $0.birthRate = Float((bounds.width * bounds.height) / 3)
    }
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
