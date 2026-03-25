import TKUIKit
import UIKit

struct DappSharingURLButtonPopUpItem: TKPopUp.Item {
    let configuration: DappSharingURLButton.Configuration
    let action: () -> Void
    let bottomSpace: CGFloat

    func getView() -> UIView {
        let view = DappSharingURLButton()
        view.configuration = configuration
        view.addAction(UIAction(handler: { _ in
            action()
        }), for: .touchUpInside)
        return view
    }
}

final class DappSharingURLButton: UIControl {
    var configuration: Configuration = Configuration(title: "") {
        didSet {
            didUpdateConfiguration()
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    struct Configuration {
        let title: String
    }

    override var isHighlighted: Bool {
        didSet {
            updateBackgroundView()
        }
    }

    private let backgroundView = UIView()
    private let label = UILabel()
    private let gradientView = TKGradientView(color: .Button.secondaryBackground, direction: .rightToLeft)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 56)
    }

    private func setup() {
        backgroundView.isUserInteractionEnabled = false
        backgroundView.layer.cornerCurve = .continuous
        backgroundView.layer.cornerRadius = 16

        addSubview(backgroundView)
        backgroundView.addSubview(label)
        backgroundView.addSubview(gradientView)

        updateBackgroundView()
        didUpdateConfiguration()

        backgroundView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
        label.snp.makeConstraints { make in
            make.edges.equalTo(backgroundView).inset(16)
        }
        gradientView.snp.makeConstraints { make in
            make.top.bottom.equalTo(backgroundView)
            make.right.equalTo(backgroundView).inset(16)
            make.width.equalTo(32)
        }
    }

    private func didUpdateConfiguration() {
        label.attributedText = configuration.title.withTextStyle(
            .body1,
            color: .Button.secondaryForeground
        )
    }

    private func updateBackgroundView() {
        backgroundView.backgroundColor = isHighlighted ? .Button.secondaryBackgroundHighlighted : .Button.secondaryBackground
        gradientView.color = isHighlighted ? .Button.secondaryBackgroundHighlighted : .Button.secondaryBackground
    }
}
