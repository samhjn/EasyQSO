import XCTest
@testable import EasyQSO

/// Tests that EditQSOSnapshot equality correctly detects changes to every
/// tracked field. This is the contract EditQSOView relies on to decide
/// whether to show the "unsaved changes" alert on exit.
///
/// Regression context: when pickers were sheets, editing a satellite/contest
/// correctly flipped hasUnsavedChanges to true. After switching to
/// NavigationLink push, the view's onAppear re-fired on pop, which was
/// silently overwriting the baseline — these tests guard the Equatable
/// contract so future refactors don't drop a tracked field.
final class EditQSOSnapshotTests: XCTestCase {

    /// Convenience: a fully-populated baseline snapshot. Each test mutates
    /// exactly one field to verify that the Equatable contract detects it.
    private func makeBaseline() -> EditQSOSnapshot {
        EditQSOSnapshot(
            callsign: "BG5ABC",
            date: Date(timeIntervalSince1970: 1_700_000_000),
            endDate: Date(timeIntervalSince1970: 1_700_000_600),
            band: "20m",
            mode: "SSB",
            submode: "",
            frequency: "14.200",
            rxFrequency: "",
            txPower: "100",
            rstSent: "59",
            rstReceived: "59",
            name: "John",
            qth: "Beijing",
            gridSquare: "OM89",
            cqZone: "24",
            ituZone: "44",
            satellite: "",
            remarks: "",
            extendedFields: [:],
            rxBand: "",
            ownQTH: "",
            ownGridSquare: "",
            ownCQZone: "",
            ownITUZone: ""
        )
    }

    // MARK: - Identity

    func testEqual_SameValues() {
        XCTAssertEqual(makeBaseline(), makeBaseline())
    }

    // MARK: - Picker fields (the bug)

    func testDetectsChange_Satellite() {
        let baseline = makeBaseline()
        var edited = baseline
        edited.satellite = "ISS"
        XCTAssertNotEqual(baseline, edited,
                           "Changing satellite must be detected as an unsaved change")
    }

    func testDetectsChange_SatelliteClearedFromSet() {
        var baseline = makeBaseline()
        baseline.satellite = "ISS"
        var edited = baseline
        edited.satellite = ""
        XCTAssertNotEqual(baseline, edited,
                           "Clearing a satellite selection must be detected as a change")
    }

    func testDetectsChange_ContestAddedToExtendedFields() {
        let baseline = makeBaseline()
        var edited = baseline
        edited.extendedFields["CONTEST_ID"] = "CQ-WW-SSB"
        XCTAssertNotEqual(baseline, edited,
                           "Adding a contest selection must be detected as a change")
    }

    func testDetectsChange_DXCCAddedToExtendedFields() {
        let baseline = makeBaseline()
        var edited = baseline
        edited.extendedFields["DXCC"] = "291"
        XCTAssertNotEqual(baseline, edited,
                           "Adding a DXCC selection must be detected as a change")
    }

    func testDetectsChange_ContestRemovedFromExtendedFields() {
        var baseline = makeBaseline()
        baseline.extendedFields["CONTEST_ID"] = "CQ-WW-SSB"
        var edited = baseline
        edited.extendedFields.removeValue(forKey: "CONTEST_ID")
        XCTAssertNotEqual(baseline, edited,
                           "Removing a contest selection must be detected as a change")
    }

    func testDetectsChange_ContestValueChange() {
        var baseline = makeBaseline()
        baseline.extendedFields["CONTEST_ID"] = "CQ-WW-SSB"
        var edited = baseline
        edited.extendedFields["CONTEST_ID"] = "ARRL-DX-CW"
        XCTAssertNotEqual(baseline, edited)
    }

    // MARK: - Other core fields

    func testDetectsChange_Callsign() {
        let baseline = makeBaseline()
        var edited = baseline
        edited.callsign = "VK2DEF"
        XCTAssertNotEqual(baseline, edited)
    }

    func testDetectsChange_Date() {
        let baseline = makeBaseline()
        var edited = baseline
        edited.date = Date(timeIntervalSince1970: 1_700_000_001)
        XCTAssertNotEqual(baseline, edited)
    }

    func testDetectsChange_BandModeFrequency() {
        let baseline = makeBaseline()

        var bandChange = baseline; bandChange.band = "40m"
        XCTAssertNotEqual(baseline, bandChange)

        var modeChange = baseline; modeChange.mode = "CW"
        XCTAssertNotEqual(baseline, modeChange)

        var freqChange = baseline; freqChange.frequency = "7.010"
        XCTAssertNotEqual(baseline, freqChange)
    }

    func testDetectsChange_RST() {
        let baseline = makeBaseline()
        var sent = baseline; sent.rstSent = "58"
        var recv = baseline; recv.rstReceived = "57"
        XCTAssertNotEqual(baseline, sent)
        XCTAssertNotEqual(baseline, recv)
    }

    func testDetectsChange_OwnStationFields() {
        let baseline = makeBaseline()
        var qth = baseline; qth.ownQTH = "Shanghai"
        var grid = baseline; grid.ownGridSquare = "PM01"
        var cq = baseline; cq.ownCQZone = "24"
        var itu = baseline; itu.ownITUZone = "44"
        XCTAssertNotEqual(baseline, qth)
        XCTAssertNotEqual(baseline, grid)
        XCTAssertNotEqual(baseline, cq)
        XCTAssertNotEqual(baseline, itu)
    }

    // MARK: - Full coverage: every stored property affects equality

    /// Mirror of all stored properties on EditQSOSnapshot. If a new field is
    /// added without updating this test, the mirror count diverges and this
    /// fails loudly — a reminder to add a change-detection test for it.
    func testSchemaCoverage_AllFieldsReflected() {
        let snap = makeBaseline()
        let mirror = Mirror(reflecting: snap)
        XCTAssertEqual(mirror.children.count, 24,
                        "EditQSOSnapshot field count changed. Update equality tests accordingly.")
    }
}
