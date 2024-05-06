import UIKit

struct BuySellListItemMapper {
  
  func mapPaymentMethodItem(_ item: PaymentMethodItemsModel.Item) -> PaymentMethodItemCell.Configuration {
    let id = item.identifier
    let title = makePaymentItemTitle(item.title)
    
    let paymentContentConfiguration = PaymentMethodItemCellContentView.Configuration(contentModel:
        .init(
          title: title,
          paymentIcon: item.image
        )
    )
    
    return PaymentMethodItemCell.Configuration(
      id: id,
      contentConfiguration: paymentContentConfiguration
    )
  }
  
  private func makePaymentItemTitle(_ titleString: String) -> NSAttributedString {
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
