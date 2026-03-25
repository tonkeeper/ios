import TKUIKit
import UIKit

public final class TKRecoverPhraseBannerView: UIView, ConfigurableView {
    let backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = .Accent.orange
        return view
    }()

    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public struct Model {
        public let text: String
        public init(text: String) {
            self.text = text
        }
    }

    public func configure(model: Model) {
        label.attributedText = model.text.withTextStyle(
            .body3,
            color: .Constant.black,
            alignment: .left,
            lineBreakMode: .byWordWrapping
        )
    }
}

private extension TKRecoverPhraseBannerView {
    func setup() {
        backgroundView.layer.cornerRadius = 16
        backgroundView.layer.cornerCurve = .continuous
        backgroundView.layer.masksToBounds = true

        label.numberOfLines = 0

        addSubview(backgroundView)
        addSubview(label)

        setupConstraints()
    }

    func setupConstraints() {
        backgroundView.snp.makeConstraints { make in
            make.top.equalTo(self)
            make.left.bottom.right.equalTo(self).inset(16)
        }

        label.snp.makeConstraints { make in
            make.edges.equalTo(backgroundView).inset(UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16))
        }
    }
}
