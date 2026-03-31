import SnapKit
import UIKit

public final class TKBlurView: UIView {
    private let blurView: UIVisualEffectView = {
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        return UIVisualEffectView(effect: blurEffect)
    }()

    private let colorView: UIView = {
        let view = UIView()
        view.backgroundColor = .Background.transparent
        return view
    }()

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension TKBlurView {
    func setup() {
        addSubview(blurView)
        addSubview(colorView)

        setupConstraints()
    }

    func setupConstraints() {
        colorView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }

        blurView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
    }
}
