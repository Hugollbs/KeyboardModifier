import XCTest
@testable import KeyboardModifier

final class LaunchAtLoginTests: XCTestCase {
    func testSeulUnPaquetAppEstAccepte() {
        XCTAssertTrue(isAppBundle(URL(fileURLWithPath: "/Applications/KeyboardModifier.app")))
        XCTAssertFalse(isAppBundle(URL(fileURLWithPath: "/Users/x/projet/.build/out/Products/Debug")))
    }

    func testLitLExecutableDuLaunchAgent() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("agent-\(UUID()).plist")
        defer { try? FileManager.default.removeItem(at: url) }
        let plist: [String: Any] = ["Label": "test", "ProgramArguments": ["/chemin/KeyboardModifier"]]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: url)
        XCTAssertEqual(launchAgentExecutable(at: url), "/chemin/KeyboardModifier")
    }

    func testLaunchAgentAbsentDonneNil() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("absent-\(UUID()).plist")
        XCTAssertNil(launchAgentExecutable(at: url))
    }
}
