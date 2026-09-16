import Foundation

struct PasscodeCoding {
    var encoder: PasscodeEncoder {
        PasscodeEncoder(payloadVersion: payloadVersion)
    }

    var decoder: PasscodeDecoder {
        PasscodeDecoder(payloadVersion: payloadVersion)
    }
}

private extension PasscodeCoding {
    var payloadVersion: UInt8 {
        1
    }
}
