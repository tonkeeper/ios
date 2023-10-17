//
//  InAppBrowserMainInAppBrowserMainPresenter.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 18/08/2023.
//

import UIKit

final class InAppBrowserMainPresenter {
  
  enum MenuItem: CaseIterable {
    case refresh
    case share
    case copy
    
    var title: String? {
      switch self {
      case .copy: return "Copy link"
      case .refresh: return "Refresh"
      case .share: return "Share"
      }
    }
    
    var icon: UIImage? {
      switch self {
      case .copy: return .Icons.InAppBrowser.Menu.copy
      case .refresh: return .Icons.InAppBrowser.Menu.refresh
      case .share: return .Icons.InAppBrowser.Menu.share
      }
    }
  }
  
  // MARK: - Module
  
  weak var viewInput: InAppBrowserMainViewInput?
  weak var output: InAppBrowserMainModuleOutput?
  
  // MARK: - Dependencies
  
  private var url: URL
  
  // MARK: - State
  
  init(url: URL) {
    self.url = url
  }
}

// MARK: - InAppBrowserMainPresenterIntput

extension InAppBrowserMainPresenter: InAppBrowserMainPresenterInput {
  func viewDidLoad() {
    viewInput?.loadURLRequest(URLRequest(url: url))
  }
  
  func didTapMenuButton() {
    let menuItems = MenuItem.allCases.map {
      TKMenuItem(
        icon: .image($0.icon, tinColor: .Accent.blue, backgroundColor: nil),
        iconPosition: .right,
        iconSide: .menuIconSide,
        iconCornerRadius: 0,
        leftTitle: $0.title,
        rightTitle: nil,
        isSelected: false)
    }
    viewInput?.showMenu(with: menuItems)
  }
  
  func didTapCloseButton() {
    output?.inAppBrowserMainDidFinish(self)
  }
  
  func didChangeURL(_ url: URL) {
    self.url = url
  }
  
  func didPullToRefresh() {
    viewInput?.loadURLRequest(URLRequest(url: url))
  }
  
  func didSelectMenuItem(at index: Int) {
    switch MenuItem.allCases[index] {
    case .refresh:
      viewInput?.loadURLRequest(URLRequest(url: url))
    case .copy:
      UIPasteboard.general.string = url.absoluteString
    case .share:
      viewInput?.shareURL(url)
    }
  }
}

// MARK: - InAppBrowserMainModuleInput

extension InAppBrowserMainPresenter: InAppBrowserMainModuleInput {}

// MARK: - Private

private extension InAppBrowserMainPresenter {}

private extension CGFloat {
  static let menuIconSide: CGFloat = 16
}
