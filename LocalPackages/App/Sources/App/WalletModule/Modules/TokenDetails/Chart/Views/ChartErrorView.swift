import SnapKit
import SwiftUI
import TKUIKit
import UIKit

final class ChartErrorView: UIView, ConfigurableView {
    private let hostingView = SwiftUIHostingView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - ConfigurableView

    struct Model {
        let title: String?
        let buttons: ChartBottomButtonsView.Config?
    }

    func configure(model: Model) {
        hostingView.setContent {
            VStack(spacing: 0) {
                ChartErrorContentView(title: model.title)

                if let buttons = model.buttons {
                    ChartBottomButtonsView(config: buttons)
                }
            }
        }
    }
}

private extension ChartErrorView {
    func setup() {
        addSubview(hostingView)
        setupConstraints()
    }

    func setupConstraints() {
        hostingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
