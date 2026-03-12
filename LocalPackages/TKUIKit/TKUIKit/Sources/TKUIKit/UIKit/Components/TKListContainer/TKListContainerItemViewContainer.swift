import UIKit

public final class TKListContainerItemViewContainer: UIControl {
    var isHighlightable: Bool = true
    override public var isHighlighted: Bool {
        didSet {
            guard isHighlightable else { return }
            highlightView.isHighlighted = isHighlighted
        }
    }

    private let highlightView = TKHighlightView()

    var isSeparatorVisible: Bool = true {
        didSet {
            separatorView.isHidden = !isSeparatorVisible
        }
    }

    private let separatorView = TKSeparatorView()

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setContentView(_ view: UIView) {
        addSubview(view)
        view.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
    }

    private func setup() {
        backgroundColor = .Background.content

        addSubviews(highlightView, separatorView)

        highlightView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
        separatorView.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(16)
            make.bottom.right.equalToSuperview()
        }
    }
}
