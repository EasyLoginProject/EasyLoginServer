import XCTest
@testable import ExtensionsTests
@testable import ApplicationTests
@testable import DataProviderTests

XCTMain([
    testCase(PBKDF2Tests.allTests),
    testCase(EasyLoginAuthenticatorTests.allTests),
    testCase(DiffArrayTests.allTests),
])
