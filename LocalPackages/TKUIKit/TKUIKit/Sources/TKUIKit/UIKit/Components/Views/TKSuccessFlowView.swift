import UIKit
import Lottie

private final class SuccessView: UIView {
    private lazy var successView: LottieAnimationView = {
        let successView = LottieAnimationView(name: .animationName)
        successView.maskAnimationToBounds = false
        successView.loopMode = .playOnce
        successView.contentMode = .scaleToFill
        return successView
    }()
    
    private lazy var labelView: UILabel = {
        let v = UILabel()
        v.attributedText = "Done".withTextStyle(.label2, color: .Accent.green)
        return v
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(successView)
        addSubview(labelView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let labelSize = labelView.sizeThatFits(size)
        let totalHeight: CGFloat = .successViewSize + .padding + labelSize.height
        return .init(width: labelSize.width, height: totalHeight)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let labelSize = labelView.sizeThatFits(bounds.size)
        let totalHeight: CGFloat = .successViewSize + .padding + labelSize.height
        
        let successViewMinX = (bounds.width - .successViewSize) / 2.0
        let successViewMinY = (bounds.height - totalHeight) / 2.0
        
        successView.frame = .init(
            x: successViewMinX,
            y: successViewMinY,
            width: .successViewSize,
            height: .successViewSize
        )
        
        let labelViewMinX = (bounds.width - labelSize.width) / 2.0
        let labelViewMinY = successViewMinY + .successViewSize + .padding
        
        labelView.frame = .init(x: labelViewMinX, y: labelViewMinY, width: labelSize.width, height: labelSize.height)
    }
    
    func play() {
        successView.play()
    }
}

public final class TKSuccessFlowView: UIView {
    public enum State {
        case content
        case loading
        case success
    }
    
    public var state = State.content {
        didSet {
            updateState()
        }
    }
    
    private let contentView: UIView
    private lazy var loaderView = TKLoaderView(size: .medium, style: .primary)
    private lazy var successView = SuccessView()
    
    public init(contentView: UIView) {
        self.contentView = contentView
        super.init(frame: .init())
        
        addSubview(contentView)
        addSubview(loaderView)
        addSubview(successView)
        
        updateState()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        updateLayout(in: bounds.size)
    }
}

private extension TKSuccessFlowView {
    func updateLayout(in bounds: CGSize) {
        let successViewSize = successView.sizeThatFits(bounds)
        let successViewMinX = (bounds.width - successViewSize.width) / 2.0
        let successViewMinY = (bounds.height - successViewSize.height) / 2.0
        
        successView.frame = .init(
            x: successViewMinX,
            y: successViewMinY,
            width: successViewSize.width,
            height: successViewSize.height
        )
        
        let loaderViewSize = loaderView.sizeThatFits(bounds)
        let loaderViewMinX = (bounds.width - loaderViewSize.width) / 2.0
        let loaderViewMinY = (bounds.height - loaderViewSize.height) / 2.0
        
        loaderView.frame = .init(
            x: loaderViewMinX,
            y: loaderViewMinY,
            width: loaderViewSize.width,
            height: loaderViewSize.height
        )
        
        let contentViewSize = CGSize(width: bounds.width, height: bounds.height)
        let contentViewMinX = (bounds.width - contentViewSize.width) / 2.0
        let contentViewMinY = (bounds.height - contentViewSize.height) / 2.0
        contentView.frame = .init(x: contentViewMinX, y: contentViewMinY, width: contentViewSize.width, height: contentViewSize.height)
    }
    
    func updateState() {
        let isContentViewHidden = state != .content
        let isLoaderViewHidden = state != .loading
        let isSuccessViewHidden = state != .success
        
        contentView.isHidden = isContentViewHidden
        loaderView.isHidden = isLoaderViewHidden
        successView.isHidden = isSuccessViewHidden
        
        if state == .success {
            successView.play()
        }
    }
}

private extension CGFloat {
    static let successViewSize = 38.0
    static let padding = 0.0
}

private extension String {
    static let animationName = "check480"
}
