import Foundation

enum BrowserSearchSection: Hashable {
  case apps
  case newSearch(headerModel: BrowserSearchListSectionHeaderView.Model)
}
