import SnapKit
import TKUIKit
import UIKit

final class RampPickerWarningHeaderView: UIView, TKCollectionViewSupplementaryContainerViewContentView {
    private let contentView = RampWarningView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    private func setup() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().inset(Constants.bottomPadding)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(model: String) {
        contentView.configure(attributedText: model.withTextStyle(.body2, color: .Text.primary))
    }

    func prepareForReuse() {
        contentView.configure(attributedText: nil)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let contentSize = contentView.sizeThatFits(size)
        return CGSize(width: contentSize.width, height: contentSize.height + Constants.bottomPadding)
    }
}

private extension RampPickerWarningHeaderView {
    enum Constants {
        static let bottomPadding: CGFloat = 16
    }
}
