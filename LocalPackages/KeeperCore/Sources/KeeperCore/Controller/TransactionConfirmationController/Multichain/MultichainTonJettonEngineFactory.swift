import BigInt
import TonSwift

final class MultichainTonJettonEngineFactory {
    private let api: API
    private let sendService: SendService
    private let blockchainService: BlockchainService
    private let ratesStore: TonRatesStore
    private let currencyStore: CurrencyStore
    private let transferService: TransferService
    private let balanceService: BalanceService
    private let settingsRepository: SettingsRepository
    private let batteryCalculation: BatteryCalculation

    init(
        api: API,
        sendService: SendService,
        blockchainService: BlockchainService,
        ratesStore: TonRatesStore,
        currencyStore: CurrencyStore,
        transferService: TransferService,
        balanceService: BalanceService,
        settingsRepository: SettingsRepository,
        batteryCalculation: BatteryCalculation
    ) {
        self.api = api
        self.sendService = sendService
        self.blockchainService = blockchainService
        self.ratesStore = ratesStore
        self.currencyStore = currencyStore
        self.transferService = transferService
        self.balanceService = balanceService
        self.settingsRepository = settingsRepository
        self.batteryCalculation = batteryCalculation
    }

    func makeController(
        wallet: Wallet,
        recipient: String,
        master: String,
        amount: BigUInt,
        comment: String?
    ) async -> JettonTransferTransactionConfirmationController? {
        guard let recipientAddress = try? Address.parse(recipient),
              let masterAddress = try? Address.parse(master),
              let jettonItem = await jettonItem(wallet: wallet, masterAddress: masterAddress)
        else {
            return nil
        }

        return JettonTransferTransactionConfirmationController(
            wallet: wallet,
            recipient: TonRecipient(
                recipientAddress: .raw(recipientAddress),
                isMemoRequired: false,
                isScam: false
            ),
            jettonItem: jettonItem,
            amount: amount,
            comment: comment,
            recipientDisplayAddress: recipient,
            sendService: sendService,
            blockchainService: blockchainService,
            ratesStore: ratesStore,
            currencyStore: currencyStore,
            transferService: transferService,
            balanceService: balanceService,
            settingsRepository: settingsRepository,
            batteryCalculation: batteryCalculation,
            buildsFeeOptions: true
        )
    }

    private func jettonItem(wallet: Wallet, masterAddress: Address) async -> JettonItem? {
        if let walletBalance = try? balanceService.getBalance(wallet: wallet),
           let item = walletBalance.balance.jettonsBalance.first(
               where: { $0.item.jettonInfo.address == masterAddress }
           )?.item
        {
            return item
        }

        do {
            let info = try await api.resolveJetton(address: masterAddress)
            let walletAddress = try await blockchainService.getWalletAddress(
                jettonMaster: masterAddress.toRaw(),
                owner: wallet.address.toRaw(),
                network: wallet.network
            )
            return JettonItem(jettonInfo: info, walletAddress: walletAddress)
        } catch {
            return nil
        }
    }
}
