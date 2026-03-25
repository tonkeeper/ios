import UIKit

public final class TKContainerCollectionViewCell: UICollectionViewCell, ReusableView {
    public var containerContentView: UIView?

    private let containerView = UIView()

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func prepareForReuse() {
        super.prepareForReuse()
        containerView.subviews.forEach { $0.removeFromSuperview() }
    }

    public func setContentView(_ view: UIView?) {
        containerView.subviews.forEach { $0.removeFromSuperview() }
        containerContentView = view
        guard let view else { return }
        containerView.addSubview(view)
        view.snp.makeConstraints { make in
            make.edges.equalTo(containerView)
        }
    }

    private func setup() {
        contentView.addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalTo(contentView)
        }
    }
}
