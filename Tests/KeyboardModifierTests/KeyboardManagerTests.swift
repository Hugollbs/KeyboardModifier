import XCTest
@testable import KeyboardModifier

@MainActor
final class KeyboardManagerTests: XCTestCase {
    private let a = KeyboardID(vendorID: 1, productID: 1)
    private let b = KeyboardID(vendorID: 2, productID: 2)
    private var mapping: FakeMapping!
    private var store: FakeStore!
    private var sources: [KeyboardID: FakeHIDSource] = [:]
    private var launched: [Action] = []
    private var persisted: [Config] = []

    override func setUp() async throws {
        mapping = FakeMapping()
        store = FakeStore()
        sources = [:]
        launched = []
        persisted = []
    }

    private func makeManager(_ keyboards: [KeyboardConfig]) -> KeyboardManager {
        KeyboardManager(config: Config(keyboards: keyboards), mapping: mapping, store: store,
                        makeEngine: { [unowned self] keyboard in
                            let source = FakeHIDSource()
                            self.sources[keyboard.id] = source
                            return Engine(keyboard: keyboard.id, rules: keyboard.rules, source: source,
                                          mapping: self.mapping, store: self.store,
                                          runAction: { self.launched.append($0) })
                        },
                        persist: { [unowned self] in self.persisted.append($0) })
    }

    private func keyboard(_ id: KeyboardID, enabled: Bool, rules: [Rule] = []) -> KeyboardConfig {
        KeyboardConfig(id: id, name: "K\(id.vendorID)", enabled: enabled, rules: rules)
    }

    func testSeulsLesClaviersActivesDemarrent() throws {
        let manager = makeManager([keyboard(a, enabled: true), keyboard(b, enabled: false)])
        try manager.start()
        XCTAssertTrue(manager.isRunning(a))
        XCTAssertFalse(manager.isRunning(b))
        XCTAssertEqual(mapping.disabled, [a])
    }

    func testChaqueClavierALesPropresRaccourcis() throws {
        let safari = Action(type: "app", value: "Safari")
        let notes = Action(type: "app", value: "Notes")
        let manager = makeManager([keyboard(a, enabled: true, rules: [Rule(key: 5, action: safari)]),
                                   keyboard(b, enabled: true, rules: [Rule(key: 5, action: notes)])])
        try manager.start()
        sources[a]?.send(usage: 5)
        sources[b]?.send(usage: 5)
        XCTAssertEqual(launched, [safari, notes])
    }

    func testActiverPuisDesactiverUnClavier() throws {
        let manager = makeManager([keyboard(a, enabled: false)])
        try manager.setEnabled(a, true)
        XCTAssertTrue(manager.isRunning(a))
        XCTAssertEqual(persisted.last?.keyboards.first?.enabled, true)
        try manager.setEnabled(a, false)
        XCTAssertFalse(manager.isRunning(a))
        XCTAssertEqual(mapping.restored, [a])
        XCTAssertEqual(persisted.last?.keyboards.first?.enabled, false)
    }

    func testEchecDActivationNeChangePasLaConfig() {
        mapping.disableError = EngineError.mappingFailed("boom")
        let manager = makeManager([keyboard(a, enabled: false)])
        XCTAssertThrowsError(try manager.setEnabled(a, true))
        XCTAssertFalse(manager.keyboards[0].enabled)
        XCTAssertTrue(persisted.isEmpty)
    }

    func testUnEchecNEmpechePasLesAutresClaviers() {
        let manager = makeManager([keyboard(a, enabled: true), keyboard(b, enabled: true)])
        sources[a]?.startError = EngineError.permissionDenied
        XCTAssertThrowsError(try manager.start()) { XCTAssertEqual($0 as? EngineError, .permissionDenied) }
        XCTAssertFalse(manager.isRunning(a))
        XCTAssertTrue(manager.isRunning(b))
    }

    func testStopRendTousLesClaviersMaisGardeLaConfig() throws {
        let manager = makeManager([keyboard(a, enabled: true), keyboard(b, enabled: true)])
        try manager.start()
        manager.stop()
        XCTAssertFalse(manager.isActive)
        XCTAssertEqual(Set(mapping.restored), [a, b])
        XCTAssertTrue(manager.keyboards.allSatisfy(\.enabled))
    }

    func testAjoutDUnNouveauClavierDesactive() {
        let manager = makeManager([])
        manager.add(a, name: "Nouveau")
        manager.add(a, name: "Nouveau") // sans doublon
        XCTAssertEqual(manager.keyboards, [KeyboardConfig(id: a, name: "Nouveau", enabled: false, rules: [])])
    }

    func testMiseAJourDesReglesEtSauvegarde() throws {
        let manager = makeManager([keyboard(a, enabled: true)])
        try manager.start()
        let action = Action(type: "app", value: "Safari")
        manager.update(a, name: "Renommé", rules: [Rule(key: 5, action: action)])
        sources[a]?.send(usage: 5)
        XCTAssertEqual(launched, [action])
        XCTAssertEqual(persisted.last?.keyboards.first?.name, "Renommé")
    }

    func testRestaurationDeTousLesClavierApresArretBrutal() {
        store.saved = [a, b]
        makeManager([]).restoreLeftoverMappings()
        XCTAssertEqual(mapping.restored, [a, b])
        XCTAssertEqual(store.saved, [])
    }

    func testCaptureVisantUnClavierPrecis() throws {
        let manager = makeManager([keyboard(a, enabled: true), keyboard(b, enabled: true)])
        try manager.start()
        var captured: Int?
        manager.captureNextKey(on: b) { captured = $0 }
        sources[a]?.send(usage: 9) // l'autre clavier ne déclenche pas la capture
        XCTAssertNil(captured)
        sources[b]?.send(usage: 7)
        XCTAssertEqual(captured, 7)
    }

    func testRedemarrageApresVeilleSeulementPourLesClavierActifs() throws {
        let manager = makeManager([keyboard(a, enabled: true), keyboard(b, enabled: false)])
        try manager.start()
        manager.reapplyRunning()
        XCTAssertEqual(mapping.disabled, [a, a]) // ré-appliqué sur a, jamais sur b
    }

    func testEchecAuReveilNeFaitPasPerdreLeClavier() throws {
        let manager = makeManager([keyboard(a, enabled: true)])
        try manager.start()
        mapping.disableError = EngineError.mappingFailed("test")
        manager.reapplyRunning()
        XCTAssertTrue(manager.isRunning(a)) // avant : start() échouait et le clavier était perdu
        XCTAssertEqual(sources[a]?.stopCount, 1) // l'écoute n'a pas été coupée
    }
}
