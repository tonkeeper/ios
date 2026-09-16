import CoreImage
import KeeperCore
import KeeperCoreComponents
import TKLogging
import TKUIKit

struct QrCodeMatrixGeneratorImplementation {
    private let storeInCache: (_ value: CachedQrCodeMatrix, _ key: QrCodeMatrixCacheKey) -> Void
    private let getFromCache: (_ key: QrCodeMatrixCacheKey) -> QrCodeMatrix?
}

extension QrCodeMatrixGeneratorImplementation {
    static func disposable() -> Self {
        var cache = Atomic(wrappedValue: [QrCodeMatrixCacheKey: CachedQrCodeMatrix]())
        return Self { value, key in
            cache.wrappedValue[key] = value
        } getFromCache: { key in
            cache.wrappedValue[key]?.matrix
        }
    }

    typealias Vault = FileSystemVault<CachedQrCodeMatrix, QrCodeMatrixCacheKey>
    static func persistent(cache: Vault) -> Self {
        Self { value, key in
            do {
                try cache.saveItem(value, key: key)
            } catch {
                Log.w("failed to cache qr code matrix due to error: \(error)")
            }
        } getFromCache: { key in
            let cached: CachedQrCodeMatrix
            do {
                cached = try cache.loadItem(key: key)
            } catch let error as Vault.LoadError {
                switch error {
                case .noItem:
                    break
                default:
                    Log.w("failed to read qr data from cache due to error: \(error)")
                }
                return nil
            } catch {
                Log.w("failed to read qr data from cache due to error: \(error)")
                return nil
            }

            guard cached.matches(string: key.string, correctionLevel: key.correctionLevel) else {
                Log.w("qr cache entry does not match requested payload, regenerating")
                return nil
            }

            return cached.matrix
        }
    }
}

extension QrCodeMatrixGeneratorImplementation: QrCodeMatrixGenerator {
    func generateMatrix(
        string: String,
        configuration: QrCodeGeneratorConfiguration
    ) -> QrCodeMatrix? {
        let correctionLevel = configuration
            .resolvedErrorCorrectionLevel
            .ciInputValue
        let key = QrCodeMatrixCacheKey(
            string: string,
            correctionLevel: correctionLevel
        )
        if let cachedMatrix = getFromCache(key) {
            return cachedMatrix
        }
        guard let data = string.data(using: .ascii) else {
            Log.w("failed to get ascii data from string: \(string)")
            return nil
        }
        let filter = {
            let filter = CIFilter(name: "CIQRCodeGenerator")
            filter?.setValue(data, forKey: "inputMessage")
            filter?.setValue(correctionLevel, forKey: "inputCorrectionLevel")
            return filter
        }()
        guard let outputImage = filter?.outputImage else {
            Log.w("failed to generate qr code image")
            return nil
        }
        guard let matrix = QrCodeMatrix(ciImage: outputImage) else {
            Log.w("failed to create qr code matrix from ci image")
            return nil
        }
        let itemToCache = CachedQrCodeMatrix(
            string: string,
            correctionLevel: correctionLevel,
            matrix: matrix
        )
        storeInCache(itemToCache, key)
        return matrix
    }
}
