import XCTest
@testable import EasyQSO

/// Tests that core ADIF field tags (SAT_NAME, CALL, BAND, etc.) are properly
/// separated from extended fields (adifFieldsData) so that dual-storage
/// inconsistencies don't arise. When a core tag lingers in extendedFields,
/// editing the dedicated @State (e.g., satellite) doesn't update the stale
/// copy in extendedFields, which then gets written back to adifFieldsData on
/// save — causing the old value to reappear on next load.
final class CoreFieldStrippingTests: XCTestCase {

    // MARK: - ADIFFields.coreFieldIds

    func testCoreFieldIds_ContainsSATNAME() {
        XCTAssertTrue(ADIFFields.coreFieldIds.contains("SAT_NAME"),
                       "SAT_NAME must be in coreFieldIds to be stripped from extendedFields")
    }

    func testCoreFieldIds_ContainsCommonCoreFields() {
        let expected = ["CALL", "BAND", "MODE", "FREQ", "RST_SENT", "RST_RCVD",
                        "NAME", "QTH", "GRIDSQUARE", "CQZ", "ITUZ", "SAT_NAME", "COMMENT"]
        for tag in expected {
            XCTAssertTrue(ADIFFields.coreFieldIds.contains(tag),
                           "\(tag) should be a core field")
        }
    }

    func testCoreFieldIds_DoesNotContainExtendedFields() {
        let extendedTags = ["CONTEST_ID", "DXCC", "MY_DXCC", "STATION_CALLSIGN",
                            "MY_RIG", "MY_ANTENNA", "SUBMODE"]
        for tag in extendedTags {
            XCTAssertFalse(ADIFFields.coreFieldIds.contains(tag),
                            "\(tag) should NOT be a core field (it's extended)")
        }
    }

    // MARK: - Stripping logic (simulates what EditQSOView init / save does)

    func testStripping_RemovesStaleSATNAME() {
        let adifFields: [String: String] = [
            "SAT_NAME": "OLD-SATELLITE",
            "CONTEST_ID": "CQ-WW-SSB",
            "SUBMODE": "USB",
            "DXCC": "291"
        ]
        let stripped = adifFields.filter { !ADIFFields.coreFieldIds.contains($0.key) }

        XCTAssertNil(stripped["SAT_NAME"],
                      "SAT_NAME must be stripped — it's handled by the dedicated satellite column")
        XCTAssertEqual(stripped["CONTEST_ID"], "CQ-WW-SSB",
                        "CONTEST_ID must be preserved — it's an extended field")
        XCTAssertEqual(stripped["SUBMODE"], "USB")
        XCTAssertEqual(stripped["DXCC"], "291")
    }

    func testStripping_RemovesAllCoreFields() {
        var adifFields: [String: String] = [
            "CONTEST_ID": "ARRL-DX-CW",
            "MY_RIG": "IC-7300"
        ]
        // Add all core field IDs with dummy values
        for coreId in ADIFFields.coreFieldIds {
            adifFields[coreId] = "stale-value"
        }

        let stripped = adifFields.filter { !ADIFFields.coreFieldIds.contains($0.key) }

        XCTAssertEqual(stripped.count, 2,
                        "Only the 2 extended fields should survive stripping")
        XCTAssertEqual(stripped["CONTEST_ID"], "ARRL-DX-CW")
        XCTAssertEqual(stripped["MY_RIG"], "IC-7300")
    }

    func testStripping_EmptyDict_StaysEmpty() {
        let stripped = [String: String]().filter { !ADIFFields.coreFieldIds.contains($0.key) }
        XCTAssertTrue(stripped.isEmpty)
    }

    // MARK: - Regression: satellite edit round-trip

    func testSatelliteEditRoundTrip_StaleSATNAMEDoesNotPersist() {
        // Simulates: record has SAT_NAME in adifFields from a previous save bug.
        // User opens EditQSO, changes satellite to "ISS", saves.
        // On next load, SAT_NAME must NOT override the dedicated satellite column.

        let originalAdifFields: [String: String] = [
            "SAT_NAME": "DELETED-SAT",
            "CONTEST_ID": "CQ-WW-SSB"
        ]

        // --- Load phase: strip core fields ---
        let loadedExtendedFields = originalAdifFields.filter {
            !ADIFFields.coreFieldIds.contains($0.key)
        }
        XCTAssertNil(loadedExtendedFields["SAT_NAME"],
                      "On load, SAT_NAME should not be in extendedFields")
        XCTAssertEqual(loadedExtendedFields["CONTEST_ID"], "CQ-WW-SSB",
                        "On load, CONTEST_ID should still be in extendedFields")

        // --- Save phase: strip core fields ---
        var saveFields = loadedExtendedFields
        saveFields["SUBMODE"] = "USB"  // added during save
        let savedFields = saveFields.filter { !ADIFFields.coreFieldIds.contains($0.key) }
        XCTAssertNil(savedFields["SAT_NAME"],
                      "On save, SAT_NAME must not appear in adifFields")
    }
}
