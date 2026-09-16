import Foundation
import KeeperCore
import UIKit

protocol BatteryPromocodeInputModuleOutput: AnyObject {
    var didUpdateResolvingState: ((BatteryPromocodeResolveState) -> Void)? { get set }
}

final class BatteryPromocodeInputViewModel: ObservableObject, BatteryPromocodeInputModuleOutput {
    // MARK: - BatteryPromocodeInputModuleOutput

    var didUpdateResolvingState: ((BatteryPromocodeResolveState) -> Void)?

    // MARK: - State

    enum Accessory {
        case none
        case loader
        case success
    }

    @Published private(set) var text = ""
    @Published private(set) var isValid = true
    @Published private(set) var accessory: Accessory = .none
    @Published var isFocused = false

    private var resolvingState: BatteryPromocodeResolveState = .none {
        didSet {
            didUpdateResolveState()
            didUpdateResolvingState?(resolvingState)
        }
    }

    private var isStarted = false
    private var resolvingTask: Task<Void, Never>?

    // MARK: - Dependencies

    private let wallet: Wallet
    private let batteryService: BatteryService
    private let batteryPromocodeStore: BatteryPromocodeStore

    init(
        wallet: Wallet,
        batteryService: BatteryService,
        batteryPromocodeStore: BatteryPromocodeStore
    ) {
        self.wallet = wallet
        self.batteryService = batteryService
        self.batteryPromocodeStore = batteryPromocodeStore
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        batteryPromocodeStore.addObserver(self) { observer, _ in
            DispatchQueue.main.async {
                let state = observer.batteryPromocodeStore.state
                guard observer.resolvingState != state else { return }
                observer.resolvingState = state
            }
        }
        resolvingState = batteryPromocodeStore.state
    }

    // MARK: - Actions

    func setText(_ text: String) {
        guard text != self.text else { return }
        self.text = text
        isValid = true
        resolve(text: text)
    }

    func paste() {
        guard let pasteboardString = UIPasteboard.general.string else { return }
        text = pasteboardString
        isFocused = false
        resolve(text: pasteboardString)
    }

    func endEditing() {
        isFocused = false
    }

    // MARK: - Resolving

    private func resolve(text: String?) {
        if let resolvingTask {
            resolvingTask.cancel()
        }

        batteryPromocodeStore.setResolveState(.none)

        guard let text, !text.isEmpty else {
            return
        }

        resolvingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            self.resolvingState = .resolving(promocode: text)
            await batteryPromocodeStore.setResolveState(.resolving(promocode: text))
            do {
                try await batteryService.verifyPromocode(wallet: wallet, promocode: text)
                self.resolvingState = .success(promocode: text)
                await batteryPromocodeStore.setResolveState(.success(promocode: text))
            } catch {
                self.resolvingState = .failed(promocode: text)
                await batteryPromocodeStore.setResolveState(.failed(promocode: text))
            }
        }
    }

    private func didUpdateResolveState() {
        switch resolvingState {
        case .none:
            isValid = true
            accessory = .none
        case let .success(promocode):
            isValid = true
            accessory = .success
            if text.isEmpty {
                text = promocode
            }
        case let .failed(promocode):
            isValid = false
            accessory = .none
            if text.isEmpty {
                text = promocode
            }
        case let .resolving(promocode):
            isValid = true
            accessory = .loader
            if text.isEmpty {
                text = promocode
            }
        }
    }
}
