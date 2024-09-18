import Foundation
import TonStreamingAPI
import EventSource
import TonSwift

public actor WalletBackgroundUpdate {
  public struct Event {
    public let wallet: Wallet
    public let lt: Int64
    public let txHash: String
  }
  
  private var task: Task<Void, Never>?
  private var eventId: String?
  
  private let jsonDecoder = JSONDecoder()
  
  private let wallet: Wallet
  private let backgroundUpdateStore: BackgroundUpdateStore
  private let streamingAPI: StreamingAPI
  private let eventClosure: (Event) -> Void
  
  init(wallet: Wallet, 
       backgroundUpdateStore: BackgroundUpdateStore,
       streamingAPI: StreamingAPI,
       eventClosure: @escaping (Event) -> Void) {
    self.wallet = wallet
    self.backgroundUpdateStore = backgroundUpdateStore
    self.streamingAPI = streamingAPI
    self.eventClosure = eventClosure
  }
  
  func start() {
    task?.cancel()
    task = nil
    
    let task = Task {
      do {
        let address = try wallet.address
        print("Log 🪵: WalletBackgroundUpdate - \(wallet.label) — connecting")
        await backgroundUpdateStore.setConnectionState(.connecting, wallet: wallet)
        let stream = try await streamingAPI.accountsTransactionsStream(accounts: [address.toRaw()])
        guard !Task.isCancelled else { return }
        print("Log 🪵: WalletBackgroundUpdate - \(wallet.label) — connected")
        await backgroundUpdateStore.setConnectionState(.connected, wallet: wallet)
        for try await events in stream {
          print("Log 🪵: WalletBackgroundUpdate - \(wallet.label) — recieved events \(events)")
          handleReceivedEvents(events)
        }
        print("Log 🪵: WalletBackgroundUpdate - \(wallet.label) — disconnected")
        await backgroundUpdateStore.setConnectionState(.disconnected, wallet: wallet)
        guard !Task.isCancelled else { return }
        start()
      } catch {
        guard !error.isCancelledError else { return }
        if error.isNoConnectionError {
          print("Log 🪵: WalletBackgroundUpdate - \(wallet.label) — no connection")
          await backgroundUpdateStore.setConnectionState(.noConnection, wallet: wallet)
        } else {
          print("Log 🪵: WalletBackgroundUpdate - \(wallet.label) — disconnected")
          await backgroundUpdateStore.setConnectionState(.disconnected, wallet: wallet)
          try? await Task.sleep(nanoseconds: 3_000_000_000)
          self.start()
        }
      }
    }
    
    self.task = task
  }
  
  func stop() {
    task?.cancel()
    task = nil
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
      let event = Event(
        wallet: wallet,
        lt: eventTransaction.lt,
        txHash: eventTransaction.txHash
      )
      eventClosure(event)
    } catch {
      return
    }
  }
}
