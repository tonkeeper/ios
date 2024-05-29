import UIKit

private class Weak<T: AnyObject> {
    private(set) weak var object: T?
    init(_ object: T) {
        self.object = object
    }
}

public struct TKTabViewItem {
    let item: CustomStringConvertible
    let action: (() -> Void)?
    public init(item: CustomStringConvertible, action: (() -> Void)? = nil) {
        self.item = item
        self.action = action
    }
}

public final class TKTabView: UIView {
    public var sliderViewColor: UIColor = .Accent.blue {
        didSet {
            updateState()
        }
    }
        
    public var itemSpacing: CGFloat = 7.0 {
        didSet {
            updateLayout(in: bounds.size)
        }
    }
    
    public var itemPadding: UIEdgeInsets = .init(top: 4, left: 12, bottom: 4, right: 12) {
        didSet {
            updateLayout(in: bounds.size)
        }
    }
    
    public var tabItems: [TKTabViewItem] = [] {
        didSet {
            updateState()
        }
    }
    
    private lazy var sliderView: CALayer = {
        let v = CALayer()
        v.frame.size.height = 3.0
        v.cornerRadius = 1.5
        v.actions = [
            #keyPath(CALayer.bounds): NSNull(),
            #keyPath(CALayer.frame): NSNull(),
            #keyPath(CALayer.position): NSNull()
        ]
        return v
    }()
        
    public weak var scrollView: UIScrollView? {
        didSet {
            if let scrollView {
              contentOffsetToken = scrollView.observe(\.contentOffset) { [weak self] scrollView, _ in
                  self?.scrollViewDidScroll(
                    scrollViewContentOffset: scrollView.contentOffset.x,
                    scrollViewContentSize: scrollView.contentSize.width
                  )
              }
            } else {
              contentOffsetToken = nil
            }
        }
    }
    
    private var contentOffsetToken: NSKeyValueObservation?
    private var totalTabItemsWidth: CGFloat = 0.0
    private var tabItemViews: [Weak<TKButton>] = []
            
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(sliderView)
        updateState()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override var intrinsicContentSize: CGSize {
        let totalWidth = totalTabItemsWidth + CGFloat(tabItems.count - 1) * itemSpacing
        var totalHeight = 0.0
        for object in tabItemViews {
            if let tabItem = object.object {
                let tabItemSize = tabItem.sizeThatFits(.zero)
                totalHeight = max(totalHeight, tabItemSize.height)
            }
        }
        return .init(width: totalWidth, height: totalHeight)
    }
    
    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        let totalWidth = totalTabItemsWidth + CGFloat(tabItems.count - 1) * itemSpacing
        var totalHeight = 0.0
        for object in tabItemViews {
            if let tabItem = object.object {
                let tabItemSize = tabItem.sizeThatFits(size)
                totalHeight = max(totalHeight, tabItemSize.height)
            }
        }
        return .init(width: totalWidth, height: totalHeight)
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        updateLayout(in: bounds.size)
    }
}

private extension TKTabView {
    func updateLayout(in bounds: CGSize) {
        let totalWidth = totalTabItemsWidth + CGFloat(tabItems.count - 1) * itemSpacing
        
        var tabItemMaxY = 0.0
        var tabItemMinX = (bounds.width - totalWidth) / 2.0
        
        for object in self.tabItemViews {
            if let tabItem = object.object {
                let tabItemSize = tabItem.sizeThatFits(bounds)
                let tabItemMinY = (bounds.height - tabItemSize.height) / 2.0
                tabItem.frame = .init(x: tabItemMinX, y: tabItemMinY, width: tabItemSize.width, height: tabItemSize.height)
                tabItemMinX += (tabItemSize.width + itemSpacing)
                tabItemMaxY = max(tabItemMaxY, tabItemMinY + tabItemSize.height)
            }
        }
        
        sliderView.position.y = tabItemMaxY + itemPadding.bottom
    }
    
    func updateState() {
        sliderView.backgroundColor = sliderViewColor.cgColor
        
        subviews.forEach { $0.removeFromSuperview() }
        
        tabItemViews = []
        
        var totalWidth = 0.0
        
        for item in self.tabItems {
            let tabItem = TKButton()
            tabItem.configuration = .init(
                content: .init(title: .plainString("\(item.item)")),
                contentPadding: itemPadding,
                padding: .zero,
                textStyle: .label1,
                textColor: .Text.primary,
                action: item.action
            )
            
            let tabItemSize = tabItem.sizeThatFits(bounds.size)
            totalWidth += tabItemSize.width
            
            addSubview(tabItem)
            tabItemViews.append(.init(tabItem))
        }
        
        self.totalTabItemsWidth = totalWidth
        
        updateLayout(in: bounds.size)
    }
    
    func scrollViewDidScroll(scrollViewContentOffset: CGFloat, scrollViewContentSize: CGFloat) {
        if scrollViewContentSize.isZero { return }
        let scrollViewPageOffset = (scrollViewContentOffset / scrollViewContentSize) * CGFloat(tabItemViews.count)
        
        let prevScrollViewPageIndexInt = max(0, min(tabItemViews.count - 1, (Int(scrollViewPageOffset.rounded(.down)))))
        let nextScrollViewPageIndexInt = max(0, min(tabItemViews.count - 1, (Int(scrollViewPageOffset.rounded(.up)))))
                
        if tabItemViews.isEmpty { return }
        
        let koefOffset = max(0, min(1, scrollViewPageOffset - CGFloat(prevScrollViewPageIndexInt)))
        
        var prevTabItemPosition = 0.0
        var nextTabItemPosition = 0.0
        
        var prevTabItemWidth = 0.0
        var nextTabItemWidth = 0.0
        
        if let prevTabItem = self.tabItemViews[prevScrollViewPageIndexInt].object {
            prevTabItemWidth = prevTabItem.sizeThatFits(bounds.size).width
            prevTabItemPosition = prevTabItem.center.x
        }
        
        if let nextTabItem = self.tabItemViews[nextScrollViewPageIndexInt].object {
            nextTabItemWidth = nextTabItem.sizeThatFits(bounds.size).width
            nextTabItemPosition = nextTabItem.center.x
        }
        
        let sliderViewPosition = prevTabItemPosition + (nextTabItemPosition - prevTabItemPosition) * koefOffset
        let sliderViewWidth = prevTabItemWidth + (nextTabItemWidth - prevTabItemWidth) * koefOffset
        
        sliderView.position.x = sliderViewPosition
        sliderView.frame.size.width = sliderViewWidth
    }
}
