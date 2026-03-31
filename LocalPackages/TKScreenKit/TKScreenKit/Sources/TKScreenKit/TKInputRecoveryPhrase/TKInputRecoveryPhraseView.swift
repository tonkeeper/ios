import SnapKit
import TKUIKit
import UIKit

public final class TKInputRecoveryPhraseView: UIView {
    public struct InputFieldModel {
        public let index: Int
        public let didUpdateText: (String) -> Void
        public let didBeignEditing: () -> Void
        public let didEndEditing: () -> Void
        public let shouldPaste: (String) -> Bool
        public let didTapReturn: (() -> Void)?
    }

    public struct SegmentedControlModel {
        public let tabs: [String]
        public let selectedIndex: Int
        public let selectionClosure: (Int) -> Void
    }

    public var titleDescriptionModel = TKTitleDescriptionView.Model(title: "") {
        didSet {
            updateTitleDescriptionView()
        }
    }

    public var seedPhraseInputControlModel: SegmentedControlModel? {
        didSet {
            updateSeedPhraseModeSegmentedControl()
        }
    }

    public var inputs = [InputFieldModel]() {
        didSet {
            updateInputs()
        }
    }

    var bannerViewProvider: (() -> UIView)? {
        didSet {
            bannerView?.removeFromSuperview()
            bannerView = nil
            if let bannerView = bannerViewProvider?() {
                self.bannerView = bannerView
                self.contentStackView.insertArrangedSubview(bannerView, at: 1)
                self.contentStackView.setCustomSpacing(.afterWordInputSpacing, after: bannerView)
            }
        }
    }

    let scrollView: UIScrollView = {
        let scrollView = TKUIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()

    let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.directionalLayoutMargins = .contentStackViewPadding
        return stackView
    }()

    let inputStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        return stackView
    }()

    let titleDescriptionView: TKTitleDescriptionView = {
        let view = TKTitleDescriptionView(size: .big)
        view.padding = .titleDescriptionPadding
        return view
    }()

    var inputTextFields = [TKMnemonicTextField]()

    let continueButton = TKButton()

    private let seedPhraseModeSegmentedControl = TKSegmentedControl()
    private let seedPhraseModeSegmentedControlContainer = UIView()

    let suggestsView = TKInputRecoveryPhraseSuggestsView()
    let pasteButton = TKButton()

    var bannerView: UIView?

    var keyboardHeight: CGFloat = 0 {
        didSet {
            if keyboardHeight.isZero {
                scrollView.contentInset.bottom = safeAreaInsets.bottom + suggestsView.bounds.height
            } else {
                scrollView.contentInset.bottom = keyboardHeight - safeAreaInsets.bottom + suggestsView.bounds.height
            }
            pasteButton.snp.remakeConstraints { make in
                make.centerX.equalTo(self)
                if keyboardHeight.isZero {
                    make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
                } else {
                    make.bottom.equalTo(self).offset(-(keyboardHeight - safeAreaInsets.bottom))
                }
            }
        }
    }

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        suggestsView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 52)
    }

    func scrollToInput(
        at index: Int,
        animationDuration: TimeInterval
    ) {
        guard inputTextFields.count > index else { return }
        let inputTextField = inputTextFields[index]
        let fieldConvertedFrame = scrollView.convert(inputTextField.frame, from: inputStackView)

        var topInset = titleDescriptionView.frame.maxY
        if let bannerView {
            topInset = bannerView.frame.maxY - .afterWordInputSpacing
        }
        if !seedPhraseModeSegmentedControlContainer.isHidden {
            topInset = seedPhraseModeSegmentedControlContainer.frame.maxY - .afterWordInputSpacing
        }

        let scrollViewMaxOrigin = scrollView.contentSize.height
            - scrollView.frame.height
            + scrollView.contentInset.bottom

        let yContentOffset = min(fieldConvertedFrame.minY - topInset, scrollViewMaxOrigin)

        UIView.animate(withDuration: animationDuration) {
            self.scrollView.contentOffset = .init(x: 0, y: yContentOffset)
        }
    }

    func scrollToBottom(animationDuration: TimeInterval) {
        if scrollView.contentSize.height < scrollView.bounds.size.height { return }
        let bottomOffset = CGPoint(x: 0, y: scrollView.contentSize.height - scrollView.bounds.size.height + scrollView.adjustedContentInset.bottom)
        UIView.animate(withDuration: animationDuration) {
            self.scrollView.contentOffset = bottomOffset
        }
    }

    func configureSuggests(model: TKInputRecoveryPhraseSuggestsView.Model) {
        suggestsView.alpha = model.suggests.isEmpty ? 0 : 1
        suggestsView.configure(model: model)
    }
}

private extension TKInputRecoveryPhraseView {
    func setup() {
        backgroundColor = .Background.page

        suggestsView.alpha = 0

        contentStackView.addArrangedSubview(titleDescriptionView)
        contentStackView.addArrangedSubview(seedPhraseModeSegmentedControlContainer)
        contentStackView.setCustomSpacing(12, after: seedPhraseModeSegmentedControlContainer)
        contentStackView.addArrangedSubview(inputStackView)
        contentStackView.setCustomSpacing(16, after: inputStackView)
        contentStackView.addArrangedSubview(continueButton)

        addSubview(scrollView)
        addSubview(pasteButton)
        scrollView.addSubview(contentStackView)
        seedPhraseModeSegmentedControlContainer.addSubview(seedPhraseModeSegmentedControl)

        setupConstraints()

        updateTitleDescriptionView()
        updateSeedPhraseModeSegmentedControl()
        updateInputs()
    }

    func setupConstraints() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        pasteButton.snp.makeConstraints { make in
            make.centerX.equalTo(self)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
        }

        seedPhraseModeSegmentedControl.snp.makeConstraints { make in
            make.left.greaterThanOrEqualTo(seedPhraseModeSegmentedControlContainer)
            make.right.lessThanOrEqualTo(seedPhraseModeSegmentedControlContainer)
            make.top.bottom.equalTo(seedPhraseModeSegmentedControlContainer)
            make.centerX.equalTo(seedPhraseModeSegmentedControlContainer)
        }

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leftAnchor.constraint(equalTo: leftAnchor),
            scrollView.rightAnchor.constraint(equalTo: rightAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.widthAnchor.constraint(equalTo: widthAnchor),

            contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStackView.leftAnchor.constraint(equalTo: scrollView.leftAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStackView.rightAnchor.constraint(equalTo: scrollView.rightAnchor),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    func updateTitleDescriptionView() {
        titleDescriptionView.configure(model: titleDescriptionModel)
    }

    func updateSeedPhraseModeSegmentedControl() {
        if let seedPhraseInputControlModel {
            seedPhraseModeSegmentedControlContainer.isHidden = false
            seedPhraseModeSegmentedControl.tabs = seedPhraseInputControlModel.tabs
            seedPhraseModeSegmentedControl.selectedIndex = seedPhraseInputControlModel.selectedIndex
            seedPhraseModeSegmentedControl.didSelectTab = { _, index in
                seedPhraseInputControlModel.selectionClosure(index)
            }
        } else {
            seedPhraseModeSegmentedControlContainer.isHidden = true
        }
    }

    func updateInputs() {
        inputStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        inputTextFields = []
        for (index, inputModel) in inputs.enumerated() {
            let textField = TKMnemonicTextField()
            textField.accessibilityLabel = "mnemonic.input.\(index)"
            textField.accessoryView = suggestsView
            textField.indexNumber = inputModel.index
            textField.didUpdateText = { text in
                inputModel.didUpdateText(text)
            }
            textField.didBeginEditing = {
                inputModel.didBeignEditing()
            }
            textField.didEndEditing = {
                inputModel.didEndEditing()
            }
            textField.shouldPaste = { text in
                inputModel.shouldPaste(text)
            }
            textField.didTapReturn = {
                inputModel.didTapReturn?()
            }

            inputStackView.addArrangedSubview(textField)
            inputStackView.setCustomSpacing(.afterWordInputSpacing, after: textField)
            inputTextFields.append(textField)
        }
    }
}

private extension CGFloat {
    static let topSpacing: CGFloat = 44
    static let afterWordInputSpacing: CGFloat = 16
}

private extension UIEdgeInsets {
    static let continueButtonContainerPadding = UIEdgeInsets(
        top: 16,
        left: 0,
        bottom: 32,
        right: 0
    )
}

private extension NSDirectionalEdgeInsets {
    static let titleDescriptionPadding = NSDirectionalEdgeInsets(
        top: 11,
        leading: 0,
        bottom: 16,
        trailing: 0
    )

    static let contentStackViewPadding = NSDirectionalEdgeInsets(
        top: 0,
        leading: 32,
        bottom: 0,
        trailing: 32
    )

    static let switchWordsCountButtonsStackViewPadding = NSDirectionalEdgeInsets(
        top: 4,
        leading: 4,
        bottom: 4,
        trailing: 4
    )
}
