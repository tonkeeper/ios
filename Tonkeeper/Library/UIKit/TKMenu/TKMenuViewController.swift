//
//  TKMenuViewController.swift
//  Tonkeeper
//
//  Created by Grigory on 10.7.23..
//

import UIKit

final class TKMenuViewController: UIViewController {
  
  var didTapToDismiss: (() -> Void)?
  var didSelectItem: ((_ itemIndex: Int) -> Void)?
  
  private let tableView = UITableView(frame: .zero, style: .plain)
  private let dismissView = UIView()
  private let imageLoader = NukeImageLoader()
  
  private let items: [TKMenuItem]
  private let origin: CGPoint
  private let menuWidth: CGFloat
  
  init(items: [TKMenuItem],
       origin: CGPoint,
       menuWidth: CGFloat) {
    self.items = items
    self.origin = origin
    self.menuWidth = menuWidth
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let dismissGesture = UITapGestureRecognizer(target: self, action: #selector(didTap))
    dismissView.addGestureRecognizer(dismissGesture)
    
    view.backgroundColor = .clear
    view.addSubview(dismissView)
    view.addSubview(tableView)
    
    tableView.layer.masksToBounds = true
    tableView.layer.cornerRadius = .cornerRadius
    tableView.register(TKMenuCell.self, forCellReuseIdentifier: "Cell")
    tableView.dataSource = self
    tableView.delegate = self
    tableView.backgroundColor = .Background.contentTint
    tableView.separatorColor = .Separator.common
    tableView.separatorInset.left = 16
    tableView.showsVerticalScrollIndicator = false
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    dismissView.frame = view.bounds
  }
  
  func showMenu(duration: TimeInterval) {
    let menuHeight: CGFloat = items.count > .maximumRows
    ? .heightCoeff * .menuItemHeight
    : CGFloat(items.count) * .menuItemHeight
    let frame = CGRect(origin: origin, size: .init(width: menuWidth, height: menuHeight))
    
    let initialTransformation = CGAffineTransform(scaleX: 0.9, y: 0.9)
    let finalTransformation = CGAffineTransform(scaleX: 1, y: 1)
    
    tableView.frame = frame
    tableView.alpha = .hideAlpha
    tableView.transform = initialTransformation
    
    UIView.animate(withDuration: duration,
                   delay: 0,
                   usingSpringWithDamping: 2,
                   initialSpringVelocity: 0.5,
                   options: .curveEaseInOut) {
      self.tableView.transform = finalTransformation
      self.tableView.alpha = 1
    }
  }
  
  func hideMenu(duration: TimeInterval, completion: @escaping () -> Void) {
    let finalTransform = CGAffineTransform(scaleX: 0.9, y: 0.9)
    UIView.animate(withDuration: duration,
                   delay: 0,
                   usingSpringWithDamping: 2,
                   initialSpringVelocity: 0.5,
                   options: .curveEaseInOut) {
      self.tableView.transform = finalTransform
      self.tableView.alpha = 0
    } completion: { _ in
      completion()
    }
  }
  
  @objc
  private func didTap() {
    didTapToDismiss?()
  }
}

extension TKMenuViewController: UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return items.count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as? TKMenuCell else {
      return UITableViewCell()
    }
    
    cell.imageLoader = imageLoader
    cell.configure(model: items[indexPath.row])
    return cell
  }
}

extension TKMenuViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    didSelectItem?(indexPath.row)
  }
  
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return .menuItemHeight
  }
}

private extension CGFloat {
  static let menuItemHeight: CGFloat = 48
  static let heightCoeff: CGFloat = 4.5
  static let cornerRadius: CGFloat = 16
  static let hideAlpha: CGFloat = 0.3
}

private extension Int {
  static let maximumRows = 4
}
