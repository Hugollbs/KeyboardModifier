import XCTest
@testable import KeyboardModifier

final class KeyFilterTests: XCTestCase {
    func testAppuiSurUneTouche() {
        XCTAssertEqual(pressedKey(page: HID.keyboardPage, usage: 22, value: 1), 22)
    }

    func testRelachementIgnore() {
        XCTAssertNil(pressedKey(page: HID.keyboardPage, usage: 22, value: 0))
    }

    func testAutrePageIgnoree() {
        XCTAssertNil(pressedKey(page: 0x0C, usage: 22, value: 1)) // page « consommateur » (touches média)
    }

    func testBornesDeLaPlage() {
        XCTAssertNil(pressedKey(page: HID.keyboardPage, usage: 3, value: 1))   // code d'erreur
        XCTAssertEqual(pressedKey(page: HID.keyboardPage, usage: 4, value: 1), 4)
        XCTAssertEqual(pressedKey(page: HID.keyboardPage, usage: 231, value: 1), 231)
        XCTAssertNil(pressedKey(page: HID.keyboardPage, usage: 232, value: 1))
    }
}
