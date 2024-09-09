import Foundation
import TonStreamingAPI
import EventSource
import TonSwift
import OpenAPIRuntime
import TonAPI

public actor BackgroundUpdateUpdater {
  public struct BackgroundUpdateEvent {
    public let accountAddress: Address
    public let lt: Int64
    public let txHash: String
  }
  
  private var task: Task<Void, Never>?
  private let jsonDecoder = JSONDecoder()
  private var observations = [UUID: (BackgroundUpdateEvent) -> Void]()

  private let backgroundUpdateStore: BackgroundUpdateStoreV3
  private let walletsStore: WalletsStore
  private let streamingAPI: TonStreamingAPI.Client
  
  init(backgroundUpdateStore: BackgroundUpdateStoreV3,
       walletsStore: WalletsStore,
       streamingAPI: TonStreamingAPI.Client) {
    self.backgroundUpdateStore = backgroundUpdateStore
    self.walletsStore = walletsStore
    self.streamingAPI = streamingAPI
  }
  
  public func start() {
    walletsStore.addObserver(self) { observer, event in
      switch event {
      case .didChangeActiveWallet(let wallet):
        Task {
          guard let address = try? wallet.address else { return }
          self.connect(addresses: [address])
        }
      default: break
      }
    }
    guard let activeWalletAddress = try? walletsStore.getActiveWallet().address else { return }
    connect(addresses: [activeWalletAddress])
  }
  
  public func stop() {
    task?.cancel()
    task = nil
  }
  
  @discardableResult
  nonisolated
  public func addEventObserver<T: AnyObject>(_ observer: T,
                                      closure: @escaping (T, BackgroundUpdateEvent) -> Void) -> ObservationToken {
    let id = UUID()
    let eventHandler: (BackgroundUpdateEvent) -> Void = { [weak self, weak observer] event in
      guard let self else { return }
      guard let observer else {
        Task { await self.removeObservation(key: id) }
        return
      }
      
      closure(observer, event)
    }
    
    Task {
      await addObserver(eventHandler, key: id)
    }
    
    return ObservationToken { [weak self] in
      guard let self else { return }
      Task { await self.removeObservation(key: id) }
    }
  }
  
  func addObserver(_ eventHandler: @escaping (BackgroundUpdateEvent) -> Void, key: UUID) {
    observations[key] = eventHandler
  }
  
  func removeObservation(key: UUID) {
    observations.removeValue(forKey: key)
  }
}

private extension BackgroundUpdateUpdater {
  func connect(addresses: [Address]) {
    self.task?.cancel()
    self.task = nil
    
    let task = Task {
      let rawAddresses = addresses.map { $0.toRaw() }.joined(separator: ",")
      
      do {
        await backgroundUpdateStore.setState(.connecting)
        print("Log 🪵: BackgroundUpdateUpdater — connecting")
        let stream = try await EventSource.eventSource {
          let response = try await self.streamingAPI.getTransactions(
            query: .init(accounts: [rawAddresses])
          )
          return try response.ok.body.text_event_hyphen_stream
        }
        
        guard !Task.isCancelled else { return }
        
        await backgroundUpdateStore.setState(.connected)
        print("Log 🪵: BackgroundUpdateUpdater — connected")
        for try await events in stream {
          print("Log 🪵: BackgroundUpdateUpdater — recieved events \(events)")
          handleReceivedEvents(events)
        }
        await backgroundUpdateStore.setState(.disconnected)
        print("Log 🪵: BackgroundUpdateUpdater — disconnected")
        guard !Task.isCancelled else { return }
        connect(addresses: addresses)
      } catch {
        guard !error.isCancelledError else { return }
        if error.isNoConnectionError {
          await backgroundUpdateStore.setState(.noConnection)
          print("Log 🪵: BackgroundUpdateUpdater — no connection")
        } else {
          await backgroundUpdateStore.setState(.disconnected)
          print("Log 🪵: BackgroundUpdateUpdater — disconnected")
          try? await Task.sleep(nanoseconds: 3_000_000_000)
          self.connect(addresses: addresses)
        }
      }
    }
    self.task = task
  }
  
  func handleReceivedEvents(_ events: [EventSource.Event]) {
    guard let messageEvent = events.last(where: { $0.event == "message" }),
          let eventData = messageEvent.data?.data(using: .utf8) else {
      return
    }
    do {
      let eventTransaction = try jsonDecoder.decode(EventSource.Transaction.self, from: eventData)
      let address = try Address.parse(eventTransaction.accountId)
      let updateEvent = BackgroundUpdateEvent(
        accountAddress: address,
        lt: eventTransaction.lt,
        txHash: eventTransaction.txHash
      )
      observations.values.forEach { $0(updateEvent) }
    } catch {
      return
    }
  }
}

public extension Swift.Error {
  var isNoConnectionError: Bool {
    switch self {
    case let urlError as URLError:
      switch urlError.code {
      case URLError.Code.notConnectedToInternet,
        URLError.Code.networkConnectionLost:
        return true
      default: return false
      }
    case let clientError as OpenAPIRuntime.ClientError:
      return clientError.underlyingError.isNoConnectionError
    default:
      return false
    }
  }
  
  var isCancelledError: Bool {
    switch self {
    case let cancellationError as CancellationError:
      return true
    case let urlError as URLError:
      switch urlError.code {
      case URLError.Code.cancelled:
        return true
      default: return false
      }
    case let clientError as OpenAPIRuntime.ClientError:
      return clientError.underlyingError.isCancelledError
    case let tonApiErrorResponse as TonAPI.ErrorResponse:
      switch tonApiErrorResponse {
      case .error(_, _, _, let error):
        return error.isCancelledError
      }
    default:
      return false
    }
  }
}

