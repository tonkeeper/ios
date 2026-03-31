import Foundation
import Testing
@testable import TKCryptoKit

@Suite
struct Base58Tests {
    @Test
    func encoding() {
        let string1 = "grisha".data(using: .utf8)!
        let string1Base58 = "tWnZukZN"
        #expect(string1Base58 == Base58.encode(string1))

        let string2 = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
            .data(using: .utf8)!
        let string2Base58 = """
        6WWAVR6RaTut2Av6UM6awEwUE5NwgCpoRmC9WQmcjKLWSwQVE6rcRW23MBinCQ1xxPcFgZB9z2jp1igKVp1f6sdJxmf1c9GpMFxi4e1fp7zEJgJrFYD6yrVxqo2kfLAEV8xYYBJPGJTzkKMq7kfZXuTxnoNdPCjqsYDaCvsLsbwdNWgyHW6Ub9K1f5FXZTVobWAsRBNwaXmDRi78ZWz5h5fnUVRnPiq3HHvSu8DBqdxPngorx8rRkswtDsz1KbFyzDTE7W5eFYoAYbszBmkfR2CTHfoT4yZXYkU4YSLPnLGPZeEaMQonDjr3vN35aCcgeHiJq34kVbENgqet8n8cdh2phNEWyRS8ok6A62Ynb5qFnCVzuDqXYHKJCAyrqudpWS2zbRHEivNAe7B6WBuyPUg86mXZEgyGwsEiv517fWQL6hZcj4NfaqNpGsGJMgvUhu6MGgLruphbqQYEpZeLUk3zcfWqGHoVLW3iwi6i9ULDefXvVEU2SdtfkBQi7xGnZurxPxgShbofmx3QxVTLWntL7gB2LGQ2NWtEyUuxrE2h1UKeEDvPjC6dZpNdemDL8FiMQ15nSSnsEj6GEYaPScox6mjCvouw
        """
        #expect(string2Base58 == Base58.encode(string2))
    }

    @Test
    func dcoding() {
        let string2 = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
            .data(using: .utf8)
        let string2Base58 = "6WWAVR6RaTut2Av6UM6awEwUE5NwgCpoRmC9WQmcjKLWSwQVE6rcRW23MBinCQ1xxPcFgZB9z2jp1igKVp1f6sdJxmf1c9GpMFxi4e1fp7zEJgJrFYD6yrVxqo2kfLAEV8xYYBJPGJTzkKMq7kfZXuTxnoNdPCjqsYDaCvsLsbwdNWgyHW6Ub9K1f5FXZTVobWAsRBNwaXmDRi78ZWz5h5fnUVRnPiq3HHvSu8DBqdxPngorx8rRkswtDsz1KbFyzDTE7W5eFYoAYbszBmkfR2CTHfoT4yZXYkU4YSLPnLGPZeEaMQonDjr3vN35aCcgeHiJq34kVbENgqet8n8cdh2phNEWyRS8ok6A62Ynb5qFnCVzuDqXYHKJCAyrqudpWS2zbRHEivNAe7B6WBuyPUg86mXZEgyGwsEiv517fWQL6hZcj4NfaqNpGsGJMgvUhu6MGgLruphbqQYEpZeLUk3zcfWqGHoVLW3iwi6i9ULDefXvVEU2SdtfkBQi7xGnZurxPxgShbofmx3QxVTLWntL7gB2LGQ2NWtEyUuxrE2h1UKeEDvPjC6dZpNdemDL8FiMQ15nSSnsEj6GEYaPScox6mjCvouw"
        #expect(string2 == Base58.decode(string2Base58))
    }
}
