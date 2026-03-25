import SnapKit
import UIKit

public final class TKGlassView: UIView {
    private let glassView: UIVisualEffectView = {
        let blurEffect: UIVisualEffect
        if #available(iOS 26.0, *) {
            blurEffect = UIGlassEffect(style: .regular)
        } else {
            blurEffect = UIBlurEffect(style: .light)
        }

        return UIVisualEffectView(effect: blurEffect)
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

private extension TKGlassView {
    func setup() {
        addSubview(glassView)

        setupConstraints()
    }

    func setupConstraints() {
        glassView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
    }
}
