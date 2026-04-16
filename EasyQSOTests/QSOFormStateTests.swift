import XCTest
@testable import EasyQSO

final class QSOFormStateTests: XCTestCase {

    // MARK: - hasUserInput: empty form

    func testEmptyForm_HasNoUserInput() {
        let state = QSOFormState()
        XCTAssertFalse(state.hasUserInput)
    }

    // MARK: - hasUserInput: each contact field triggers detection

    func testCallsign_DetectedAsUserInput() {
        let state = QSOFormState(callsign: "BG5ABC")
        XCTAssertTrue(state.hasUserInput)
    }

    func testRstSent_DetectedAsUserInput() {
        let state = QSOFormState(rstSent: "59")
        XCTAssertTrue(state.hasUserInput)
    }

    func testRstReceived_DetectedAsUserInput() {
        let state = QSOFormState(rstReceived: "59")
        XCTAssertTrue(state.hasUserInput)
    }

    func testName_DetectedAsUserInput() {
        let state = QSOFormState(name: "John")
        XCTAssertTrue(state.hasUserInput)
    }

    func testQTH_DetectedAsUserInput() {
        let state = QSOFormState(qth: "Beijing")
        XCTAssertTrue(state.hasUserInput)
    }

    func testGridSquare_DetectedAsUserInput() {
        let state = QSOFormState(gridSquare: "OM89")
        XCTAssertTrue(state.hasUserInput)
    }

    func testCQZone_DetectedAsUserInput() {
        let state = QSOFormState(cqZone: "24")
        XCTAssertTrue(state.hasUserInput)
    }

    func testITUZone_DetectedAsUserInput() {
        let state = QSOFormState(ituZone: "44")
        XCTAssertTrue(state.hasUserInput)
    }

    func testSatellite_DetectedAsUserInput() {
        let state = QSOFormState(satellite: "RS-44")
        XCTAssertTrue(state.hasUserInput)
    }

    func testRemarks_DetectedAsUserInput() {
        let state = QSOFormState(remarks: "Good signal")
        XCTAssertTrue(state.hasUserInput)
    }

    func testExtendedFields_DetectedAsUserInput() {
        let state = QSOFormState(extendedFields: ["CONTEST_ID": "CQ-WW-SSB"])
        XCTAssertTrue(state.hasUserInput)
    }

    // MARK: - hasUserInput: picker-specific regression tests (the bug)

    func testSatelliteOnly_DetectedAsUserInput() {
        // Regression: satellite was missing from hasUserInput before the fix.
        let state = QSOFormState(satellite: "ISS")
        XCTAssertTrue(state.hasUserInput,
                       "Selecting only a satellite must count as user input for pull-to-refresh reset")
    }

    func testContestOnly_DetectedAsUserInput() {
        let state = QSOFormState(extendedFields: ["CONTEST_ID": "ARRL-DX-CW"])
        XCTAssertTrue(state.hasUserInput,
                       "Selecting only a contest must count as user input")
    }

    func testDXCCOnly_DetectedAsUserInput() {
        let state = QSOFormState(extendedFields: ["DXCC": "291"])
        XCTAssertTrue(state.hasUserInput,
                       "Selecting only a DXCC entity must count as user input")
    }

    func testMyDXCCOnly_DetectedAsUserInput() {
        let state = QSOFormState(extendedFields: ["MY_DXCC": "318"])
        XCTAssertTrue(state.hasUserInput)
    }

    // MARK: - hasUserInput: radio fields — user-edited vs autofilled

    func testBandManuallyChanged_IsUserInput() {
        let state = QSOFormState(band: "40m")
        XCTAssertTrue(state.hasUserInput,
                       "User manually changing band from default should count as input")
    }

    func testModeManuallyChanged_IsUserInput() {
        let state = QSOFormState(mode: "CW")
        XCTAssertTrue(state.hasUserInput,
                       "User manually changing mode from default should count as input")
    }

    func testFrequencyManuallyEntered_IsUserInput() {
        let state = QSOFormState(frequency: "14.200")
        XCTAssertTrue(state.hasUserInput,
                       "User manually typing a frequency should count as input")
    }

    func testSubmodeManuallyChanged_IsUserInput() {
        let state = QSOFormState(submode: "USB")
        XCTAssertTrue(state.hasUserInput)
    }

    func testTxPowerManuallyEntered_IsUserInput() {
        let state = QSOFormState(txPower: "100")
        XCTAssertTrue(state.hasUserInput)
    }

    func testBandAutoFilled_NotUserInput() {
        let state = QSOFormState(band: "40m", autoFilledFields: ["BAND"])
        XCTAssertFalse(state.hasUserInput,
                        "Band set by autofill should not count as user input")
    }

    func testModeAutoFilled_NotUserInput() {
        let state = QSOFormState(mode: "CW", autoFilledFields: ["MODE"])
        XCTAssertFalse(state.hasUserInput)
    }

    func testFrequencyAutoFilled_NotUserInput() {
        let state = QSOFormState(frequency: "14.200", autoFilledFields: ["FREQ"])
        XCTAssertFalse(state.hasUserInput)
    }

    func testSubmodeAutoFilled_NotUserInput() {
        let state = QSOFormState(submode: "USB", autoFilledFields: ["SUBMODE"])
        XCTAssertFalse(state.hasUserInput)
    }

    func testTxPowerAutoFilled_NotUserInput() {
        let state = QSOFormState(txPower: "100", autoFilledFields: ["TX_PWR"])
        XCTAssertFalse(state.hasUserInput)
    }

    func testBandStillAtDefault_NotUserInput() {
        // Even without autofill flag, default value doesn't count
        let state = QSOFormState(band: "20m")
        XCTAssertFalse(state.hasUserInput)
    }

    func testModeStillAtDefault_NotUserInput() {
        let state = QSOFormState(mode: "SSB")
        XCTAssertFalse(state.hasUserInput)
    }

    func testAllRadioFieldsAutoFilled_NotUserInput() {
        let state = QSOFormState(
            band: "40m", mode: "CW", submode: "PCW",
            frequency: "7.010", rxFrequency: "7.020", txPower: "100",
            autoFilledFields: ["BAND", "MODE", "SUBMODE", "FREQ", "RX_FREQ", "TX_PWR"]
        )
        XCTAssertFalse(state.hasUserInput,
                        "Fully autofilled radio settings should not count as user input")
    }

    func testMixedAutoFillAndManual_OnlyManualCounts() {
        // Band autofilled, but frequency manually entered
        let state = QSOFormState(band: "40m", frequency: "7.010",
                                  autoFilledFields: ["BAND"])
        XCTAssertTrue(state.hasUserInput,
                       "Manual frequency entry should count even when band is autofilled")
    }

    // MARK: - hasUserInput: multiple fields

    func testMultipleFieldsFilled() {
        let state = QSOFormState(callsign: "BG5ABC", satellite: "ISS",
                                  extendedFields: ["CONTEST_ID": "CQ-WW-SSB"])
        XCTAssertTrue(state.hasUserInput)
    }

    // MARK: - resetAll: clears every field

    func testResetAll_ClearsAllUserInputFields() {
        var state = QSOFormState(
            callsign: "BG5ABC", rstSent: "59", rstReceived: "59",
            name: "John", qth: "Beijing", gridSquare: "OM89",
            cqZone: "24", ituZone: "44", satellite: "RS-44",
            remarks: "Test", extendedFields: ["CONTEST_ID": "CQ-WW-SSB", "DXCC": "291"]
        )
        state.resetAll()
        XCTAssertFalse(state.hasUserInput, "After resetAll, hasUserInput must be false")
    }

    func testResetAll_ClearsSatellite() {
        var state = QSOFormState(satellite: "ISS")
        state.resetAll()
        XCTAssertEqual(state.satellite, "")
    }

    func testResetAll_ClearsContestFromExtendedFields() {
        var state = QSOFormState(extendedFields: ["CONTEST_ID": "ARRL-DX-CW"])
        state.resetAll()
        XCTAssertTrue(state.extendedFields.isEmpty)
        XCTAssertNil(state.extendedFields["CONTEST_ID"])
    }

    func testResetAll_ClearsDXCCFromExtendedFields() {
        var state = QSOFormState(extendedFields: ["DXCC": "291", "MY_DXCC": "318"])
        state.resetAll()
        XCTAssertTrue(state.extendedFields.isEmpty)
    }

    func testResetAll_RestoresDefaultBandAndMode() {
        var state = QSOFormState(band: "40m", mode: "CW", submode: "PCW")
        state.resetAll()
        XCTAssertEqual(state.band, "20m")
        XCTAssertEqual(state.mode, "SSB")
        XCTAssertEqual(state.submode, "")
    }

    func testResetAll_ClearsRadioFields() {
        var state = QSOFormState(frequency: "14.200", rxFrequency: "14.250",
                                  rxBand: "20m", txPower: "100")
        state.resetAll()
        XCTAssertEqual(state.frequency, "")
        XCTAssertEqual(state.rxFrequency, "")
        XCTAssertEqual(state.rxBand, "")
        XCTAssertEqual(state.txPower, "")
    }

    func testResetAll_ClearsOwnStationExtendedFields() {
        var state = QSOFormState(extendedFields: [
            "STATION_CALLSIGN": "BG5ABC",
            "MY_RIG": "IC-7300",
            "CONTEST_ID": "CQ-WW-SSB"
        ])
        state.resetAll()
        XCTAssertTrue(state.extendedFields.isEmpty,
                       "resetAll must clear ALL extended fields including own-station keys")
    }

    // MARK: - clearTransient: preserves radio settings

    func testClearTransient_PreservesBandModeFrequency() {
        var state = QSOFormState(
            callsign: "BG5ABC", band: "40m", mode: "CW",
            submode: "PCW", frequency: "7.010", rxFrequency: "7.020", txPower: "50"
        )
        state.clearTransient()
        XCTAssertEqual(state.band, "40m")
        XCTAssertEqual(state.mode, "CW")
        XCTAssertEqual(state.submode, "PCW")
        XCTAssertEqual(state.frequency, "7.010")
        XCTAssertEqual(state.rxFrequency, "7.020")
        XCTAssertEqual(state.txPower, "50")
    }

    func testClearTransient_PreservesSatellite() {
        var state = QSOFormState(callsign: "BG5ABC", satellite: "RS-44")
        state.clearTransient()
        XCTAssertEqual(state.satellite, "RS-44",
                        "Satellite must be preserved during transient clear (between contacts)")
    }

    func testClearTransient_ClearsContactFields() {
        var state = QSOFormState(
            callsign: "BG5ABC", rstSent: "59", rstReceived: "59",
            name: "John", qth: "Beijing", gridSquare: "OM89",
            cqZone: "24", ituZone: "44", remarks: "Test QSO"
        )
        state.clearTransient()
        XCTAssertEqual(state.callsign, "")
        XCTAssertEqual(state.rstSent, "")
        XCTAssertEqual(state.rstReceived, "")
        XCTAssertEqual(state.name, "")
        XCTAssertEqual(state.qth, "")
        XCTAssertEqual(state.gridSquare, "")
        XCTAssertEqual(state.cqZone, "")
        XCTAssertEqual(state.ituZone, "")
        XCTAssertEqual(state.remarks, "")
    }

    func testClearTransient_PreservesOwnStationExtendedFields() {
        var state = QSOFormState(extendedFields: [
            "STATION_CALLSIGN": "BG5ABC",
            "MY_RIG": "IC-7300",
            "MY_ANTENNA": "Yagi",
            "MY_GRIDSQUARE": "OM89xx",
            "CONTEST_ID": "CQ-WW-SSB",
            "DXCC": "291"
        ])
        state.clearTransient()
        XCTAssertEqual(state.extendedFields["STATION_CALLSIGN"], "BG5ABC")
        XCTAssertEqual(state.extendedFields["MY_RIG"], "IC-7300")
        XCTAssertEqual(state.extendedFields["MY_ANTENNA"], "Yagi")
        XCTAssertEqual(state.extendedFields["MY_GRIDSQUARE"], "OM89xx")
    }

    func testClearTransient_RemovesNonOwnStationExtendedFields() {
        var state = QSOFormState(extendedFields: [
            "STATION_CALLSIGN": "BG5ABC",
            "CONTEST_ID": "CQ-WW-SSB",
            "DXCC": "291",
            "MY_DXCC": "318"
        ])
        state.clearTransient()
        XCTAssertNil(state.extendedFields["CONTEST_ID"],
                      "CONTEST_ID must be cleared during transient clear")
        XCTAssertNil(state.extendedFields["DXCC"],
                      "DXCC must be cleared during transient clear")
        XCTAssertNil(state.extendedFields["MY_DXCC"],
                      "MY_DXCC is not an own-station key and should be cleared")
    }

    // MARK: - clearTransient: each own-station key preserved

    func testClearTransient_AllOwnStationKeysPreserved() {
        let allOwnKeys: [String: String] = [
            "STATION_CALLSIGN": "BG5ABC",
            "OPERATOR": "BG5ABC",
            "MY_RIG": "IC-7300",
            "MY_ANTENNA": "Dipole",
            "MY_POTA_REF": "CN-0001",
            "MY_SOTA_REF": "BV/TP-001",
            "MY_WWFF_REF": "BVFF-0001",
            "MY_SIG": "POTA",
            "MY_SIG_INFO": "CN-0001",
            "MY_CITY": "Beijing",
            "MY_GRIDSQUARE": "OM89xx",
            "MY_CQ_ZONE": "24",
            "MY_ITU_ZONE": "44",
            "MY_LAT": "N039 55.000",
            "MY_LON": "E116 23.000"
        ]
        var state = QSOFormState(extendedFields: allOwnKeys)
        state.clearTransient()
        XCTAssertEqual(state.extendedFields.count, allOwnKeys.count,
                        "All \(allOwnKeys.count) own-station keys must be preserved")
        for (key, value) in allOwnKeys {
            XCTAssertEqual(state.extendedFields[key], value, "Key \(key) should be preserved")
        }
    }

    // MARK: - ownStationKeys completeness

    func testOwnStationKeys_ContainsExpectedKeys() {
        let expected: Set<String> = [
            "STATION_CALLSIGN", "OPERATOR", "MY_RIG", "MY_ANTENNA",
            "MY_POTA_REF", "MY_SOTA_REF", "MY_WWFF_REF",
            "MY_SIG", "MY_SIG_INFO", "MY_CITY", "MY_GRIDSQUARE",
            "MY_CQ_ZONE", "MY_ITU_ZONE", "MY_LAT", "MY_LON"
        ]
        XCTAssertEqual(QSOFormState.ownStationKeys, expected)
    }

    // MARK: - resetAll vs clearTransient: satellite behavior difference

    func testResetAll_ClearsSatellite_ClearTransient_PreservesIt() {
        var full = QSOFormState(callsign: "BG5ABC", satellite: "ISS")
        var transient = full

        full.resetAll()
        transient.clearTransient()

        XCTAssertEqual(full.satellite, "",
                        "resetAll must clear satellite")
        XCTAssertEqual(transient.satellite, "ISS",
                        "clearTransient must preserve satellite")
    }

    // MARK: - resetAll vs clearTransient: extendedFields behavior difference

    func testResetAll_ClearsAll_ClearTransient_KeepsOwnStation() {
        let fields: [String: String] = [
            "STATION_CALLSIGN": "BG5ABC",
            "CONTEST_ID": "CQ-WW-SSB"
        ]
        var full = QSOFormState(extendedFields: fields)
        var transient = QSOFormState(extendedFields: fields)

        full.resetAll()
        transient.clearTransient()

        XCTAssertTrue(full.extendedFields.isEmpty)
        XCTAssertEqual(transient.extendedFields.count, 1)
        XCTAssertEqual(transient.extendedFields["STATION_CALLSIGN"], "BG5ABC")
    }
}
