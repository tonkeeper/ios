import FirebaseRemoteConfig
import TKLogging
import UIKit

public final class TKFirebaseRemoteConfigProvider {
    private let requestTimeoutMs: UInt64
    private let remoteConfig: RemoteConfig
    private let lock = NSLock()
    private var _keys: Set<String> = []

    public init(
        requestTimeoutMs: UInt64
    ) {
        self.requestTimeoutMs = requestTimeoutMs
        self.remoteConfig = .remoteConfig()
    }
}

extension TKFirebaseRemoteConfigProvider: RemoteConfigProvider {
    public func load() async {
        let waitForFetchBeforeActivate = remoteConfig.lastFetchStatus == .noFetchYet
        Log.i("loading remote config, waitForFetchBeforeActivate=\(waitForFetchBeforeActivate)")
        if waitForFetchBeforeActivate {
            await doLoad()
        } else {
            do {
                try await activateConfig()
            } catch {
                Log.w("failed to activate remote config", extraInfo: [
                    "failureReason": "\(error)",
                ])
            }
            Task {
                do {
                    try await remoteConfig.fetch()
                    Log.i("remote config fetched")
                } catch {
                    Log.w("failed to fetch remote config", extraInfo: [
                        "failureReason": "\(error)",
                    ])
                }
            }
        }
    }

    public subscript(_ flag: String) -> Bool? {
        guard keys.contains(flag) else {
            return nil
        }
        return remoteConfig.configValue(forKey: flag).boolValue
    }
}

extension TKFirebaseRemoteConfigProvider {
    private var keys: Set<String> {
        get {
            lock.withLock {
                _keys
            }
        }
        set {
            lock.withLock {
                _keys = newValue
            }
        }
    }

    private func doLoad() async {
        enum RemoteConfigLoadingError: Error {
            case failedToFetch(
                _ underlying: Error? = nil
            )
            case failedToActivate(
                _ underlying: Error? = nil
            )
            case deadlineExceeded
            case failedToSleep(
                _ underlying: Error? = nil
            )
        }
        do {
            try await withThrowingTaskGroup { group in
                group.addTask { [self] in
                    do {
                        try await remoteConfig.fetch()
                        Log.i("remote config fetched")
                    } catch {
                        throw RemoteConfigLoadingError.failedToFetch(error)
                    }
                    guard !Task.isCancelled else {
                        return
                    }
                    do {
                        try await activateConfig()
                    } catch {
                        throw RemoteConfigLoadingError.failedToActivate(error)
                    }
                }
                group.addTask { [self] in
                    do {
                        try await Task.sleep(nanoseconds: requestTimeoutMs * NSEC_PER_MSEC)
                    } catch {
                        throw RemoteConfigLoadingError.failedToSleep(error)
                    }
                    throw RemoteConfigLoadingError.deadlineExceeded
                }

                try await group.next()
                group.cancelAll()
            }
        } catch let error as RemoteConfigLoadingError {
            let extraInfo: (Error?) -> [String: String] = { error in
                if let error {
                    ["failureReason": "\(error)"]
                } else {
                    [:]
                }
            }
            switch error {
            case let .failedToFetch(error):
                Log.w("failed to fetch remote config", extraInfo: extraInfo(error))
            case let .failedToActivate(error):
                Log.w("failed to activate remote config", extraInfo: extraInfo(error))
            case .deadlineExceeded:
                Log.w("remote config fetch deadline exceeded", extraInfo: extraInfo(error))
            case let .failedToSleep(error):
                Log.w("failed to wait for remote config fetch", extraInfo: extraInfo(error))
            }
        } catch {
            Log.w("failed to fetch remote config, unknown error", extraInfo: [
                "failureReason": "\(error)",
            ])
        }
    }

    private func activateConfig() async throws {
        try await remoteConfig.activate()
        keys = Set(remoteConfig.allKeys(from: .remote))
        Log.i("remote config activated, keys: [\(keys.joined(separator: ", "))]")
    }
}
