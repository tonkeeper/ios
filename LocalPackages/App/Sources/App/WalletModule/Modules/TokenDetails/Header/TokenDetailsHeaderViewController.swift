import TKUIKit
import UIKit

final class TokenDetailsHeaderViewController: UIViewController {
    let informationView = TokenDetailsInformationView()
    let buttonsView = TokenDetailsHeaderButtonsView()
    let bannerContainer = UIStackView()
    let chartContainer = UIView()

    private let stackView = UIStackView()

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
    }

    func embedChartViewController(_ chartViewController: UIViewController) {
        addChild(chartViewController)
        chartContainer.addSubview(chartViewController.view)
        chartViewController.didMove(toParent: self)

        chartViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            chartViewController.view.topAnchor.constraint(equalTo: chartContainer.topAnchor),
            chartViewController.view.leftAnchor.constraint(equalTo: chartContainer.leftAnchor),
            chartViewController.view.bottomAnchor.constraint(equalTo: chartContainer.bottomAnchor),
            chartViewController.view.rightAnchor.constraint(equalTo: chartContainer.rightAnchor),
        ])
    }
}
