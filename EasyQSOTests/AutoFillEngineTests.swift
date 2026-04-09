import XCTest
import CoreData
@testable import EasyQSO

final class AutoFillEngineTests: XCTestCase {

    private var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        context = TestHelper.createInMemoryContext()
    }

    override func tearDown() {
        // Reset DXCC test data to avoid leaking between tests
        DXCCManager.shared.loadTestData(entities: [], prefixes: [])
        context = nil
        super.tearDown()
    }

    // MARK: - Field Source Tracking

    func testTrackFieldChange_UserEdit_PreventsAutoFill() {
        let engine = AutoFillEngine()
        engine.addRule(AutoFillRule(
            id: "test_rule",
            inputs: ["A"],
            outputs: ["B"],
            compute: { _, _ in ["B": "auto_value"] }
        ))

        // Simulate user typing a different value into B
        engine.trackFieldChange("B", newValue: "user_typed")
        XCTAssertFalse(engine.canAutoFill("B"))

        // Evaluate: B should NOT be filled
        let results = engine.evaluate(trigger: "A", currentValues: ["A": "1"], context: context)
        XCTAssertTrue(results.isEmpty, "User-edited field should not be overwritten by autofill")
    }

    func testTrackFieldChange_MatchesAutoFill_NotUserEdited() {
        let engine = AutoFillEngine()
        engine.addRule(AutoFillRule(
            id: "test_rule",
            inputs: ["A"],
            outputs: ["B"],
            compute: { _, _ in ["B": "auto_value"] }
        ))

        // Autofill sets B
        let results1 = engine.evaluate(trigger: "A", currentValues: ["A": "1"], context: context)
        XCTAssertEqual(results1["B"], "auto_value")

        // SwiftUI onChange fires with the same value autofill set → not a user edit
        engine.trackFieldChange("B", newValue: "auto_value")
        XCTAssertTrue(engine.isAutoFilled("B"), "Field should still be marked autofilled")
        XCTAssertTrue(engine.canAutoFill("B"))
    }

    func testAutoFilledField_CanBeOverwritten() {
        let engine = AutoFillEngine()
        engine.addRule(AutoFillRule(
            id: "test_rule",
            inputs: ["A"],
            outputs: ["B"],
            compute: { values, _ in
                let a = values["A"] ?? ""
                return ["B": "computed_\(a)"]
            }
        ))

        // First evaluation: B gets autofilled
        let results1 = engine.evaluate(trigger: "A", currentValues: ["A": "1"], context: context)
        XCTAssertEqual(results1["B"], "computed_1")
        XCTAssertTrue(engine.isAutoFilled("B"))

        // Second evaluation: B can be overwritten since it's autofilled, not user-edited
        let results2 = engine.evaluate(trigger: "A", currentValues: ["A": "2"], context: context)
        XCTAssertEqual(results2["B"], "computed_2")
    }

    func testTrackFieldChange_DifferentValue_MarksUserEdited() {
        let engine = AutoFillEngine()
        engine.addRule(AutoFillRule(
            id: "test_rule",
            inputs: ["A"],
            outputs: ["B"],
            compute: { _, _ in ["B": "auto_value"] }
        ))

        // Autofill sets B
        let _ = engine.evaluate(trigger: "A", currentValues: ["A": "1"], context: context)
        XCTAssertTrue(engine.isAutoFilled("B"))

        // User edits B to a different value
        engine.trackFieldChange("B", newValue: "user_changed_value")
        XCTAssertFalse(engine.isAutoFilled("B"))
        XCTAssertEqual(engine.fieldSources["B"], .userEdited)
    }

    func testResetAllSources() {
        let engine = AutoFillEngine()
        engine.trackFieldChange("A", newValue: "user_value")
        engine.recordAutoFill("B", value: "auto_value")

        engine.resetAllSources()

        XCTAssertTrue(engine.fieldSources.isEmpty)
        XCTAssertTrue(engine.canAutoFill("A"))
        XCTAssertTrue(engine.canAutoFill("B"))
    }

    // MARK: - Reentrancy Guard (Cycle Breaking)

    func testReentrancyGuard_BreaksCycles() {
        let engine = AutoFillEngine()
        var callCount = 0

        // Rule: A → B
        engine.addRule(AutoFillRule(
            id: "a_to_b",
            inputs: ["A"],
            outputs: ["B"],
            compute: { _, ctx in
                callCount += 1
                // Simulate B triggering A again (would cause infinite loop without guard)
                let _ = engine.evaluate(trigger: "A", currentValues: [:], context: ctx)
                return ["B": "value"]
            }
        ))

        let results = engine.evaluate(trigger: "A", currentValues: ["A": "1"], context: context)
        XCTAssertEqual(results["B"], "value")
        // callCount should be 1, not infinite — the re-entrant call was skipped
        XCTAssertEqual(callCount, 1)
    }

    // MARK: - Graph Analysis

    func testDetectCycles_NoCycles() {
        let engine = AutoFillEngine()
        engine.addRule(AutoFillRule(
            id: "a_to_b", inputs: ["A"], outputs: ["B"],
            compute: { _, _ in [:] }
        ))
        engine.addRule(AutoFillRule(
            id: "b_to_c", inputs: ["B"], outputs: ["C"],
            compute: { _, _ in [:] }
        ))

        let cycles = engine.detectCycles()
        XCTAssertTrue(cycles.isEmpty, "No cycles should be detected in a linear graph")
    }

    func testDetectCycles_WithCycle() {
        let engine = AutoFillEngine()
        engine.addRule(AutoFillRule(
            id: "a_to_b", inputs: ["A"], outputs: ["B"],
            compute: { _, _ in [:] }
        ))
        engine.addRule(AutoFillRule(
            id: "b_to_a", inputs: ["B"], outputs: ["A"],
            compute: { _, _ in [:] }
        ))

        let cycles = engine.detectCycles()
        XCTAssertFalse(cycles.isEmpty, "Should detect the A↔B cycle")
    }

    func testValidateAcyclicExcluding_AllowedEdges() {
        let engine = AutoFillEngine()
        // FREQ ↔ BAND (known bidirectional)
        engine.addRule(AutoFillRule(
            id: "freq_to_band", inputs: ["FREQ"], outputs: ["BAND"],
            compute: { _, _ in [:] }
        ))
        engine.addRule(AutoFillRule(
            id: "band_to_freq", inputs: ["BAND"], outputs: ["FREQ"],
            compute: { _, _ in [:] }
        ))
        // BAND → QTH (one-directional)
        engine.addRule(AutoFillRule(
            id: "band_to_qth", inputs: ["BAND"], outputs: ["MY_CITY"],
            compute: { _, _ in [:] }
        ))

        // Without excluding: has cycle
        let hasUnexpectedCycles = !engine.validateAcyclicExcluding(allowedEdges: [])
        XCTAssertTrue(hasUnexpectedCycles)

        // Excluding the known bidirectional edges: should be acyclic
        let isAcyclic = engine.validateAcyclicExcluding(allowedEdges: [
            DirectedEdge(from: "FREQ", to: "BAND"),
            DirectedEdge(from: "BAND", to: "FREQ"),
        ])
        XCTAssertTrue(isAcyclic, "Graph should be acyclic after removing known bidirectional edges")
    }

    // MARK: - Standard Engine: Structure Validation

    func testStandardEngine_NoUnexpectedCycles() {
        let engine = AutoFillEngine.standardEngine()

        // The standard engine has FREQ↔BAND as a known cycle.
        // After excluding those edges, no other cycles should exist.
        let isAcyclic = engine.validateAcyclicExcluding(
            allowedEdges: AutoFillEngine.knownBidirectionalEdges
        )
        XCTAssertTrue(isAcyclic, "Standard engine should have no unexpected cycles beyond FREQ↔BAND")
    }

    func testStandardEngine_AllOutputsAreDeclared() {
        let engine = AutoFillEngine.standardEngine()

        for rule in engine.rules {
            let results = rule.compute(["BAND": "20m", "MODE": "SSB"], context)
            for key in results.keys {
                XCTAssertTrue(
                    rule.outputs.contains(key),
                    "Rule '\(rule.id)' produced undeclared output '\(key)'. " +
                    "Declared outputs: \(rule.outputs)"
                )
            }
        }
    }

    // MARK: - Standard Engine: Own QTH Autofill

    func testStandardEngine_OwnQTH_AutoFilled() throws {
        let record = QSORecord(context: context)
        record.callsign = "BG1AAA"
        record.date = Date()
        record.band = "20m"
        record.mode = "SSB"
        record.rstSent = "59"
        record.rstReceived = "59"
        record.adifFields = ["MY_CITY": "Beijing", "MY_GRIDSQUARE": "OM89xb"]
        try context.save()

        let engine = AutoFillEngine.standardEngine()
        let results = engine.evaluate(
            trigger: "BAND",
            currentValues: ["BAND": "20m", "MODE": "SSB"],
            context: context
        )

        XCTAssertEqual(results["MY_CITY"], "Beijing")
        XCTAssertEqual(results["MY_GRIDSQUARE"], "OM89xb")
        XCTAssertTrue(engine.isAutoFilled("MY_CITY"))
        XCTAssertTrue(engine.isAutoFilled("MY_GRIDSQUARE"))
    }

    func testStandardEngine_OwnQTH_SkipsUserEdited() throws {
        let record = QSORecord(context: context)
        record.callsign = "BG1AAA"
        record.date = Date()
        record.band = "20m"
        record.mode = "SSB"
        record.rstSent = "59"
        record.rstReceived = "59"
        record.adifFields = ["MY_CITY": "Beijing", "MY_GRIDSQUARE": "OM89xb"]
        try context.save()

        let engine = AutoFillEngine.standardEngine()

        // User manually edited MY_CITY
        engine.trackFieldChange("MY_CITY", newValue: "UserTypedCity")

        let results = engine.evaluate(
            trigger: "BAND",
            currentValues: ["BAND": "20m", "MODE": "SSB"],
            context: context
        )

        // MY_CITY should NOT be in results (user-edited)
        XCTAssertNil(results["MY_CITY"], "User-edited MY_CITY should not be overwritten")
        // MY_GRIDSQUARE should still be autofilled
        XCTAssertEqual(results["MY_GRIDSQUARE"], "OM89xb")
    }

    func testStandardEngine_OwnQTH_PartialUserEdit() throws {
        let record = QSORecord(context: context)
        record.callsign = "BG1AAA"
        record.date = Date()
        record.band = "20m"
        record.mode = "SSB"
        record.rstSent = "59"
        record.rstReceived = "59"
        record.adifFields = [
            "MY_CITY": "Beijing",
            "MY_GRIDSQUARE": "OM89xb",
            "MY_CQ_ZONE": "24",
            "MY_ITU_ZONE": "44"
        ]
        try context.save()

        let engine = AutoFillEngine.standardEngine()

        // User edited only CQ zone and ITU zone
        engine.trackFieldChange("MY_CQ_ZONE", newValue: "99")
        engine.trackFieldChange("MY_ITU_ZONE", newValue: "99")

        let results = engine.evaluate(
            trigger: "MODE",
            currentValues: ["BAND": "20m", "MODE": "SSB"],
            context: context
        )

        // City and grid should be autofilled
        XCTAssertEqual(results["MY_CITY"], "Beijing")
        XCTAssertEqual(results["MY_GRIDSQUARE"], "OM89xb")
        // CQ zone and ITU zone should NOT be overwritten
        XCTAssertNil(results["MY_CQ_ZONE"])
        XCTAssertNil(results["MY_ITU_ZONE"])
    }

    // MARK: - Standard Engine: Band → Frequency

    func testStandardEngine_BandToFrequency() throws {
        let record = QSORecord(context: context)
        record.callsign = "BG1AAA"
        record.date = Date()
        record.band = "40m"
        record.mode = "CW"
        record.frequencyMHz = 7.025
        record.rstSent = "599"
        record.rstReceived = "599"
        try context.save()

        let engine = AutoFillEngine.standardEngine()
        let results = engine.evaluate(
            trigger: "BAND",
            currentValues: ["BAND": "40m", "MODE": "CW"],
            context: context
        )

        XCTAssertEqual(results["FREQ"], "7.025")
        XCTAssertTrue(engine.isAutoFilled("FREQ"))
    }

    func testStandardEngine_BandToFrequency_SkipsUserEdited() throws {
        let record = QSORecord(context: context)
        record.callsign = "BG1AAA"
        record.date = Date()
        record.band = "40m"
        record.mode = "CW"
        record.frequencyMHz = 7.025
        record.rstSent = "599"
        record.rstReceived = "599"
        try context.save()

        let engine = AutoFillEngine.standardEngine()
        engine.trackFieldChange("FREQ", newValue: "14.200")

        let results = engine.evaluate(
            trigger: "BAND",
            currentValues: ["BAND": "40m", "MODE": "CW"],
            context: context
        )

        XCTAssertNil(results["FREQ"], "User-edited frequency should not be overwritten")
    }

    // MARK: - Standard Engine: Band → Station Info

    func testStandardEngine_BandToStationInfo() throws {
        let record = QSORecord(context: context)
        record.callsign = "BG1AAA"
        record.date = Date()
        record.band = "20m"
        record.mode = "SSB"
        record.txPower = "100"
        record.rstSent = "59"
        record.rstReceived = "59"
        record.adifFields = ["STATION_CALLSIGN": "BG5XYZ", "MY_RIG": "IC-7300"]
        try context.save()

        let engine = AutoFillEngine.standardEngine()
        let results = engine.evaluate(
            trigger: "BAND",
            currentValues: ["BAND": "20m", "MODE": "SSB"],
            context: context
        )

        XCTAssertEqual(results["TX_PWR"], "100")
        XCTAssertEqual(results["STATION_CALLSIGN"], "BG5XYZ")
        XCTAssertEqual(results["MY_RIG"], "IC-7300")
    }

    func testStandardEngine_BandToStationInfo_SkipsUserEdited() throws {
        let record = QSORecord(context: context)
        record.callsign = "BG1AAA"
        record.date = Date()
        record.band = "20m"
        record.mode = "SSB"
        record.txPower = "100"
        record.rstSent = "59"
        record.rstReceived = "59"
        try context.save()

        let engine = AutoFillEngine.standardEngine()
        engine.trackFieldChange("TX_PWR", newValue: "50")

        let results = engine.evaluate(
            trigger: "BAND",
            currentValues: ["BAND": "20m", "MODE": "SSB"],
            context: context
        )

        XCTAssertNil(results["TX_PWR"], "User-edited TX_PWR should not be overwritten")
    }

    // MARK: - Edge Cases

    func testEvaluate_UnknownTrigger_ReturnsEmpty() {
        let engine = AutoFillEngine.standardEngine()
        let results = engine.evaluate(
            trigger: "UNKNOWN_FIELD",
            currentValues: [:],
            context: context
        )
        XCTAssertTrue(results.isEmpty)
    }

    func testEvaluate_EmptyBand_ReturnsEmpty() {
        let engine = AutoFillEngine.standardEngine()
        let results = engine.evaluate(
            trigger: "BAND",
            currentValues: ["BAND": ""],
            context: context
        )
        XCTAssertTrue(results.isEmpty)
    }

    func testAllOutputFields() {
        let engine = AutoFillEngine.standardEngine()
        let outputs = engine.allOutputFields

        // Should contain all expected output fields
        XCTAssertTrue(outputs.contains("FREQ"))
        XCTAssertTrue(outputs.contains("TX_PWR"))
        XCTAssertTrue(outputs.contains("MY_CITY"))
        XCTAssertTrue(outputs.contains("MY_GRIDSQUARE"))
        XCTAssertTrue(outputs.contains("MY_CQ_ZONE"))
        XCTAssertTrue(outputs.contains("MY_ITU_ZONE"))
        XCTAssertTrue(outputs.contains("STATION_CALLSIGN"))
        XCTAssertTrue(outputs.contains("CQZ"))
        XCTAssertTrue(outputs.contains("ITUZ"))
        XCTAssertTrue(outputs.contains("DXCC"))
    }

    // MARK: - Standard Engine: CALL → Contacted CQ/ITU Zone Autofill

    func testStandardEngine_CallToContactedZones() {
        loadDXCCTestData()
        let engine = AutoFillEngine.standardEngine()

        let results = engine.evaluate(
            trigger: "CALL",
            currentValues: ["CALL": "W1AW"],
            context: context
        )

        XCTAssertEqual(results["CQZ"], "5")
        XCTAssertEqual(results["ITUZ"], "8")
        XCTAssertEqual(results["DXCC"], "291")
        XCTAssertTrue(engine.isAutoFilled("CQZ"))
        XCTAssertTrue(engine.isAutoFilled("ITUZ"))
        XCTAssertTrue(engine.isAutoFilled("DXCC"))
    }

    func testStandardEngine_CallToContactedZones_WithOverride() {
        loadDXCCTestDataWithOverrides()
        let engine = AutoFillEngine.standardEngine()

        // W4 prefix has CQ zone override 4, ITU zone override 9
        let results = engine.evaluate(
            trigger: "CALL",
            currentValues: ["CALL": "W4ABC"],
            context: context
        )

        XCTAssertEqual(results["CQZ"], "4")
        XCTAssertEqual(results["ITUZ"], "9")
        XCTAssertEqual(results["DXCC"], "291")
    }

    func testStandardEngine_CallToContactedZones_ShortCallsignSkipped() {
        loadDXCCTestData()
        let engine = AutoFillEngine.standardEngine()

        // Single character callsign should not trigger lookup
        let results = engine.evaluate(
            trigger: "CALL",
            currentValues: ["CALL": "W"],
            context: context
        )

        XCTAssertTrue(results.isEmpty)
    }

    func testStandardEngine_CallToContactedZones_EmptyCallsign() {
        loadDXCCTestData()
        let engine = AutoFillEngine.standardEngine()

        let results = engine.evaluate(
            trigger: "CALL",
            currentValues: ["CALL": ""],
            context: context
        )

        XCTAssertTrue(results.isEmpty)
    }

    func testStandardEngine_CallToContactedZones_UnknownCallsign() {
        loadDXCCTestData()
        let engine = AutoFillEngine.standardEngine()

        let results = engine.evaluate(
            trigger: "CALL",
            currentValues: ["CALL": "QQ0ZZZ"],
            context: context
        )

        XCTAssertTrue(results.isEmpty)
    }

    func testStandardEngine_CallToContactedZones_SkipsUserEdited() {
        loadDXCCTestData()
        let engine = AutoFillEngine.standardEngine()

        // User manually edited CQZ
        engine.trackFieldChange("CQZ", newValue: "99")

        let results = engine.evaluate(
            trigger: "CALL",
            currentValues: ["CALL": "W1AW"],
            context: context
        )

        // CQZ should NOT be in results (user-edited)
        XCTAssertNil(results["CQZ"], "User-edited CQZ should not be overwritten")
        // ITUZ and DXCC should still be autofilled
        XCTAssertEqual(results["ITUZ"], "8")
        XCTAssertEqual(results["DXCC"], "291")
    }

    func testStandardEngine_CallToContactedZones_AutoFilledCanBeUpdated() {
        loadDXCCTestDataWithOverrides()
        let engine = AutoFillEngine.standardEngine()

        // First callsign → autofill zones
        let results1 = engine.evaluate(
            trigger: "CALL",
            currentValues: ["CALL": "W1AW"],
            context: context
        )
        XCTAssertEqual(results1["CQZ"], "5")
        XCTAssertEqual(results1["ITUZ"], "8")
        XCTAssertTrue(engine.isAutoFilled("CQZ"))

        // Change callsign → zones should update (they're autofilled, not user-edited)
        let results2 = engine.evaluate(
            trigger: "CALL",
            currentValues: ["CALL": "W4ABC"],
            context: context
        )
        XCTAssertEqual(results2["CQZ"], "4")
        XCTAssertEqual(results2["ITUZ"], "9")
    }

    func testStandardEngine_CallToContactedZones_UserEditThenAutoFillBlocked() {
        loadDXCCTestDataWithOverrides()
        let engine = AutoFillEngine.standardEngine()

        // First: autofill from W1AW
        let _ = engine.evaluate(
            trigger: "CALL",
            currentValues: ["CALL": "W1AW"],
            context: context
        )
        XCTAssertTrue(engine.isAutoFilled("CQZ"))

        // User edits CQZ to a different value
        engine.trackFieldChange("CQZ", newValue: "99")
        XCTAssertFalse(engine.isAutoFilled("CQZ"))

        // Change callsign → CQZ should NOT update (user-edited)
        let results = engine.evaluate(
            trigger: "CALL",
            currentValues: ["CALL": "W4ABC"],
            context: context
        )
        XCTAssertNil(results["CQZ"])
        // ITUZ was never user-edited, should still update
        XCTAssertEqual(results["ITUZ"], "9")
    }

    func testStandardEngine_NoUnexpectedCycles_WithCallRule() {
        let engine = AutoFillEngine.standardEngine()

        // CALL → CQZ/ITUZ/DXCC should not create any cycles
        let isAcyclic = engine.validateAcyclicExcluding(
            allowedEdges: AutoFillEngine.knownBidirectionalEdges
        )
        XCTAssertTrue(isAcyclic, "Adding CALL rule should not introduce unexpected cycles")
    }

    func testStandardEngine_CallRuleOutputsDeclared() {
        let engine = AutoFillEngine.standardEngine()
        let callRule = engine.rules.first { $0.id == "call_to_contacted_zones" }
        XCTAssertNotNil(callRule)
        XCTAssertEqual(callRule?.inputs, ["CALL"])
        XCTAssertEqual(callRule?.outputs, ["CQZ", "ITUZ", "DXCC"])
    }

    func testStandardEngine_CallToContactedZones_NoDXCCData() {
        // Don't load any DXCC data → DXCCManager.shared.isDataAvailable is false
        DXCCManager.shared.loadTestData(entities: [], prefixes: [])
        let engine = AutoFillEngine.standardEngine()

        let results = engine.evaluate(
            trigger: "CALL",
            currentValues: ["CALL": "W1AW"],
            context: context
        )

        XCTAssertTrue(results.isEmpty, "No results when DXCC data is unavailable")
    }

    // MARK: - DXCC Test Data Helpers

    private func loadDXCCTestData() {
        let entities = [
            DXCCEntity(code: 291, name: "United States", cqZone: 5, ituZone: 8, continent: "NA", latitude: 40.0, longitude: -100.0, timeOffset: 5.0, primaryPrefix: "K"),
            DXCCEntity(code: 336, name: "Israel", cqZone: 20, ituZone: 39, continent: "AS", latitude: 31.32, longitude: -34.82, timeOffset: -2.0, primaryPrefix: "4X"),
        ]
        let prefixes = [
            DXCCPrefixEntry(prefix: "K", entityCode: 291, exact: false),
            DXCCPrefixEntry(prefix: "W", entityCode: 291, exact: false),
            DXCCPrefixEntry(prefix: "N", entityCode: 291, exact: false),
            DXCCPrefixEntry(prefix: "4X", entityCode: 336, exact: false),
        ]
        DXCCManager.shared.loadTestData(entities: entities, prefixes: prefixes)
    }

    private func loadDXCCTestDataWithOverrides() {
        let entities = [
            DXCCEntity(code: 291, name: "United States", cqZone: 5, ituZone: 8, continent: "NA", latitude: 40.0, longitude: -100.0, timeOffset: 5.0, primaryPrefix: "K"),
        ]
        let prefixes = [
            DXCCPrefixEntry(prefix: "K", entityCode: 291, exact: false),
            DXCCPrefixEntry(prefix: "W", entityCode: 291, exact: false),
            DXCCPrefixEntry(prefix: "W4", entityCode: 291, exact: false, cqZoneOverride: 4, ituZoneOverride: 9),
        ]
        DXCCManager.shared.loadTestData(entities: entities, prefixes: prefixes)
    }
}
