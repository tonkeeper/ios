import UIKit

public final class TKNavigationBarContainer: UIView {
    private lazy var barStackView: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.alignment = .center
        view.distribution = .fill
        view.spacing = 16.0
        return view
    }()
    
    private lazy var separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .Separator.common
        view.isHidden = true
        return view
    }()
    
    public var barViews: [UIView] = [] {
        didSet {
            oldValue.forEach { [weak self] in self?.barStackView.removeArrangedSubview($0) }
            barViews.forEach { [weak self] in self?.barStackView.addArrangedSubview($0) }
        }
    }
    
    public var contentView: UIView? {
        didSet {
            oldValue?.removeFromSuperview()
            guard let contentView else { return }
            insertSubview(contentView, at: 0)
            setNeedsLayout()
        }
    }
    
    public weak var scrollView: UIScrollView? {
        didSet {
            didSetScrollView()
        }
    }
    
    public var barHeight: CGFloat {
        didSet {
            setNeedsLayout()
        }
    }
    
    public var barPadding: UIEdgeInsets = .init(top: 8, left: 16, bottom: 8, right: 16) {
        didSet {
            setNeedsLayout()
        }
    }
    
    public var contentPadding: UIEdgeInsets = .init(top: 10, left: 10, bottom: 10, right: 10) {
        didSet {
            setNeedsLayout()
        }
    }
    
    public var additionalInset: CGFloat {
        let barViewHeight = barPadding.top + barPadding.bottom + barHeight
        let contentViewHeight = contentPadding.top + contentPadding.bottom + contentViewSize(contentView, bounds.size).height
        return barViewHeight + contentViewHeight
    }
    
    private var additionalHeight: CGFloat {
        additionalInset + safeAreaInsets.top
    }
    
    private var contentOffsetToken: NSKeyValueObservation?
    private let contentViewSize: (UIView?, CGSize) -> CGSize
    
    public init(
        contentView: UIView? = nil,
        contentViewSize: @escaping (_ contentView: UIView?, _ boundsSize: CGSize) -> CGSize = { _, _  in .init() },
        barHeight: CGFloat = 32
    ) {
        self.contentViewSize = contentViewSize
        self.contentView = contentView
        self.barHeight = barHeight
        super.init(frame: .init())
        
        backgroundColor = .Background.page
        
        addSubview(barStackView)
        if let contentView {
            addSubview(contentView)
        }
        addSubview(separatorView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func didSetScrollView() {
        if let scrollView = scrollView {
            contentOffsetToken = scrollView.observe(\.contentOffset) { [weak self] scrollView, _ in
                let offset = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
                self?.separatorView.isHidden = offset <= 0
            }
        } else {
            contentOffsetToken = nil
        }
    }
    
    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        .init(width: size.width, height: additionalHeight)
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        let barStackViewMinX = barPadding.left
        let barStackViewMinY = barPadding.top + safeAreaInsets.top
        let barStackViewWidth = bounds.width - (barPadding.left + barPadding.right)
        let barStackViewHeight = barHeight
        
        barStackView.frame = .init(
            x: barStackViewMinX,
            y: barStackViewMinY,
            width: barStackViewWidth,
            height: barStackViewHeight
        )
        
        let contentViewBounds = CGSize(width: bounds.width - (contentPadding.left + contentPadding.right), height: bounds.height)
        let contentViewSize = contentViewSize(contentView, contentViewBounds)
        let contentViewMinX = contentPadding.left
        let contentViewMinY = barStackViewMinY + barStackViewHeight + contentPadding.top + barPadding.bottom
        
        contentView?.frame = .init(
            x: contentViewMinX,
            y: contentViewMinY,
            width: contentViewSize.width,
            height: contentViewSize.height
        )
        
        let separatorViewMinY = contentViewMinY + contentViewSize.height + contentPadding.bottom - Constants.separatorWidth
        separatorView.frame = .init(x: 0, y: separatorViewMinY, width: bounds.width, height: Constants.separatorWidth)
    }
}
