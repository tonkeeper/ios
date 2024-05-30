import UIKit

public final class TKRadioView: UIView {
    public var isSelected = true {
        didSet {
            updateState()
        }
    }
    
    public var selectedColor = UIColor.Button.primaryBackground {
        didSet {
            updateState()
        }
    }
    
    private let defaultBorderView: CALayer = {
        let v = CALayer()
        v.actions = .disabledActions
        v.borderWidth = .borderWidth
        v.borderColor = UIColor.Button.tertiaryBackground.cgColor
        v.cornerRadius = .size / 2.0
        return v
    }()
    
    private let selectedBorderView: CALayer = {
        let v = CALayer()
        v.actions = .disabledActions
        v.borderWidth = .borderWidth
        v.cornerRadius = .size / 2.0
        return v
    }()
    
    private let selectedCircleView: CALayer = {
        let v = CALayer()
        v.actions = .disabledActions
        v.cornerRadius = .circleSize / 2.0
        return v
    }()
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(defaultBorderView)
        layer.addSublayer(selectedBorderView)
        layer.addSublayer(selectedCircleView)
        updateState()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        updateLayout(in: bounds.size)
    }
    
    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        .init(width: .size, height: .size)
    }
}

private extension TKRadioView {
    func updateLayout(in bounds: CGSize) {
        let minX = (bounds.width - .size) / 2.0
        let minY = (bounds.height - .size) / 2.0
        
        defaultBorderView.frame = .init(x: minX, y: minY, width: .size, height: .size)
        selectedBorderView.frame = .init(x: minX, y: minY, width: .size, height: .size)
        
        let circleMinX = (bounds.width - .circleSize) / 2.0
        let circleMinY = (bounds.height - .circleSize) / 2.0
        
        selectedCircleView.frame = .init(x: circleMinX, y: circleMinY, width: .circleSize, height: .circleSize)
    }
    
    func updateState() {
        selectedBorderView.borderColor = selectedColor.cgColor
        selectedCircleView.backgroundColor = selectedColor.cgColor
        
        selectedBorderView.isHidden = !isSelected
        selectedCircleView.isHidden = !isSelected
    }
}

private extension [String: CAAction] {
    static let disabledActions = [
        #keyPath(CALayer.frame): NSNull(),
        #keyPath(CALayer.bounds): NSNull(),
        #keyPath(CALayer.position): NSNull(),
        #keyPath(CALayer.borderColor): NSNull(),
        #keyPath(CALayer.borderWidth): NSNull(),
        #keyPath(CALayer.backgroundColor): NSNull(),
        #keyPath(CALayer.isHidden): NSNull(),
    ]
}

private extension CGFloat {
    static let size = 24.0
    static let borderWidth = 2.0
    static let circleSize = 12.0
}
