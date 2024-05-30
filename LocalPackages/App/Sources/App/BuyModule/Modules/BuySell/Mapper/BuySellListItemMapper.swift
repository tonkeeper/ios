import UIKit
import TKUIKit

struct BuySellListItemMapper {
  func mapPaymentMethodItem(_ item: PaymentMethodItemsModel.Item, selectionClosure: @escaping () -> Void) -> SelectionCollectionViewCell.Configuration {
    let id = item.id
    let title = makePaymentMethodItemTitle(item.title)
    
    let contentConfiguration = TKUIListItemContentView.Configuration(
      leftItemConfiguration:
          .init(
            title: title,
            tagViewModel: nil,
            subtitle: nil,
            description: nil
          ),
      rightItemConfiguration: nil
    )
    
    let accessoryImageConfiguration = TKUIListItemImageAccessoryView.Configuration(
      image: item.image,
      tintColor: .clear,
      padding: .zero
    )
    
    let listItemConfiguration = TKUIListItemView.Configuration(
      iconConfiguration: .init(iconConfiguration: .none, alignment: .center),
      contentConfiguration: contentConfiguration,
      accessoryConfiguration: .image(accessoryImageConfiguration)
    )
    
    return SelectionCollectionViewCell.Configuration(
      id: id,
      listItemConfiguration: listItemConfiguration,
      accesoryConfiguration: .init(accessoryType: .radioButton),
      accesoryAlignment: .left,
      selectionClosure: selectionClosure
    )
  }
  
  private func makePaymentMethodItemTitle(_ titleString: String) -> NSAttributedString {
    let attributedString = titleString.withTextStyle(
      .label1,
      color: .Text.primary,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    let title = NSMutableAttributedString(attributedString: attributedString)

    if let dotLocation = [Character](title.string).firstIndex(where: { $0 == "·" }) {
      let range = NSRange(location: dotLocation, length: 1)
      title.addAttribute(.foregroundColor, value: UIColor.Text.tertiary, range: range)
    }
    
    return title
  }
}
