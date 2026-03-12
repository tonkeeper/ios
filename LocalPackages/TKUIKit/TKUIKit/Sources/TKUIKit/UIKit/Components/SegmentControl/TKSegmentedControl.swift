import UIKit

public final class TKSegmentedControl: UIControl {
    public var selectionColor: UIColor = .Button.tertiaryBackground {
        didSet {
            selectionView.backgroundColor = selectionColor
        }
    }

    public var didSelectTab: ((_ from: Int, _ to: Int) -> Void)?

    public var tabs = [String]() {
        didSet {
            reconfigure()
        }
    }

    public var selectedIndex: Int = -1 {
        didSet {
            didUpdateSelectedIndex()
        }
    }

    private let stackView = UIStackView()
    private let backgroundView = UIView()
    private let selectionView = UIView()

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setSelectedIndex(_ selectedIndex: Int, animated: Bool) {
        self.selectedIndex = selectedIndex
        if animated {
            UIView.animate(withDuration: 0.2) {
                self.layoutIfNeeded()
            }
        }
    }

    private func setup() {
        selectionView.layer.cornerRadius = 16
        selectionView.layer.cornerCurve = .continuous
        selectionView.backgroundColor = selectionColor

        backgroundView.layer.cornerRadius = 20
        backgroundView.layer.cornerCurve = .continuous
        backgroundView.backgroundColor = .Background.content

        addSubview(backgroundView)
        addSubview(selectionView)
        addSubview(stackView)

        backgroundView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }

        stackView.snp.makeConstraints { make in
            make.edges.equalTo(self).inset(4)
        }
    }

    private func reconfigure() {
        UIView.performWithoutAnimation {
            stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
            guard !tabs.isEmpty else {
                selectedIndex = -1
                return
            }
            for (index, tab) in tabs.enumerated() {
                let tabView = TKSegmentedControlTabView()
                tabView.title = tab
                tabView.addAction(UIAction(handler: { [weak self] _ in
                    guard let self else { return }
                    guard selectedIndex != index else { return }
                    let previousIndex = selectedIndex
                    setSelectedIndex(index, animated: true)
                    didSelectTab?(previousIndex, index)
                }), for: .touchUpInside)
                stackView.addArrangedSubview(tabView)
            }
            selectedIndex = 0
        }
    }

    private func didUpdateSelectedIndex() {
        guard selectedIndex >= 0 else {
            selectionView.isHidden = true
            return
        }
        selectionView.isHidden = false
        let view = stackView.arrangedSubviews[selectedIndex]
        selectionView.snp.remakeConstraints { make in
            make.edges.equalTo(view)
        }
    }
}

private final class TKSegmentedControlTabView: UIControl {
    var title: String = "" {
        didSet {
            reconfigure()
        }
    }

    override var isHighlighted: Bool {
        didSet {
            label.alpha = isHighlighted ? 0.64 : 1
        }
    }

    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        addSubview(label)

        label.snp.makeConstraints { make in
            make.top.equalTo(self).offset(6)
            make.left.equalTo(self).offset(12)
            make.bottom.equalTo(self).offset(-6)
            make.right.equalTo(self).offset(-12)
        }
    }

    private func reconfigure() {
        label.attributedText = title.withTextStyle(
            .label2,
            color: .Button.secondaryForeground,
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        )
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }
}
