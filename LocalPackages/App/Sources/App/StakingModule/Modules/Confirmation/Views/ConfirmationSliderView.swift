import TKUIKit
import UIKit

private final class AnimatableGradientMaskView: UIView {
    private let gradientColors: [CGColor]
    private let presentationView: UIView
    private let presentationMaskView: UIView
    
    private lazy var contentView = UIView()
    
    private lazy var gradientView: CAGradientLayer = {
        let v = CAGradientLayer()
        v.colors = gradientColors
        return v
    }()
    
    init(
        gradientColors: [CGColor] = [UIColor.gray.cgColor, UIColor.gray.cgColor],
        attributedText: NSAttributedString
    ) {
        self.gradientColors = gradientColors
        
        let presentationView = UILabel()
        presentationView.attributedText = attributedText
        
        let presentationMaskView = UILabel()
        presentationMaskView.attributedText = attributedText
        
        self.presentationView = presentationView
        self.presentationMaskView = presentationMaskView
        
        super.init(frame: .zero)
        
        addSubview(contentView)
        contentView.addSubview(presentationView)
        contentView.layer.addSublayer(gradientView)
        contentView.mask = presentationMaskView
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.frame = bounds
        presentationView.frame = bounds
        presentationMaskView.frame = bounds
        gradientView.frame = bounds
    }
    
    func start(duration: Double) {
        let anim = slideAnimation(duration: duration)
        gradientView.add(anim, forKey: .init(describing: Self.self))
    }
    
    func stop() {
        gradientView.removeAllAnimations()
    }
    
    private func slideAnimation(duration: Double) -> CAAnimation {
        let startPointAnimation = CABasicAnimation(keyPath: "startPoint")
        startPointAnimation.fromValue = CGPoint(x: -0.5, y: 0)
        startPointAnimation.toValue = CGPoint(x: 1.0, y: 0)
        
        let endPointAnimation = CABasicAnimation(keyPath: "endPoint")
        endPointAnimation.fromValue = CGPoint(x: 0, y: 0)
        endPointAnimation.toValue = CGPoint(x: 1.5, y: 0)
        
        let animationGroup = CAAnimationGroup()
        animationGroup.duration = duration
        animationGroup.fillMode = .forwards
        animationGroup.repeatCount = .infinity
        animationGroup.animations = [
            startPointAnimation,
            endPointAnimation
        ]
        
        return animationGroup
    }
}

final class ConfirmationSliderView: UIView {
    private lazy var animatableGradientView: AnimatableGradientMaskView = {
        let startGradientColor = UIColor(red: 194/255, green: 218/255, blue: 255/255, alpha: 1)
        let endGradientColor = UIColor(red: 194/255, green: 218/255, blue: 255/255, alpha: 0)
        let attributedText = "Slide to Confirm".withTextStyle(.label1, color: .Text.tertiary, alignment: .center)
        
        let v = AnimatableGradientMaskView(
            gradientColors: [
                endGradientColor.cgColor,
                startGradientColor.cgColor,
                endGradientColor.cgColor
            ],
            attributedText: attributedText
        )
        return v
    }()
    
    private lazy var sliderView: TKPaddingContainerView = {
        let v = UIImageView()
        v.contentMode = .scaleAspectFit
        v.image = .TKUIKit.Icons.Size28.arrowRightOutline.withTintColor(.Text.primary, renderingMode: .alwaysOriginal)
        
        let c = TKPaddingContainerView()
        c.setViews([v])
        c.padding = .init(top: 16, left: 32, bottom: 16, right: 32)
        c.backgroundColor = .Button.primaryBackground
        return c
    }()
    
    private var sliderViewPositionMaxX: CGFloat {
        bounds.width - .sliderViewWidth / 2.0
    }
    
    private var sliderViewPositionMinX: CGFloat {
        .sliderViewWidth / 2.0
    }
    
    private var sliderViewInitialPosition: CGFloat = 0.0
    
    var didSlide: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 16.0
        sliderView.layer.cornerRadius = 16
        
        addSubview(animatableGradientView)
        addSubview(sliderView)
        
        let gesture = UIPanGestureRecognizer()
        gesture.addTarget(self, action: #selector(handleGesture))
        sliderView.addGestureRecognizer(gesture)
        
        animatableGradientView.start(duration: 4.0)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayout()
    }
    
    @objc
    private func handleGesture(_ sender: UIPanGestureRecognizer) {
        if sender.state == .began {
            self.sliderViewInitialPosition = sliderView.center.x
        } else if sender.state == .changed {
            
            let translation = sender.translation(in: sliderView)
            var newPosition = sliderViewInitialPosition + translation.x
            newPosition = max(sliderViewPositionMinX, min(sliderViewPositionMaxX, newPosition))
            sliderView.center.x = newPosition
            
            if newPosition == sliderViewPositionMaxX {
                didSlide?()
            }
            
        } else if sender.state == .ended {
            UIView.animate(withDuration: 0.35) {
                self.sliderView.frame.origin.x = 0.0
            }
        }
    }
    
    private func updateLayout() {
        animatableGradientView.frame = bounds
        sliderView.frame.size = .init(width: .sliderViewWidth, height: bounds.height)
        sliderView.frame.origin.y = 0.0
    }
}

private extension CGFloat {
    static let sliderViewWidth = 92.0
}
