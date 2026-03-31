import SnapKit
import TKLocalize
import TKUIKit
import UIKit

final class SendV3AmountBalanceConvertedView: UIView {
    var didTapSwap: (() -> Void)?

    var isSwapHidden: Bool = false {
        didSet {
            swapImageView.isHidden = isSwapHidden
            swapButton.isHidden = isSwapHidden
        }
    }

    var convertedValue: String = "" {
        didSet {
            convertedLabel.attributedText = convertedValue.withTextStyle(
                .body2,
                color: .Text.secondary,
                alignment: .left,
                lineBreakMode: .byTruncatingTail
            )
        }
    }

    let convertedLabel = UILabel()
    let swapImageView = UIImageView()
    let spacerView = UIView()
    let swapButton = TKButton()
    let stackView = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        swapImageView.contentMode = .center
        swapImageView.image = .TKUIKit.Icons.Size16.swapVertical
        swapImageView.tintColor = .Icon.tertiary

        swapButton.configuration = TKButton.Configuration(
            content: TKButton.Configuration.Content(),
            action: { [weak self] in
                self?.didTapSwap?()
            }
        )

        swapImageView.setContentHuggingPriority(.required, for: .horizontal)
        convertedLabel.setContentHuggingPriority(.required, for: .horizontal)
        convertedLabel.isUserInteractionEnabled = false
        spacerView.setContentHuggingPriority(.defaultLow, for: .horizontal)

        stackView.spacing = 4
        stackView.alignment = .center

        addSubview(stackView)
        addSubview(swapButton)

        stackView.addArrangedSubview(convertedLabel)
        stackView.addArrangedSubview(swapImageView)
        stackView.addArrangedSubview(spacerView)

        stackView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
        swapImageView.snp.makeConstraints { make in
            make.top.bottom.equalTo(self)
        }
        swapButton.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
    }
}
