import Foundation
import KeeperCoreSensitive
import TKCore
import TKLogging
import TonSwift

private extension String {
    static var didRunArgon2DeriveTimeMeasurementKey: String {
        "v1_did_run_argon2_derive_time_measurement"
    }
}

typealias Argon2DeriveTimeMeasurementScheduledOperation = @Sendable () async -> Void

struct Argon2DeriveTimeMeasurementControllerDependencies {
    var logEvent: (_ event: Encodable) -> Void
    var makePassword: () -> String
    var makeMnemonic: () -> CoreMnemonic
    var measureEncryptDecrypt: (
        _ mnemonic: CoreMnemonic,
        _ password: String,
        _ now: () -> TimeInterval
    ) -> Argon2DeriveTimeMeasurementController.MeasurementResult
    var now: () -> TimeInterval
    var userDefaults: UserDefaults
    var schedule: (_ operation: @escaping Argon2DeriveTimeMeasurementScheduledOperation) async -> Void
    var processMetadata: () -> [String: Any]
}

actor Argon2DeriveTimeMeasurementController {
    private let dependencies: Argon2DeriveTimeMeasurementControllerDependencies
    private var didScheduleMeasurement = false

    init(dependencies: Argon2DeriveTimeMeasurementControllerDependencies) {
        self.dependencies = dependencies
    }

    init(
        analyticsProvider: AnalyticsProvider,
        appInfoProvider: AppInfoProvider
    ) {
        let deviceModel = appInfoProvider.deviceModel
        self.init(
            dependencies: Argon2DeriveTimeMeasurementControllerDependencies(
                logEvent: {
                    analyticsProvider.log($0)
                },
                makePassword: {
                    let number = Int.random(in: 0 ... 9999)
                    return String(format: "%04d", number)
                },
                makeMnemonic: {
                    CoreMnemonic(
                        mnemonicWords: TonSwift.Mnemonic.mnemonicNew(),
                        type: .ton
                    )
                },
                measureEncryptDecrypt: Self.measureEncryptDecrypt,
                now: {
                    ProcessInfo.processInfo.systemUptime
                },
                userDefaults: .standard,
                schedule: { operation in
                    Task.detached(priority: .medium) {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        await operation()
                    }
                },
                processMetadata: {
                    [
                        "device_model": deviceModel,
                        "low_power_mode_enabled": ProcessInfo.processInfo.isLowPowerModeEnabled,
                        "thermal_state": ProcessInfo.processInfo.thermalState.analyticsValue,
                    ]
                }
            )
        )
    }
}

extension Argon2DeriveTimeMeasurementController {
    var needsMeasurement: Bool {
        !dependencies.userDefaults.bool(
            forKey: .didRunArgon2DeriveTimeMeasurementKey
        )
    }

    func runInBackgroundIfNeeded() async {
        guard needsMeasurement, !didScheduleMeasurement else { return }
        didScheduleMeasurement = true

        await dependencies.schedule { [weak self] in
            await self?.measureAndSend()
        }
    }
}

extension Argon2DeriveTimeMeasurementController {
    enum MeasurementStep: String {
        case encrypt
        case decrypt
        case verify
    }

    enum MeasurementError: Error {
        case decryptedMnemonicMismatch
    }

    struct MeasurementResult {
        var encryptDuration: TimeInterval?
        var decryptDuration: TimeInterval?
        var failureStep: MeasurementStep?
        var error: Error?

        var isSuccess: Bool {
            failureStep == nil
        }

        static func success(
            encryptDuration: TimeInterval,
            decryptDuration: TimeInterval
        ) -> MeasurementResult {
            MeasurementResult(
                encryptDuration: encryptDuration,
                decryptDuration: decryptDuration,
                failureStep: nil,
                error: nil
            )
        }

        static func failure(
            step: MeasurementStep,
            encryptDuration: TimeInterval? = nil,
            decryptDuration: TimeInterval? = nil,
            error: Error
        ) -> MeasurementResult {
            MeasurementResult(
                encryptDuration: encryptDuration,
                decryptDuration: decryptDuration,
                failureStep: step,
                error: error
            )
        }
    }
}

private extension Argon2DeriveTimeMeasurementController {
    func measureAndSend() {
        guard reserveMeasurement() else {
            return
        }

        let password = dependencies.makePassword()
        let mnemonic = dependencies.makeMnemonic()
        let totalStartedAt = dependencies.now()
        let measurement = dependencies.measureEncryptDecrypt(
            mnemonic,
            password,
            dependencies.now
        )
        let totalDuration = dependencies.now() - totalStartedAt

        send(
            measurement: measurement,
            totalDuration: totalDuration
        )
    }

    func reserveMeasurement() -> Bool {
        guard needsMeasurement else {
            return false
        }
        dependencies.userDefaults.set(
            true,
            forKey: .didRunArgon2DeriveTimeMeasurementKey
        )
        return true
    }

    func send(
        measurement: MeasurementResult,
        totalDuration: TimeInterval
    ) {
        var metadata: [String: Any] = [
            "status": measurement.isSuccess ? "success" : "failure",
            "total_duration_ms": milliseconds(totalDuration),
        ]
        if let encryptDuration = measurement.encryptDuration {
            metadata["encrypt_duration_ms"] = milliseconds(encryptDuration)
        }
        if let decryptDuration = measurement.decryptDuration {
            metadata["decrypt_duration_ms"] = milliseconds(decryptDuration)
        }
        if let failureStep = measurement.failureStep {
            metadata["failure_step"] = failureStep.rawValue
        }
        if let error = measurement.error {
            metadata["error_type"] = String(describing: type(of: error))
        }
        metadata.merge(dependencies.processMetadata()) { current, _ in
            current
        }

        let otherMetadataString: String?
        do {
            otherMetadataString = try String(
                data: JSONSerialization.data(
                    withJSONObject: metadata,
                    options: [.sortedKeys]
                ),
                encoding: .utf8
            )
        } catch {
            Log.w("failed to serialize argon2 analytics metadata payload due to error: \(error)")
            otherMetadataString = nil
        }

        dependencies.logEvent(
            CustomError(
                severity: .warning,
                errorMessage: "argon2_derive_time_measurement",
                otherMetadata: otherMetadataString
            )
        )
    }

    func milliseconds(_ duration: TimeInterval) -> Int {
        Int((duration * 1000).rounded())
    }

    static func measureEncryptDecrypt(
        mnemonic: CoreMnemonic,
        password: String,
        now: () -> TimeInterval
    ) -> MeasurementResult {
        let encryptStartedAt = now()
        let rawData: RawMnemonicsData
        let cipher: MnemonicsRepositoryV2Crypto.Cipher
        do {
            let salt = try MnemonicsRepositoryV2Crypto.makeSalt()
            cipher = try MnemonicsRepositoryV2Crypto.unlock(
                passcode: password,
                salt: salt
            )
            rawData = try cipher.encrypt(mnemonic)
        } catch {
            return .failure(
                step: .encrypt,
                encryptDuration: now() - encryptStartedAt,
                error: error
            )
        }
        let encryptDuration = now() - encryptStartedAt

        let decryptStartedAt = now()
        let decryptedMnemonic: CoreMnemonic
        do {
            decryptedMnemonic = try cipher.decrypt(rawData)
        } catch {
            return .failure(
                step: .decrypt,
                encryptDuration: encryptDuration,
                decryptDuration: now() - decryptStartedAt,
                error: error
            )
        }
        let decryptDuration = now() - decryptStartedAt

        guard decryptedMnemonic == mnemonic else {
            return .failure(
                step: .verify,
                encryptDuration: encryptDuration,
                decryptDuration: decryptDuration,
                error: MeasurementError.decryptedMnemonicMismatch
            )
        }

        return .success(
            encryptDuration: encryptDuration,
            decryptDuration: decryptDuration
        )
    }
}

private extension ProcessInfo.ThermalState {
    var analyticsValue: String {
        switch self {
        case .nominal:
            "nominal"
        case .fair:
            "fair"
        case .serious:
            "serious"
        case .critical:
            "critical"
        @unknown default:
            "unknown"
        }
    }
}
