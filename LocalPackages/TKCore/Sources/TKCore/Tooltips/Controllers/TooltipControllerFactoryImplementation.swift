import Foundation
import KeeperCore

final class TooltipControllerFactoryImplementation {
    private let commonTooltipsRepository: TooltipDataRepository
    private let withdrawTooltipRepository: WithdrawButtonTooltipRepository
    private let newHistoryEntryPointTooltipRepository: NewHistoryEntryPointTooltipRepository
    private let tradeTabTooltipRepository: TradeTabTooltipRepository
    private let favoriteTooltipRepository: FavoriteTooltipRepository
    private let addMultichainWalletTooltipRepository: AddMultichainWalletTooltipRepository
    private let calendar: Calendar

    private lazy var withdrawTooltipController = WithdrawTooltipController(
        commonTooltipsRepository: commonTooltipsRepository,
        withdrawTooltipRepository: withdrawTooltipRepository,
        calendar: calendar
    )
    private lazy var newHistoryEntryPointTooltipController = NewHistoryEntryPointTooltipController(
        commonTooltipsRepository: commonTooltipsRepository,
        newHistoryEntryPointTooltipRepository: newHistoryEntryPointTooltipRepository,
        calendar: calendar
    )
    private lazy var tradeTabTooltipController = TradeTabTooltipController(
        commonTooltipsRepository: commonTooltipsRepository,
        tradeTabTooltipRepository: tradeTabTooltipRepository,
        calendar: calendar
    )
    private lazy var favoriteTooltipController = FavoriteTooltipController(
        favoriteTooltipRepository: favoriteTooltipRepository
    )
    private lazy var addMultichainWalletMainTooltipController = AddMultichainWalletTooltipController(
        placement: .main,
        repository: addMultichainWalletTooltipRepository,
        calendar: calendar
    )
    private lazy var addMultichainWalletWalletsListTooltipController = AddMultichainWalletTooltipController(
        placement: .walletsList,
        repository: addMultichainWalletTooltipRepository,
        calendar: calendar
    )

    init(
        commonTooltipsRepository: TooltipDataRepository,
        withdrawTooltipRepository: WithdrawButtonTooltipRepository,
        newHistoryEntryPointTooltipRepository: NewHistoryEntryPointTooltipRepository,
        tradeTabTooltipRepository: TradeTabTooltipRepository,
        favoriteTooltipRepository: FavoriteTooltipRepository,
        addMultichainWalletTooltipRepository: AddMultichainWalletTooltipRepository,
        calendar: Calendar
    ) {
        self.commonTooltipsRepository = commonTooltipsRepository
        self.withdrawTooltipRepository = withdrawTooltipRepository
        self.newHistoryEntryPointTooltipRepository = newHistoryEntryPointTooltipRepository
        self.tradeTabTooltipRepository = tradeTabTooltipRepository
        self.favoriteTooltipRepository = favoriteTooltipRepository
        self.addMultichainWalletTooltipRepository = addMultichainWalletTooltipRepository
        self.calendar = calendar
    }
}

extension TooltipControllerFactoryImplementation: TooltipControllerFactory {
    func controller(for tooltipId: TooltipID) -> TooltipController {
        switch tooltipId {
        case .walletBalanceWithdraw:
            withdrawTooltipController
        case .newHistoryEntryPoint:
            newHistoryEntryPointTooltipController
        case .tradeTab:
            tradeTabTooltipController
        case .tradeFavorite:
            favoriteTooltipController
        case .addMultichainWalletMain:
            addMultichainWalletMainTooltipController
        case .addMultichainWalletWalletsList:
            addMultichainWalletWalletsListTooltipController
        }
    }
}
