import Foundation
import UIKit
import TKUIKit
import KeeperCore

struct StakingLinksViewModelBuilder {
  func buildModel(poolInfo: StackingPoolInfo,
                  openURL: @escaping (URL) -> Void,
                  openURLInApp: @escaping (URL) -> Void) -> StakingDetailsLinksView.Model {
    var linkItems = [StakingDetailsLinksView.Model.LinkItem]()
    if let url = URL(string: poolInfo.implementation.urlString),
       let host = url.host {
      let urlButton = StakingDetailsLinksView.Model.LinkItem(title: host, icon: .TKUIKit.Icons.Size16.globe) {
        openURLInApp(url)
      }
      linkItems.append(urlButton)
    }
    
    for social in poolInfo.implementation.socials {
      guard let url = URL(string: social),
            let host = url.host else {
        continue
      }
      let icon: UIImage
      let title: String
      let action: () -> Void
      switch host {
      case "t.me":
        icon = .TKUIKit.Icons.Size16.telegram
        title = "Community"
        action = {
          openURL(url)
        }
      case "twitter.com":
        icon = .TKUIKit.Icons.Size16.twitter
        title = "Twitter"
        action = {
          openURL(url)
        }
      default:
        continue
      }
      
      let button = StakingDetailsLinksView.Model.LinkItem(title: title, icon: icon, action: action)
      linkItems.append(button)
    }
    
    let tonviewerUrlString = "https://tonviewer.com/\(poolInfo.address.toRaw())"
    if let tonviewerUrl = URL(string: tonviewerUrlString) {
      let urlButton = StakingDetailsLinksView.Model.LinkItem(title: "tonviewer.com", icon: .TKUIKit.Icons.Size16.magnifyingGlass) {
        openURLInApp(tonviewerUrl)
      }
      linkItems.append(urlButton)
    }
    
    return StakingDetailsLinksView.Model(
      header: TKListTitleView.Model(title: "Links", textStyle: .h3),
      linkItems: linkItems
    )
  }
}
