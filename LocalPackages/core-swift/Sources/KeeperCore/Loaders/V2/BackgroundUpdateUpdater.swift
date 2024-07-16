import Foundation
import TonStreamingAPI
import EventSource
import TonSwift
import OpenAPIRuntime

public actor BackgroundUpdateUpdater {
  public struct BackgroundUpdateEvent {
    public let accountAddress: Address
    public let lt: Int64
    public let txHash: String
  }
  
  private var task: Task<Void, Never>?
  private let jsonDecoder = JSONDecoder()
  private var observations = [UUID: (BackgroundUpdateEvent) -> Void]()

  private let backgroundUpdateStore: BackgroundUpdateStoreV2
  private let streamingAPI: TonStreamingAPI.Client
  
  init(backgroundUpdateStore: BackgroundUpdateStoreV2,
       streamingAPI: TonStreamingAPI.Client) {
    self.backgroundUpdateStore = backgroundUpdateStore
    self.streamingAPI = streamingAPI
  }
  
  public func start(addresses: [Address]) {
    let state = backgroundUpdateStore.getState()
    switch state {
    case .connecting(let connectingAddresses):
      guard addresses != connectingAddresses else { return }
      connect(addresses: addresses)
    case .connected(let connectedAddresses):
      guard addresses != connectedAddresses else { return }
      connect(addresses: addresses)
    case .disconnected:
      connect(addresses: addresses)
    case .noConnection:
      connect(addresses: addresses)
    }
  }
  
  public func stop() async {
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
        await backgroundUpdateStore.updateState { _ in
          Store.StateUpdate(newState: .connecting(addresses: addresses))
        }
        let stream = try await EventSource.eventSource {
          let response = try await self.streamingAPI.getTransactions(
            query: .init(accounts: [rawAddresses])
          )
          return try response.ok.body.text_event_hyphen_stream
        }
        
        guard !Task.isCancelled else { return }
        
        await backgroundUpdateStore.updateState { _ in
          Store.StateUpdate(newState: .connected(addresses: addresses))
        }
        for try await events in stream {
          handleReceivedEvents(events)
        }
        await backgroundUpdateStore.updateState { _ in
          Store.StateUpdate(newState: .disconnected)
        }
        guard !Task.isCancelled else { return }
        connect(addresses: addresses)
      } catch {
        if error.isNoConnectionError {
          await backgroundUpdateStore.updateState { _ in
            Store.StateUpdate(newState: .noConnection)
          }
        } else {
          await backgroundUpdateStore.updateState { _ in
            Store.StateUpdate(newState: .disconnected)
          }
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
    case let urlError as URLError:
      switch urlError.code {
      case URLError.Code.cancelled:
        return true
      default: return false
      }
    case let clientError as OpenAPIRuntime.ClientError:
      return clientError.underlyingError.isCancelledError
    default:
      return false
    }
  }
}

