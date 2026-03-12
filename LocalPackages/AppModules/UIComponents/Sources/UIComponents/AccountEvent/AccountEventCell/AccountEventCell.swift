import TKUIKit
import UIKit

public class AccountEventCell: TKCollectionViewNewCell, ConfigurableView {
    let accountEventCellContentView = AccountEventCellContentView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func contentSize(targetWidth: CGFloat) -> CGSize {
        return accountEventCellContentView.sizeThatFits(CGSize(width: targetWidth, height: 0))
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        accountEventCellContentView.frame = contentContainerView.bounds
    }

    public struct Model {
        public let id: String
        public let accountEventContentConfiguration: AccountEventCellContentView.Model
        public init(id: String, accountEventContentConfiguration: AccountEventCellContentView.Model) {
            self.id = id
            self.accountEventContentConfiguration = accountEventContentConfiguration
        }
    }

    public func configure(model: Model) {
        accountEventCellContentView.configure(model: model.accountEventContentConfiguration)
        setNeedsLayout()
    }

    override public func prepareForReuse() {
        super.prepareForReuse()
        accountEventCellContentView.prepareForReuse()
    }
}

private extension AccountEventCell {
    func setup() {
        isSeparatorVisible = false
        addSubview(accountEventCellContentView)
    }
}
