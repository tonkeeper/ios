import Foundation
import TonStreamingAPI
import EventSource

public final class WalletBackgroundUpdate {
  
  @Atomic public var eventClosure: ((BackgroundUpdateEvent) -> Void)?
  @Atomic public var stateClosure: ((BackgroundUpdateConnectionState) -> Void)?
  
  @Atomic public var state: BackgroundUpdateConnectionState = .connecting {
    didSet {
      logState(state: state)
      stateClosure?(state)
    }
  }
  
  @Atomic private var eventId: String?
  private var task: Task<Void, Never>?
  
  private let jsonDecoder = JSONDecoder()
  
  private let wallet: Wallet
  private let streamingAPIProvider: StreamingAPIProvider
  
  init(wallet: Wallet, 
       streamingAPIProvider: StreamingAPIProvider) {
    self.wallet = wallet
    self.streamingAPIProvider = streamingAPIProvider
  }
  
  func start() {
    self.task?.cancel()
    
    let task = Task {
      do {
        let address = try wallet.address
        
        self.state = .connecting
        
        let stream = try await streamingAPIProvider.api(wallet.isTestnet).accountTransactionsStream(account: address.toRaw())
        try Task.checkCancellation()
        self.state = .connected
        
        for try await events in stream {
          handleReceivedEvents(events)
        }
        
        self.state = .disconnected
        
        try Task.checkCancellation()
        await MainActor.run {
          start()
        }
      } catch {
        guard !error.isCancelledError else { return }
        if error.isNoConnectionError {
          state = .noConnection
        } else {
          state = .disconnected
          try? await Task.sleep(nanoseconds: 3_000_000_000)
          await MainActor.run {
            self.start()
          }
        }
      }
    }
    self.task = task
  }
  
  func stop() {
    task?.cancel()
  }
  
  private func handleReceivedEvents(_ events: [EventSource.Event]) {
    guard let messageEvent = events.last(where: { $0.event == "message" }),
          let eventId = messageEvent.id,
          let eventData = messageEvent.data?.data(using: .utf8) else {
      return
    }
    
    self.eventId = eventId
    
    do {
      let eventTransaction = try jsonDecoder.decode(EventSource.Transaction.self, from: eventData)
      let event = BackgroundUpdateEvent(
        wallet: wallet,
        lt: eventTransaction.lt,
        txHash: eventTransaction.txHash
      )
      eventClosure?(event)
    } catch {
      return
    }
  }
  
  private func logState(state: BackgroundUpdateConnectionState) {
    switch state {
    case .connecting:
      print("Log 🪵: WalletBackgroundUpdate - \(wallet.label) — connecting")
    case .connected:
      print("Log 🪵: WalletBackgroundUpdate - \(wallet.label) — connected")
    case .disconnected:
      print("Log 🪵: WalletBackgroundUpdate - \(wallet.label) — disconnected")
    case .noConnection:
      print("Log 🪵: WalletBackgroundUpdate - \(wallet.label) — no connection")
    }
  }
}
