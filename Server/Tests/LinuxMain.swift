import XCTest
@testable import ExtensionsTests
@testable import ApplicationTests

XCTMain([
    testCase(PBKDF2Tests.allTests),
    testCase(EasyLoginAuthenticatorTests.allTests),
])
