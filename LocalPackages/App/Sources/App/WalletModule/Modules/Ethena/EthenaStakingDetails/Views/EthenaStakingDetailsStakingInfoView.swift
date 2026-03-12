import TKUIKit
import UIKit

final class EthenaStakingDetailsInfoView: UIView {
    struct Configuration {
        let apyTitle: String
        let apyDescription: String
        let apyValue: String
        let boostTitle: String
        let boostDescription: String
        let faqButtonModel: TKPlainButton.Model?
        let checkEligibilityButtonModel: TKPlainButton.Model?
    }

    var configuration = Configuration(
        apyTitle: "",
        apyDescription: "",
        apyValue: "",
        boostTitle: "",
        boostDescription: "",
        faqButtonModel: nil,
        checkEligibilityButtonModel: nil
    ) {
        didSet {
            didUpdateConfiguration()
            setNeedsLayout()
            invalidateIntrinsicContentSize()
        }
    }

    private let contentView = UIView()
    private let apyTitleLabel = UILabel()
    private let apyDescriptionLabel = UILabel()
    private let apyValueLabel = UILabel()
    private let boostTitleLabel = UILabel()
    private let boostDescriptionLabel = UILabel()
    private let faqButton = TKPlainButton()
    private let checkEligibilityButton = TKPlainButton()
    private let separatorView = TKSeparatorView()
    private let buttonsView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        backgroundColor = .Background.page
        contentView.backgroundColor = .Background.content

        contentView.layer.cornerRadius = 16
        contentView.layer.cornerCurve = .continuous
        contentView.layer.masksToBounds = true

        apyDescriptionLabel.numberOfLines = 0
        boostDescriptionLabel.numberOfLines = 0

        addSubview(contentView)

        let apyStackView = UIStackView()
        apyStackView.axis = .vertical

        let apyTopStackView = UIStackView()
        apyTopStackView.axis = .horizontal

        apyTopStackView.addArrangedSubview(apyTitleLabel)
        apyTopStackView.addArrangedSubview(apyValueLabel)
        apyStackView.addArrangedSubview(apyTopStackView)
        apyStackView.addArrangedSubview(apyDescriptionLabel)

        contentView.addSubview(apyStackView)

        let boostStackView = UIStackView()
        boostStackView.axis = .vertical

        boostStackView.addArrangedSubview(boostTitleLabel)
        boostStackView.addArrangedSubview(boostDescriptionLabel)

        contentView.addSubview(boostStackView)

        contentView.addSubview(separatorView)

        contentView.addSubview(buttonsView)

        contentView.snp.makeConstraints { make in
            make.edges.equalTo(self).inset(UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16))
        }

        apyStackView.snp.makeConstraints { make in
            make.left.top.right.equalTo(contentView).inset(16)
        }

        separatorView.snp.makeConstraints { make in
            make.top.equalTo(apyStackView.snp.bottom).offset(16)
            make.left.equalTo(contentView).offset(16)
            make.right.equalTo(contentView).offset(-16)
        }

        boostStackView.snp.makeConstraints { make in
            make.left.right.equalTo(contentView).inset(16)
            make.top.equalTo(separatorView.snp.bottom).offset(16)
        }

        buttonsView.snp.makeConstraints { make in
            make.top.equalTo(boostStackView.snp.bottom)
            make.left.equalTo(contentView).offset(16)
            make.right.lessThanOrEqualTo(contentView).offset(-16)
            make.bottom.equalTo(contentView).offset(-16)
        }

        setupButtonsView()
    }

    private func didUpdateConfiguration() {
        apyTitleLabel.attributedText = configuration.apyTitle
            .withTextStyle(
                .label1,
                color: .Text.primary
            )
        apyValueLabel.attributedText = configuration.apyValue
            .withTextStyle(
                .label1,
                color: .Text.primary,
                alignment: .right,
                lineBreakMode: .byWordWrapping
            )
        apyDescriptionLabel.attributedText = configuration.apyDescription
            .withTextStyle(
                .body2,
                color: .Text.secondary,
                alignment: .left,
                lineBreakMode: .byWordWrapping
            )

        boostTitleLabel.attributedText = configuration.boostTitle
            .withTextStyle(
                .label1,
                color: .Text.primary
            )
        boostDescriptionLabel.attributedText = configuration.boostDescription
            .withTextStyle(
                .body2,
                color: .Text.secondary,
                alignment: .left,
                lineBreakMode: .byWordWrapping
            )

        if let faqButtonModel = configuration.faqButtonModel {
            faqButton.isHidden = false
            faqButton.configure(model: faqButtonModel)
        } else {
            faqButton.isHidden = true
        }

        if let checkEligibilityButtonModel = configuration.checkEligibilityButtonModel {
            checkEligibilityButton.isHidden = false
            checkEligibilityButton.configure(model: checkEligibilityButtonModel)
        } else {
            checkEligibilityButton.isHidden = true
        }
    }

    private func setupButtonsView() {
        buttonsView.addSubview(faqButton)
        buttonsView.addSubview(checkEligibilityButton)

        let dotLabel = UILabel()
        dotLabel.attributedText = " · ".withTextStyle(
            .body2,
            color: .Text.secondary
        )
        buttonsView.addSubview(dotLabel)

        faqButton.snp.makeConstraints { make in
            make.top.left.bottom.equalTo(buttonsView)
        }

        dotLabel.snp.makeConstraints { make in
            make.top.bottom.equalTo(buttonsView)
            make.left.equalTo(faqButton.snp.right)
        }

        checkEligibilityButton.snp.makeConstraints { make in
            make.top.right.bottom.equalTo(buttonsView)
            make.left.equalTo(dotLabel.snp.right)
        }
    }
}
