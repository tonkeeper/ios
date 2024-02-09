import UIKit
import TKUIKit

final class TokenDetailsHeaderViewController: UIViewController {
  
  let informationView = TokenDetailsInformationView()
  let buttonsView = TokenDetailsHeaderButtonsView()
  let chartContainer = UIView()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    view.addSubview(informationView)
    view.addSubview(buttonsView)
    view.addSubview(chartContainer)
    
    informationView.translatesAutoresizingMaskIntoConstraints = false
    buttonsView.translatesAutoresizingMaskIntoConstraints = false
    chartContainer.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      informationView.topAnchor.constraint(equalTo: view.topAnchor),
      informationView.leftAnchor.constraint(equalTo: view.leftAnchor),
      informationView.rightAnchor.constraint(equalTo: view.rightAnchor),
      
      buttonsView.topAnchor.constraint(equalTo: informationView.bottomAnchor),
      buttonsView.leftAnchor.constraint(equalTo: view.leftAnchor),
      buttonsView.rightAnchor.constraint(equalTo: view.rightAnchor),
      
      chartContainer.topAnchor.constraint(equalTo: buttonsView.bottomAnchor),
      chartContainer.leftAnchor.constraint(equalTo: view.leftAnchor),
      chartContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      chartContainer.rightAnchor.constraint(equalTo: view.rightAnchor)
    ])
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
      chartViewController.view.rightAnchor.constraint(equalTo: chartContainer.rightAnchor)
    ])
  }
}
