import XCTest
@testable import EasyQSO

/// Tests for the orphan detection helper used by Satellite/Contest pickers
/// to surface values that are not in the manager's known list — typically
/// because the user deleted a custom entry after using it, or imported a
/// QSO whose value is unfamiliar.
final class PickerOrphanDetectorTests: XCTestCase {

    // MARK: - isOrphan

    func testIsOrphan_EmptyValue_False() {
        XCTAssertFalse(PickerOrphanDetector.isOrphan(value: "", knownItems: []))
        XCTAssertFalse(PickerOrphanDetector.isOrphan(value: "", knownItems: ["ISS", "AO-91"]))
    }

    func testIsOrphan_ValueInList_False() {
        XCTAssertFalse(PickerOrphanDetector.isOrphan(value: "ISS", knownItems: ["ISS", "AO-91"]))
    }

    func testIsOrphan_ValueNotInList_True() {
        XCTAssertTrue(PickerOrphanDetector.isOrphan(value: "MYSAT-99", knownItems: ["ISS", "AO-91"]))
    }

    func testIsOrphan_EmptyKnownList_True() {
        // Value set but no known items → orphan.
        XCTAssertTrue(PickerOrphanDetector.isOrphan(value: "ISS", knownItems: []))
    }

    func testIsOrphan_CaseInsensitiveMatch() {
        XCTAssertFalse(PickerOrphanDetector.isOrphan(value: "iss", knownItems: ["ISS"]))
        XCTAssertFalse(PickerOrphanDetector.isOrphan(value: "Iss", knownItems: ["ISS"]))
        XCTAssertFalse(PickerOrphanDetector.isOrphan(value: "ISS", knownItems: ["iss"]))
    }

    // MARK: - Regression scenarios (the bug)

    func testIsOrphan_DeletedCustomSatellite() {
        // User created "MYSAT-1", used it, then deleted it.
        let knownAfterDeletion = ["ISS", "AO-91", "SO-50"]
        XCTAssertTrue(
            PickerOrphanDetector.isOrphan(value: "MYSAT-1", knownItems: knownAfterDeletion),
            "Custom value still on the record but removed from the manager must be detected as orphan"
        )
    }

    func testIsOrphan_ExternallyImportedUnknownContest() {
        // QSO imported from ADIF with a contest ID that's not preset and
        // hasn't been added as a custom.
        let knownContests = ["CQ-WW-SSB", "ARRL-DX-CW", "CQ-WPX-CW"]
        XCTAssertTrue(
            PickerOrphanDetector.isOrphan(value: "OBSCURE-REGIONAL-CONTEST", knownItems: knownContests),
            "Imported contest value must be detected as orphan"
        )
    }

    // MARK: - matchesSearch

    func testMatchesSearch_EmptySearch_AlwaysTrue() {
        XCTAssertTrue(PickerOrphanDetector.matchesSearch(value: "ISS", searchText: ""))
        XCTAssertTrue(PickerOrphanDetector.matchesSearch(value: "anything", searchText: ""))
    }

    func testMatchesSearch_SubstringMatch() {
        XCTAssertTrue(PickerOrphanDetector.matchesSearch(value: "AO-91", searchText: "AO"))
        XCTAssertTrue(PickerOrphanDetector.matchesSearch(value: "AO-91", searchText: "91"))
    }

    func testMatchesSearch_CaseInsensitive() {
        XCTAssertTrue(PickerOrphanDetector.matchesSearch(value: "ISS", searchText: "iss"))
        XCTAssertTrue(PickerOrphanDetector.matchesSearch(value: "iss", searchText: "ISS"))
    }

    func testMatchesSearch_NoMatch() {
        XCTAssertFalse(PickerOrphanDetector.matchesSearch(value: "ISS", searchText: "XYZ"))
    }

    // MARK: - Picker UX integration: show orphan only when it matches search

    func testOrphanVisibilityCombined_EmptySearch() {
        let value = "MYSAT-1"
        let known = ["ISS", "AO-91"]
        let shouldShow = PickerOrphanDetector.isOrphan(value: value, knownItems: known) &&
                         PickerOrphanDetector.matchesSearch(value: value, searchText: "")
        XCTAssertTrue(shouldShow, "With empty search, an orphan value should always be visible")
    }

    func testOrphanVisibilityCombined_SearchMatchesOrphan() {
        let shouldShow = PickerOrphanDetector.isOrphan(value: "MYSAT-1", knownItems: ["ISS"]) &&
                         PickerOrphanDetector.matchesSearch(value: "MYSAT-1", searchText: "MY")
        XCTAssertTrue(shouldShow)
    }

    func testOrphanVisibilityCombined_SearchDoesNotMatchOrphan() {
        let shouldShow = PickerOrphanDetector.isOrphan(value: "MYSAT-1", knownItems: ["ISS"]) &&
                         PickerOrphanDetector.matchesSearch(value: "MYSAT-1", searchText: "ARRL")
        XCTAssertFalse(shouldShow,
                        "When searching for something that doesn't match, the orphan row should hide")
    }
}
