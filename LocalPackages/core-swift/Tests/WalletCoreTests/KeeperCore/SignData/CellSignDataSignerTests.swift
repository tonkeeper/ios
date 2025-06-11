import Testing
@testable import KeeperCore

@Suite("CellSignDataSignerTests")
struct CellSignDataSignerDomainEncodingTests {
  
  struct TestParameters {
    let domain: String
    let expected: String
    let expectedLength: Int?
    init(domain: String,
         expected: String,
         expectedLength: Int? = nil) {
      self.domain = domain
      self.expected = expected
      self.expectedLength = expectedLength
    }
  }
  
  @Test("Valid domain",
        arguments: [
          TestParameters(
            domain: "tonkeeper.com",
            expected: "com\0tonkeeper\0",
            expectedLength: 14
          ),
          TestParameters(
            domain: "ton-connect.github.io",
            expected: "io\0github\0ton-connect\0",
            expectedLength: 22
          ),
          TestParameters(
            domain: "tONkEEpEr.CoM",
            expected: "com\0tonkeeper\0"
          ),
          TestParameters(
            domain: "tonkeeper.com.",
            expected: "com\0tonkeeper\0"
          ),
          TestParameters(
            domain: "tonkeeper",
            expected: "tonkeeper\0",
            expectedLength: 10
          ),
          TestParameters(
            domain: "tonkeeper.",
            expected: "tonkeeper\0"
          ),
          TestParameters(
            domain: ".",
            expected: "\0",
            expectedLength: 1
          )])
  func testValidDomainEncoding(parameters: TestParameters) throws {
    let encoded = try CellSignDataSigner.encodeDomain(domain: parameters.domain)
    #expect(encoded == parameters.expected)
    if let expectedLength = parameters.expectedLength {
      #expect(encoded.count == expectedLength)
    }
  }
  
  @Test("Internationalized domain names",
        arguments: [
          TestParameters(
            domain: "пример.com",
            expected: "com\0xn--e1afmkfd\0"
          ),
          TestParameters(
            domain: "example.中国",
            expected: "xn--fiqs8s\0example\0"
          ),
          TestParameters(
            domain: "اختبار",
            expected: "xn--mgbachtv\0"
          )])
  func testInternationalizedDomainNames(parameters: TestParameters) throws {
    let encoded = try CellSignDataSigner.encodeDomain(domain: parameters.domain)
    #expect(encoded == parameters.expected)
  }
  
  @Test
  func testBoundaryConditions63Bytes() throws {
    let domain = "\(String(repeating: "a", count: 63)).com"
    let encoded = try CellSignDataSigner.encodeDomain(domain: domain)
    #expect(encoded == "com\0\(String(repeating: "a", count: 63))\0")
    #expect(encoded.count == 68)
  }
  
  @Test
  func testBoundaryConditions64Bytes() {
    let domain = "\(String(repeating: "a", count: 64)).com"
    
    #expect(throws: CellSignDataSigner.DomainEncodeError.invalidLabel) {
      _ = try CellSignDataSigner.encodeDomain(domain: domain)
    }
  }
  
  @Test
  func testBoundaryConditions126Bytes() throws {
    let domain = "\(String(repeating: "a", count: 63)).\(String(repeating: "b", count: 57)).com"
    let encoded = try CellSignDataSigner.encodeDomain(domain: domain)
    #expect(encoded == "com\0\(String(repeating: "b", count: 57))\0\(String(repeating: "a", count: 63))\0")
    #expect(encoded.count == 126)
  }
  
  @Test
  func testBoundaryConditions127Bytes() {
    let domain = "\(String(repeating: "a", count: 63)).\(String(repeating: "b", count: 58)).com"
    #expect(throws: CellSignDataSigner.DomainEncodeError.encodedIsTooLong) {
      _ = try CellSignDataSigner.encodeDomain(domain: domain)
    }
  }
  
  @Test
  func testEmptyDomainInput() throws {
    #expect(throws: CellSignDataSigner.DomainEncodeError.emptyDomain) {
      _ = try CellSignDataSigner.encodeDomain(domain: "")
    }
  }
  
  @Test
  func testDomainWithEmptyLabelInput() throws {
    #expect(throws: CellSignDataSigner.DomainEncodeError.emptyLabel) {
      _ = try CellSignDataSigner.encodeDomain(domain: "bad..com")
    }
  }
  
  @Test
  func testDomainWithSpaceInput() throws {
    #expect(throws: CellSignDataSigner.DomainEncodeError.invalidLabel) {
      _ = try CellSignDataSigner.encodeDomain(domain: "bad domain.com")
    }
  }
  
  @Test
  func testDomainWithLabelContainingControlCharacter() throws {
    #expect(throws: CellSignDataSigner.DomainEncodeError.invalidLabel) {
      _ = try CellSignDataSigner.encodeDomain(domain: "bad\u{0007}bell.com")
    }
  }
  
  @Test
  func testDomainStartingWithDot() throws {
    #expect(throws: CellSignDataSigner.DomainEncodeError.emptyLabel) {
      _ = try CellSignDataSigner.encodeDomain(domain: ".com")
    }
  }
  
  @Test
  func testDomainWithLeadingAndTrailingSpaces() throws {
    #expect(throws: CellSignDataSigner.DomainEncodeError.invalidLabel) {
      _ = try CellSignDataSigner.encodeDomain(domain: "  example.com  ")
    }
  }
}
