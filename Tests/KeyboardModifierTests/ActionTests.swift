import XCTest
@testable import KeyboardModifier

final class ActionTests: XCTestCase {
    func testRetireLesVariablesDeVSCode() {
        let env = ["ELECTRON_RUN_AS_NODE": "1", "VSCODE_PID": "42", "HOME": "/Users/x"]
        XCTAssertEqual(cleanedEnvironment(env), ["HOME": "/Users/x"])
    }

    func testEnvironnementVide() {
        XCTAssertEqual(cleanedEnvironment([:]), [:])
    }
}
