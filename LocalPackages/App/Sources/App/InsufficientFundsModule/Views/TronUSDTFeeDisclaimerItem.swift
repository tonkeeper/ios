import TKUIKit
import UIKit

struct TronUSDTFeeDisclaimerItem: TKPopUp.Item {
    var text: NSAttributedString
    var actionText: String
    var action: () -> Void
    var horizontalPadding: CGFloat
    var bottomSpace: CGFloat

    func getView() -> UIView {
        let label = TKActionLabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.setAttributedText(
            text,
            actionItems: [
                TKActionLabel.ActionItem(
                    text: actionText,
                    action: action
                ),
            ]
        )

        let container = UIView()
        container.addSubview(label)
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(
                top: 0,
                left: horizontalPadding,
                bottom: 0,
                right: horizontalPadding
            ))
        }

        return container
    }
}
