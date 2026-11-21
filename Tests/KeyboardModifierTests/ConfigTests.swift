import XCTest
@testable import KeyboardModifier

final class ConfigTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private let sample = Config(
        keyboard: KeyboardID(vendorID: 1008, productID: 12362),
        rules: [Rule(key: 22, action: Action(type: "app", value: "Safari")),
                Rule(key: 5, action: Action(type: "shell", value: "say bonjour"))])

    func testEncodageDecodage() throws {
        let data = try JSONEncoder().encode(sample)
        XCTAssertEqual(try JSONDecoder().decode(Config.self, from: data), sample)
    }

    func testConfigSansClavier() throws {
        let json = #"{"rules": []}"#.data(using: .utf8)!
        let config = try JSONDecoder().decode(Config.self, from: json)
        XCTAssertNil(config.keyboard)
    }

    func testFichierAbsentDonneUneConfigVide() throws {
        let config = try loadConfig(at: directory.appendingPathComponent("absent.json"))
        XCTAssertEqual(config, Config(keyboard: nil, rules: []))
    }

    func testFichierIllisibleLeveUneErreur() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("config.json")
        try "pas du json".write(to: url, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try loadConfig(at: url))
    }

    func testSauvegardeEtRelecture() throws {
        let url = directory.appendingPathComponent("config.json")
        saveConfig(sample, to: url)
        XCTAssertEqual(try loadConfig(at: url), sample)
    }

    func testFichierEnPermissions600() throws {
        let url = directory.appendingPathComponent("config.json")
        saveConfig(sample, to: url)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        XCTAssertEqual(attributes[.posixPermissions] as? Int, 0o600)
    }

    func testDoublonsDetectes() {
        let rules = [Rule(key: 5, action: Action(type: "app", value: "A")),
                     Rule(key: 6, action: Action(type: "app", value: "B")),
                     Rule(key: 5, action: Action(type: "app", value: "C")),
                     Rule(key: 5, action: Action(type: "app", value: "D"))]
        XCTAssertEqual(findDuplicateKeys(in: rules), [5]) // signalé une seule fois
        XCTAssertEqual(findDuplicateKeys(in: Array(rules.prefix(2))), [])
    }

    func testIdentifiantsDeClavier() {
        XCTAssertTrue(KeyboardID(vendorID: 1008, productID: 12362).isValid)
        XCTAssertFalse(KeyboardID(vendorID: -1, productID: 1).isValid)
        XCTAssertFalse(KeyboardID(vendorID: 1, productID: 0x1_0000).isValid)
    }

    func testEtatPersisteEtEfface() {
        let store = FileDisabledKeyboardStore(url: directory.appendingPathComponent("state.json"))
        let keyboard = KeyboardID(vendorID: 1008, productID: 12362)
        XCTAssertNil(store.load())
        store.save(keyboard)
        XCTAssertEqual(store.load(), keyboard)
        store.save(nil)
        XCTAssertNil(store.load())
    }
}
