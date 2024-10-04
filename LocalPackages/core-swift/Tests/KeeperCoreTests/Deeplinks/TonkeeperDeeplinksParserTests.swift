import XCTest
import TonSwift
import BigInt
@testable import KeeperCore

final class TonkeeperDeeplinksParserTests: XCTestCase {
  let parser = TonkeeperDeeplinkParser()
  
  func testTransferParsing() {
    let address = "EQD2NmD_lH5f5u1Kj3KfGyTvhZSX0Eg6qp2a5IQUKXxOG21n"
    let text = "just comment"
    let amount = "10000"
    
    let string = "transfer/\(address)?text=\(text)&amount=\(amount)"
    let transferData = Deeplink.TransferData(
      recipient: try! Address.parse(address),
      amount: BigUInt(amount),
      comment: text,
      jettonAddress: nil
    )
    let result = Deeplink.transfer(transferData)
    
    let parsedDeeplink = try! parser.parse(string: string)
    
    XCTAssertEqual(parsedDeeplink, result)
  }
  
  func testStakingParsing() {
    let string = "staking"
    let result = Deeplink.staking
    
    let parsedDeeplink = try! parser.parse(string: string)
    
    XCTAssertEqual(parsedDeeplink, result)
  }
  
  func testBuyTonParsing() {
    let string = "buy-ton"
    let result = Deeplink.buyTon
    
    let parsedDeeplink = try! parser.parse(string: string)
    
    XCTAssertEqual(parsedDeeplink, result)
  }
  
  func testExchangeParsing() {
    let provider = "neocrypto"
    let string = "exchange/neocrypto"
    let result = Deeplink.exchange(provider: provider)
    
    let parsedDeeplink = try! parser.parse(string: string)
    
    XCTAssertEqual(parsedDeeplink, result)
  }
  
  func testSwapParsing() {
    let string = "swap?ft=TON&tt=FNZ"
    let swapData = Deeplink.SwapData(
      fromToken: "TON",
      toToken: "FNZ"
    )
    let result = Deeplink.swap(swapData)
    
    let parsedDeeplink = try! parser.parse(string: string)
    
    XCTAssertEqual(parsedDeeplink, result)
  }
  
  func testActionParsing() {
    let string = "action/f0389f350dd7b6bba35ce0dd12d4e2cf557c2613bca2426d2e0c3055ac105994"
    let result = Deeplink.action(eventId: "f0389f350dd7b6bba35ce0dd12d4e2cf557c2613bca2426d2e0c3055ac105994")
    
    let parsedDeeplink = try! parser.parse(string: string)
    
    XCTAssertEqual(parsedDeeplink, result)
  }
  
  func testPoolParsing() {
    let string = "pool/0:a45b17f28409229b78360e3290420f13e4fe20f90d7e2bf8c4ac6703259e22fa"
    let result = Deeplink.pool(try! Address.parse("0:a45b17f28409229b78360e3290420f13e4fe20f90d7e2bf8c4ac6703259e22fa"))
    
    let parsedDeeplink = try! parser.parse(string: string)
    
    XCTAssertEqual(parsedDeeplink, result)
  }
  
  func testPublishParsing() {
    let string = "publish?sign=9dfab96f693363f48a641c628ae74168d37f7da1745bfd3cbf1b6013cce1477c03ae59e87c8ebe0146c1d755b797020ac29ff6a1797e7ae7d4b61df89c34540f"
    let data: Data = Data(hex: "9dfab96f693363f48a641c628ae74168d37f7da1745bfd3cbf1b6013cce1477c03ae59e87c8ebe0146c1d755b797020ac29ff6a1797e7ae7d4b61df89c34540f")
    let result = Deeplink.publish(sign: data)
    
    let parsedDeeplink = try! parser.parse(string: string)
    
    XCTAssertEqual(parsedDeeplink, result)
  }
  
  func testSignerLinkParsing() {
    let pk = "db642e022c80911fe61f19eb4f22d7fb95c1ea0b589c0f74ecf0cbf6db746c13"
    let name = "MyKey"
    let publicKey = TonSwift.PublicKey(data: Data(hex: pk))
    let string = "signer/link?pk=\(pk)&name=\(name)"
    let result = Deeplink.externalSign(
      ExternalSignDeeplink.link(
        publicKey: publicKey,
        name: name
      )
    )
    
    let parsedDeeplink = try! parser.parse(string: string)
    
    XCTAssertEqual(parsedDeeplink, result)
  }
}

