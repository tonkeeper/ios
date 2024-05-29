import Foundation

enum BrowserExploreSection: Hashable {
  case regular(title: String, hasAll: Bool, items: [AnyHashable])
  case featured(items: [BrowserExploreFeatureSectionItem])
}

enum BrowserExploreFeatureSectionItem: Hashable {
  case banner
}
