import TKUIKit
import UIKit

final class TokenDetailsHeaderViewController: UIViewController {
    let informationView = TokenDetailsInformationView()
    let buttonsView = TokenDetailsHeaderButtonsView()
    let bannerContainer = UIStackView()
    let chartContainer = UIView()

    private let stackView = UIStackView()
    private let shouldReserveChartSpace: Bool

    init(shouldReserveChartSpace: Bool) {
        self.shouldReserveChartSpace = shouldReserveChartSpace
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        stackView.axis = .vertical

        bannerContainer.axis = .vertical

        view.addSubview(stackView)

        stackView.addArrangedSubview(informationView)
        stackView.addArrangedSubview(buttonsView)
        stackView.addArrangedSubview(bannerContainer)
        stackView.addArrangedSubview(chartContainer)

        stackView.snp.makeConstraints { make in
            make.edges.equalTo(view)
        }

        if shouldReserveChartSpace {
            chartContainer.snp.makeConstraints { make in
                make.height.equalTo(Layout.chartContainerHeight)
            }
        }
    }

    func embedChartViewController(_ chartViewController: UIViewController) {
        addChild(chartViewController)
        chartContainer.addSubview(chartViewController.view)
        chartViewController.didMove(toParent: self)

        chartViewController.view.translatesAutoresizingMaskIntoConstraints = false

        chartContainer.snp.removeConstraints()
        chartViewController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

private extension TokenDetailsHeaderViewController {
    enum Layout {
        static let chartContainerHeight: CGFloat = TKUIKit.ChartView.height(showsBottomButtons: true)
    }
}
