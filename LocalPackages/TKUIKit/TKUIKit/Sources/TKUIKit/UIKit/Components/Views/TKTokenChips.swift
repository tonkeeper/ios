import Foundation
import UIKit
import SwiftUI

private final class Weak<T: AnyObject> {
    private(set) weak var object: T?
    init(_ object: T) {
        self.object = object
    }
}

public final class TKTokenChips: UIView, ConfigurableView {
    public var model: Model = .init(
        chipImages: [],
        chipSize: .init(width: 24, height: 24),
        chipRadius: 12,
        minimumChipOffset: 0,
        borderColor: .clear,
        borderWidth: 0
    ) {
        didSet {
            updateState()
        }
    }
    
    private var chipViews: [Weak<TKListItemIconImageView>] = []
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        updateState()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func configure(model: Model) {
        self.model = model
    }
    
    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        let chipViewSize = model.chipSize
        
        let maximumChipOffset = (CGFloat(chipViews.count) * chipViewSize.width - size.width) / max(1, CGFloat(chipViews.count - 1))
        let chipViewOffset = max(model.minimumChipOffset, maximumChipOffset)
        
        let totalWidth = (chipViewSize.width - chipViewOffset) * CGFloat(chipViews.count - 1) + chipViewSize.width
        return .init(width: totalWidth, height: model.chipSize.height)
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        updateLayout(in: bounds.size)
    }
}

private extension TKTokenChips {
    func updateLayout(in bounds: CGSize) {
        let chipViewSize = model.chipSize
        let chipViewRadius = model.chipRadius
        
        let maximumChipOffset = (CGFloat(chipViews.count) * chipViewSize.width - bounds.width) / max(1, CGFloat(chipViews.count - 1))
        let chipViewOffset = max(model.minimumChipOffset, maximumChipOffset)
        
        let totalWidth = (chipViewSize.width - chipViewOffset) * CGFloat(chipViews.count - 1) + chipViewSize.width
        var chipViewSizeMinX = (bounds.width - totalWidth) / 2.0
        
        for object in self.chipViews {
            if let chipView = object.object {
                chipView.frame = .init(
                    x: chipViewSizeMinX,
                    y: 0,
                    width: chipViewSize.width,
                    height: chipViewSize.height
                )
                chipView.layer.cornerRadius = chipViewRadius
                chipViewSizeMinX += (chipViewSize.width - chipViewOffset)
            }
        }
    }
    
    func updateState() {
        for chipView in self.chipViews {
            chipView.object?.removeFromSuperview()
        }
        chipViews = []
        
        for chipImage in model.chipImages {
            let chipView = TKListItemIconImageView()
            chipView.configure(model: chipImage)
            chipView.layer.borderColor = model.borderColor.cgColor
            chipView.layer.borderWidth = model.borderWidth
            chipViews.append(.init(chipView))
            addSubview(chipView)
        }
        
        updateLayout(in: bounds.size)
    }
}

public extension TKTokenChips {
    struct Model {
        let chipImages: [TKListItemIconImageView.Model]
        let chipSize: CGSize
        let chipRadius: CGFloat
        let minimumChipOffset: CGFloat
        let borderColor: UIColor
        let borderWidth: CGFloat
        
        public init(
            chipImages: [TKListItemIconImageView.Model],
            chipSize: CGSize,
            chipRadius: CGFloat,
            minimumChipOffset: CGFloat,
            borderColor: UIColor,
            borderWidth: CGFloat
        ) {
            self.chipImages = chipImages
            self.chipSize = chipSize
            self.chipRadius = chipRadius
            self.minimumChipOffset = minimumChipOffset
            self.borderColor = borderColor
            self.borderWidth = borderWidth
        }
    }
}
