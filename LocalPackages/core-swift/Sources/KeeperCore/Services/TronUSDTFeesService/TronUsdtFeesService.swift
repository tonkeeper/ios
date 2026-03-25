import BigInt
import Foundation
import TonSwift
import TronSwift

public protocol TronUsdtFeesService: AnyObject {
    func start()
    func stop()
    func refresh(wallet: Wallet) async
    func refreshActiveWallet() async
    func snapshot(wallet: Wallet, balance: ProcessedBalance?) -> TronUsdtFeesSnapshot?
    func addUpdateObserver<T: AnyObject>(
        _ observer: T,
        closure: @escaping (T, Wallet) -> Void
    )
}

final class TronUSDTFeesServiceImplementation: TronUsdtFeesService {
    private struct FeesEstimate: Equatable {
        let batteryCharges: Int
        let trxSun: BigUInt
        let tonNano: BigUInt?
    }

    private let syncQueue = DispatchQueue(label: "TronUSDTFeesServiceImplementationQueue")

    private var observers = [UUID: (Wallet) -> Void]()
    private var feesEstimates = [Wallet: FeesEstimate]()
    private var refreshTasks = [Wallet: Task<Void, Never>]()
    private var periodicRefreshTask: Task<Void, Never>?
    private var isStarted = false

    private let tronUsdtApi: TronUSDTAPI
    private let walletsStore: WalletsStore
    private let batteryCalculation: BatteryCalculation
    private let configuration: Configuration
    private let refreshIntervalNanoseconds: UInt64

    init(
        tronUsdtApi: TronUSDTAPI,
        walletsStore: WalletsStore,
        batteryCalculation: BatteryCalculation,
        configuration: Configuration,
        refreshIntervalNanoseconds: UInt64 = 60_000_000_000
    ) {
        self.tronUsdtApi = tronUsdtApi
        self.walletsStore = walletsStore
        self.batteryCalculation = batteryCalculation
        self.configuration = configuration
        self.refreshIntervalNanoseconds = refreshIntervalNanoseconds

        walletsStore.addObserver(self) { observer, event in
            observer.handleWalletsStoreEvent(event)
        }

        configuration.addUpdateObserver(self) { observer in
            observer.handleConfigurationUpdate()
        }
    }

    func start() {
        let shouldStart = syncQueue.sync { () -> Bool in
            guard !isStarted else {
                return false
            }
            isStarted = true
            return true
        }
        guard shouldStart else { return }

        let task = Task { [weak self] in
            guard let self else { return }
            await refreshActiveWallet()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: refreshIntervalNanoseconds)
                guard !Task.isCancelled else { return }
                await refreshActiveWallet()
            }
        }
        syncQueue.sync {
            periodicRefreshTask = task
        }
    }

    func stop() {
        let tasksToCancel = syncQueue.sync { () -> [Task<Void, Never>] in
            guard isStarted else {
                return []
            }
            isStarted = false

            var tasks = [Task<Void, Never>]()
            if let periodicRefreshTask {
                tasks.append(periodicRefreshTask)
            }
            tasks.append(contentsOf: refreshTasks.values)

            periodicRefreshTask = nil
            refreshTasks.removeAll()

            return tasks
        }

        tasksToCancel.forEach { $0.cancel() }
    }

    func refreshActiveWallet() async {
        guard let wallet = try? walletsStore.activeWallet else { return }
        await refresh(wallet: wallet)
    }

    func refresh(wallet: Wallet) async {
        let task = syncQueue.sync { () -> Task<Void, Never> in
            if let refreshTask = refreshTasks[wallet] {
                return refreshTask
            }

            let task = Task<Void, Never> { [weak self] in
                guard let self else { return }
                await performRefresh(wallet: wallet)
            }
            refreshTasks[wallet] = task
            return task
        }

        await task.value
    }

    func snapshot(wallet: Wallet, balance: ProcessedBalance?) -> TronUsdtFeesSnapshot? {
        guard let feesEstimate = syncQueue.sync(execute: { feesEstimates[wallet] }) else {
            return nil
        }

        let requiredBatteryCharges = feesEstimate.batteryCharges

        let requiredTON = feesEstimate.tonNano ?? calculateRequiredTON(
            network: wallet.network,
            requiredBatteryCharges: requiredBatteryCharges
        )

        let batteryChargesBalance: Int = {
            guard
                let batteryBalance = balance?.batteryBalance,
                !batteryBalance.isBalanceZero
            else {
                return 0
            }

            return batteryCalculation.calculateCharges(
                tonAmount: batteryBalance.balanceDecimalNumber
            ) ?? 0
        }()
        let batteryFillPercent = balance?.batteryBalance?.batteryState.percents ?? 0

        let trxBalance = balance?.tronUSDTItem?.trxAmount ?? 0
        let tonBalance = BigUInt(balance?.tonItem.amount ?? 0)

        return TronUsdtFeesSnapshot(
            isTRXOnlyRegion: configuration.isTRXOnlyRegion(network: wallet.network),
            requiredTRX: feesEstimate.trxSun,
            trxBalance: trxBalance,
            requiredBatteryCharges: requiredBatteryCharges,
            batteryChargesBalance: batteryChargesBalance,
            batteryFillPercent: batteryFillPercent,
            requiredTON: requiredTON,
            tonBalance: tonBalance
        )
    }

    func addUpdateObserver<T: AnyObject>(
        _ observer: T,
        closure: @escaping (T, Wallet) -> Void
    ) {
        let id = UUID()
        let observerClosure: (Wallet) -> Void = { [weak self, weak observer] wallet in
            guard let self else { return }
            guard let observer else {
                _ = self.syncQueue.sync {
                    self.observers.removeValue(forKey: id)
                }
                return
            }
            closure(observer, wallet)
        }
        syncQueue.sync {
            observers[id] = observerClosure
        }
    }
}

private extension TronUSDTFeesServiceImplementation {
    func handleConfigurationUpdate() {
        guard syncQueue.sync(execute: { isStarted }) else { return }

        let walletsToNotify = syncQueue.sync { Array(feesEstimates.keys) }
        walletsToNotify.forEach { notifyObservers(wallet: $0) }

        Task { [weak self] in
            await self?.refreshActiveWallet()
        }
    }

    func handleWalletsStoreEvent(_ event: WalletsStore.Event) {
        guard syncQueue.sync(execute: { isStarted }) else { return }

        switch event {
        case let .didChangeActiveWallet(from: previousWallet, to: activeWallet):
            guard previousWallet != activeWallet else { return }
            Task { [weak self] in
                await self?.refreshActiveWallet()
            }
        default:
            break
        }
    }

    func performRefresh(wallet: Wallet) async {
        defer {
            syncQueue.sync {
                refreshTasks[wallet] = nil
            }
        }

        guard let tronAddress = wallet.tron?.address else {
            let didChange = syncQueue.sync {
                feesEstimates.removeValue(forKey: wallet) != nil
            }
            guard didChange else { return }
            notifyObservers(wallet: wallet)
            return
        }

        do {
            let estimate = try await tronUsdtApi.estimateTransferFees(
                address: tronAddress,
                method: TransferMethod(
                    to: tronAddress,
                    amount: 1
                )
            )

            let newEstimate = FeesEstimate(
                batteryCharges: estimate.requiredBatteryCharges,
                trxSun: estimate.requiredTRXSun,
                tonNano: estimate.requiredTONAmountNano
            )

            let didChange = syncQueue.sync { () -> Bool in
                let oldEstimate = feesEstimates[wallet]
                feesEstimates[wallet] = newEstimate
                return oldEstimate != newEstimate
            }
            guard didChange else { return }
            notifyObservers(wallet: wallet)
        } catch {
            return
        }
    }

    func notifyObservers(wallet: Wallet) {
        let observers = syncQueue.sync { self.observers }
        observers.forEach { $0.value(wallet) }
    }

    func calculateRequiredTON(
        network: Network,
        requiredBatteryCharges: Int
    ) -> BigUInt {
        guard let batteryMeanFees = configuration.batteryMeanFeesDecimaNumber(
            network: network
        ) else {
            return 0
        }

        let tonAmount = batteryMeanFees.multiplying(
            by: NSDecimalNumber(value: requiredBatteryCharges)
        )
        let nanoAmount = tonAmount
            .multiplying(
                byPowerOf10: Int16(TonInfo.fractionDigits)
            )
            .rounding(
                accordingToBehavior: NSDecimalNumberHandler(
                    roundingMode: .up,
                    scale: 0,
                    raiseOnExactness: false,
                    raiseOnOverflow: false,
                    raiseOnUnderflow: false,
                    raiseOnDivideByZero: false
                )
            )

        return BigUInt(nanoAmount.stringValue) ?? 0
    }
}
