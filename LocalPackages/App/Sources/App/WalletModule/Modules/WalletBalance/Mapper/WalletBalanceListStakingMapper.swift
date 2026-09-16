import Foundation
import KeeperCore
import TKUIKit

struct WalletBalanceListStakingMapper {
    private let commentMapper: StakingItemCommentMapper
    private let balanceItemMapper: BalanceItemMapper

    init(
        amountFormatter: AmountFormatter,
        balanceItemMapper: BalanceItemMapper
    ) {
        commentMapper = StakingItemCommentMapper(amountFormatter: amountFormatter)
        self.balanceItemMapper = balanceItemMapper
    }

    func mapStakingItem(
        _ item: ProcessedBalanceStakingItem,
        isSecure: Bool,
        isPinned: Bool,
        isStakingEnable: Bool,
        stakingCollectHandler: (() -> Void)?
    ) -> WalletBalanceListCell.Configuration {
        let commentConfiguration = commentMapper
            .comment(for: item, isSecure: isSecure)
            .map { comment in
                TKCommentView.Model(
                    comment: comment.text,
                    isEnable: isStakingEnable,
                    tapClosure: comment.isCollectable ? stakingCollectHandler : nil
                )
            }

        return WalletBalanceListCell.Configuration(
            walletBalanceListCellContentViewConfiguration:
            WalletBalanceListCellContentView.Configuration(
                listItemContentViewConfiguration: balanceItemMapper.mapStakingItem(item, isSecure: isSecure, isPinned: isPinned),
                commentViewConfiguration: commentConfiguration
            )
        )
    }
}
