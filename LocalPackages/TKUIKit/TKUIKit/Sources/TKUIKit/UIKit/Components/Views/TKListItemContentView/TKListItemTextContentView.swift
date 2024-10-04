import UIKit

public final class TKListItemTextContentView: UIView {
  
  public struct Configuration {
    public let titleViewConfiguration: TKListItemTitleView.Configuration
    public let captionViewsConfigurations: [TKListItemTextView.Configuration]
    public let valueViewConfiguration: TKListItemTextView.Configuration?
    public let subvalueViewConfiguration: TKListItemTextView.Configuration?
    public let valueCaptionViewConfiguration: TKListItemTextView.Configuration?
    
    public init(titleViewConfiguration: TKListItemTitleView.Configuration,
                captionViewsConfigurations: [TKListItemTextView.Configuration] = [],
                valueViewConfiguration: TKListItemTextView.Configuration? = nil,
                subvalueViewConfiguration: TKListItemTextView.Configuration? = nil,
                valueCaptionViewConfiguration: TKListItemTextView.Configuration? = nil) {
      self.titleViewConfiguration = titleViewConfiguration
      self.captionViewsConfigurations = captionViewsConfigurations
      self.valueViewConfiguration = valueViewConfiguration
      self.subvalueViewConfiguration = subvalueViewConfiguration
      self.valueCaptionViewConfiguration = valueCaptionViewConfiguration
    }
    
    public static var `default`: Configuration {
      Configuration(
        titleViewConfiguration: TKListItemTitleView.Configuration(title: "Title")
      )
    }
  }
  
  public var configuration = Configuration.default {
    didSet {
      didUpdateConfiguration()
      setNeedsLayout()
      invalidateIntrinsicContentSize()
    }
  }
  
  let titleView = TKListItemTitleView()
  var captionViews = [TKListItemTextView]()
  let valueView = TKListItemTextView()
  let subvalueView = TKListItemTextView()
  let valueCaptionView = TKListItemTextView()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    let layout = calculateLayout(size: bounds.size)
    
    titleView.frame = layout.titleViewFrame
    for (index, frame) in layout.captionViewsFrames.enumerated() {
      captionViews[index].frame = frame
    }
    
    valueView.frame = layout.valueViewFrame
    subvalueView.frame = layout.subvalueViewFrame
    valueCaptionView.frame = layout.valueCaptionViewFrame
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    let layout = calculateLayout(size: size)
    let height: CGFloat = {
      let leftHeight = layout.titleViewFrame.height + layout.captionViewsFrames.map { $0.height }.reduce(0, +)
      let rightHeight = layout.valueViewFrame.height + layout.valueCaptionViewFrame.height
      return max(leftHeight, rightHeight)
    }()
    
    return CGSize(width: size.width, height: height)
  }
  
  public override var intrinsicContentSize: CGSize {
    sizeThatFits(CGSize(width: CGFloat.infinity, height: 0))
  }
  
  private func setup() {
    addSubview(titleView)
    addSubview(valueView)
    addSubview(subvalueView)
    addSubview(valueCaptionView)
    
    didUpdateConfiguration()
  }
  
  private func didUpdateConfiguration() {
    titleView.configuration = configuration.titleViewConfiguration
    
    captionViews.forEach { $0.removeFromSuperview() }
    captionViews.removeAll()
    configuration.captionViewsConfigurations.forEach { configuration in
      let view = TKListItemTextView()
      view.configuration = configuration
      addSubview(view)
      captionViews.append(view)
    }
    
    if let valueViewConfiguration = configuration.valueViewConfiguration {
      valueView.configuration = valueViewConfiguration
      valueView.isHidden = false
    } else {
      valueView.isHidden = true
    }
    
    if let subvalueViewConfiguration = configuration.subvalueViewConfiguration {
      subvalueView.configuration = subvalueViewConfiguration
      subvalueView.isHidden = false
    } else {
      subvalueView.isHidden = true
    }
    
    if let valueCaptionViewConfiguration = configuration.valueCaptionViewConfiguration {
      valueCaptionView.configuration = valueCaptionViewConfiguration
      valueCaptionView.isHidden = false
    } else {
      valueCaptionView.isHidden = true
    }
  }
  
  private func calculateLayout(size: CGSize) -> Layout {
    var valueViewFrame: CGRect = {
      guard !valueView.isHidden else {
        return .zero
      }
      let sizeThatFits = valueView.sizeThatFits(size)
      let viewSize = CGSize(width: min(size.width, sizeThatFits.width), height: sizeThatFits.height)
      return CGRect(origin: CGPoint(x: size.width - viewSize.width, y: 0), size: viewSize)
    }()
    
    let subvalueViewFrame: CGRect = {
      guard !subvalueView.isHidden else {
        return .zero
      }
      let sizeThatFits = subvalueView.sizeThatFits(size)
      let viewSize = CGSize(width: min(size.width, sizeThatFits.width), height: sizeThatFits.height)
      return CGRect(origin: CGPoint(x: size.width - viewSize.width, y: valueViewFrame.maxY - 4), size: viewSize)
    }()
    
    let valueCaptionViewFrame: CGRect = {
      guard !valueCaptionView.isHidden else {
        return .zero
      }
      let previousFrame = subvalueViewFrame == .zero ? valueViewFrame : subvalueViewFrame
      let sizeThatFits = valueCaptionView.sizeThatFits(size)
      let viewSize = CGSize(width: min(size.width, sizeThatFits.width), height: sizeThatFits.height)
      return CGRect(origin: CGPoint(x: size.width - viewSize.width, y: previousFrame.maxY), size: viewSize)
    }()
    
    let valueFrames = [valueViewFrame, subvalueViewFrame, valueCaptionViewFrame]
    
    var titleViewFrame: CGRect = {
      let sizeThatFits = titleView.sizeThatFits(size)
      var frame = CGRect(origin: CGPoint(x: 0, y: 0), size: sizeThatFits)
      frame = valueFrames
        .map { frame.substract(rect: $0, edge: .maxXEdge) }
        .min(by: { $0.width < $1.width }) ?? .zero
      return frame
    }()
    
    let captionsViewsFrames: [CGRect] = {
      var previousFrame = titleViewFrame
      var result = [CGRect]()
      for captionView in captionViews {
        let sizeThatFits = captionView.sizeThatFits(size)
        var frame = CGRect(origin: CGPoint(x: 0, y: previousFrame.maxY), size: sizeThatFits)
        if frame.intersects(valueViewFrame) {
          let substractFrame = frame.substract(rect: valueViewFrame, edge: .maxXEdge)
          let sizeThatFits = captionView.sizeThatFits(substractFrame.size)
          frame.size = sizeThatFits
        }
        if frame.intersects(subvalueViewFrame) {
          let substractFrame = frame.substract(rect: subvalueViewFrame, edge: .maxXEdge)
          let sizeThatFits = captionView.sizeThatFits(substractFrame.size)
          frame.size = sizeThatFits
        }
        if frame.intersects(valueCaptionViewFrame) {
          let substractFrame = frame.substract(rect: valueCaptionViewFrame, edge: .maxXEdge)
          let sizeThatFits = captionView.sizeThatFits(substractFrame.size)
          frame.size = sizeThatFits
        }
        previousFrame = frame
        result.append(frame)
      }
      return result
    }()
    
    var valueViewFullHeightFrame = valueViewFrame
    valueViewFullHeightFrame.size.height = size.height
    if valueCaptionView.isHidden,
       subvalueView.isHidden,
       valueViewFrame != .zero,
        !captionsViewsFrames.map({ $0.intersects(valueViewFullHeightFrame) }).reduce(false, { $0 || $1 }) {
      valueViewFrame = valueViewFullHeightFrame
    }
    var titleViewFullHeightFrame = titleViewFrame
    titleViewFullHeightFrame.size.height = size.height
    if captionViews.isEmpty,
       size.height > 0,
       valueViewFrame == .zero || !titleViewFullHeightFrame.intersects(valueViewFrame),
       valueCaptionViewFrame == .zero || !titleViewFullHeightFrame.intersects(valueCaptionViewFrame) {
      titleViewFrame = titleViewFullHeightFrame
    }
    
    return Layout(
      titleViewFrame: titleViewFrame,
      captionViewsFrames: captionsViewsFrames,
      valueViewFrame: valueViewFrame,
      subvalueViewFrame: subvalueViewFrame,
      valueCaptionViewFrame: valueCaptionViewFrame
    )
  }
  
  private struct Layout {
    let titleViewFrame: CGRect
    let captionViewsFrames: [CGRect]
    let valueViewFrame: CGRect
    let subvalueViewFrame: CGRect
    let valueCaptionViewFrame: CGRect
  }
}
