import XCTest
@testable import KeyboardModifier

@MainActor
final class EngineTests: XCTestCase {
    private let keyboard = KeyboardID(vendorID: 1008, productID: 12362)
    private let other = KeyboardID(vendorID: 1, productID: 2)
    private var source: FakeHIDSource!
    private var mapping: FakeMapping!
    private var store: FakeStore!
    private var launched: [Action] = []

    override func setUp() async throws {
        source = FakeHIDSource()
        mapping = FakeMapping()
        store = FakeStore()
        launched = []
    }

    private func makeEngine(keyboard: KeyboardID?, rules: [Rule] = []) -> Engine {
        Engine(config: Config(keyboard: keyboard, rules: rules), source: source, mapping: mapping,
               store: store, runAction: { [unowned self] in self.launched.append($0) })
    }

    func testDemarrageDesactiveLesTouchesEtMemoriseLEtat() throws {
        let engine = makeEngine(keyboard: keyboard)
        try engine.start()
        XCTAssertEqual(mapping.disabled, [keyboard])
        XCTAssertEqual(store.saved, keyboard)
        XCTAssertTrue(engine.isActive)
    }

    func testArretRestaureEtEffaceLEtat() throws {
        let engine = makeEngine(keyboard: keyboard)
        try engine.start()
        engine.stop()
        XCTAssertEqual(mapping.restored, [keyboard])
        XCTAssertNil(store.saved)
        XCTAssertFalse(engine.isActive)
    }

    func testArretSansDemarrageNeRestaureRien() {
        makeEngine(keyboard: keyboard).stop()
        XCTAssertTrue(mapping.restored.isEmpty)
    }

    func testSansClavierRienNEstDesactive() throws {
        try makeEngine(keyboard: nil).start()
        XCTAssertTrue(mapping.disabled.isEmpty)
        XCTAssertEqual(source.startCount, 0)
    }

    func testDemarrerDeuxFoisRepartProprement() throws {
        let engine = makeEngine(keyboard: keyboard)
        try engine.start()
        try engine.start()
        XCTAssertEqual(mapping.restored, [keyboard]) // le premier start a été défait avant le second
        XCTAssertEqual(mapping.disabled, [keyboard, keyboard])
    }

    func testEchecDOuvertureNeDesactiveRien() {
        source.startError = EngineError.permissionDenied
        let engine = makeEngine(keyboard: keyboard)
        XCTAssertThrowsError(try engine.start()) { XCTAssertEqual($0 as? EngineError, .permissionDenied) }
        XCTAssertTrue(mapping.disabled.isEmpty)
        XCTAssertNil(store.saved)
    }

    func testEchecDuMappingRestaureEtLeveLErreur() {
        mapping.disableError = EngineError.mappingFailed("boom")
        let engine = makeEngine(keyboard: keyboard)
        XCTAssertThrowsError(try engine.start())
        XCTAssertNil(store.saved)
        XCTAssertFalse(engine.isActive)
    }

    func testSeulClavierRefuse() {
        source.otherKeyboards = false
        let engine = makeEngine(keyboard: keyboard)
        XCTAssertThrowsError(try engine.start()) { XCTAssertEqual($0 as? EngineError, .onlyKeyboard) }
        XCTAssertTrue(mapping.disabled.isEmpty)
    }

    func testChangementDeClavierEchoueGardeLAncien() throws {
        let engine = makeEngine(keyboard: keyboard)
        try engine.start()
        source.startError = EngineError.openFailed(code: 1)
        // le nouveau clavier ne s'ouvre pas : la config doit garder l'ancien
        XCTAssertThrowsError(try engine.setKeyboard(other))
        XCTAssertEqual(engine.keyboard, keyboard)
    }

    func testRestaurationApresArretBrutal() {
        store.saved = keyboard // l'appli précédente a été tuée sans restaurer
        makeEngine(keyboard: nil).restoreLeftoverMapping()
        XCTAssertEqual(mapping.restored, [keyboard])
        XCTAssertNil(store.saved)
    }

    func testEchecDeRestaurationGardeLEtatPourLeProchainLancement() throws {
        let engine = makeEngine(keyboard: keyboard)
        try engine.start()
        mapping.restoreError = EngineError.mappingFailed("boom")
        engine.stop()
        XCTAssertEqual(store.saved, keyboard)
    }

    func testToucheConfigureeLanceLAction() throws {
        let action = Action(type: "app", value: "Safari")
        let engine = makeEngine(keyboard: keyboard, rules: [Rule(key: 22, action: action)])
        try engine.start()
        source.send(usage: 22)
        XCTAssertEqual(launched, [action])
    }

    func testToucheNonConfigureeEtRelachementIgnores() throws {
        let engine = makeEngine(keyboard: keyboard,
                                rules: [Rule(key: 22, action: Action(type: "app", value: "Safari"))])
        try engine.start()
        source.send(usage: 5)             // pas de règle
        source.send(usage: 22, value: 0)  // relâchement
        XCTAssertTrue(launched.isEmpty)
    }

    func testCaptureRecupereLaProchaineToucheSansLancerLAction() throws {
        let engine = makeEngine(keyboard: keyboard,
                                rules: [Rule(key: 22, action: Action(type: "app", value: "Safari"))])
        try engine.start()
        var captured: Int?
        engine.captureNextKey { captured = $0 }
        source.send(usage: 22)
        XCTAssertEqual(captured, 22)
        XCTAssertTrue(launched.isEmpty)
        source.send(usage: 22) // la capture est terminée : l'action repart
        XCTAssertEqual(launched.count, 1)
    }

    func testDoublonsSignales() {
        let rules = [Rule(key: 5, action: Action(type: "app", value: "A")),
                     Rule(key: 5, action: Action(type: "app", value: "B"))]
        XCTAssertEqual(makeEngine(keyboard: keyboard, rules: rules).duplicateKeys, [5])
    }
}
