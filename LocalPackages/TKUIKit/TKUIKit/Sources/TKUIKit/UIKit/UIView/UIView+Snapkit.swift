import UIKit
import SnapKit

extension UIView {
    public func fill(in superview: UIView, insets: UIEdgeInsets = .zero) {
        superview.addSubview(self)
        snp.makeConstraints { make in
            make.edges.equalTo(superview).inset(insets)
        }
    }
    
    public func fill(in superview: UIView, inset: CGFloat) {
        self.fill(
            in: superview,
            insets: UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
        )
    }
    
    public func fill(safeAreaOf superview: UIView) {
        superview.addSubview(self)
        snp.makeConstraints { make in
            make.edges.equalTo(superview.safeAreaInsets)
        }
    }

    public func pinToTopSafeArea(in superview: UIView) {
        superview.addSubview(self)
        snp.makeConstraints { make in
            make.leading.trailing.equalTo(superview)
            make.top.equalTo(superview.safeAreaLayoutGuide.snp.top)
        }
    }
    
    public func layout(in superview: UIView, withLayout layout: (ConstraintMaker) -> Void) {
        superview.addSubview(self)
        snp.makeConstraints(layout)
    }
}
