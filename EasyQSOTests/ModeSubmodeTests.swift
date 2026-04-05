import XCTest
import CoreData
@testable import EasyQSO

final class ModeSubmodeTests: XCTestCase {

    private var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        context = TestHelper.createInMemoryContext()
    }

    override func tearDown() {
        context = nil
        super.tearDown()
    }

    // MARK: - ModeManager.resolveMode

    func testResolveModeForParentMode() {
        let result = ModeManager.resolveMode("SSB")
        XCTAssertEqual(result.mode, "SSB")
        XCTAssertNil(result.submode)
    }

    func testResolveModeForSubmode() {
        let result = ModeManager.resolveMode("LSB")
        XCTAssertEqual(result.mode, "SSB")
        XCTAssertEqual(result.submode, "LSB")
    }

    func testResolveModeForUSB() {
        let result = ModeManager.resolveMode("USB")
        XCTAssertEqual(result.mode, "SSB")
        XCTAssertEqual(result.submode, "USB")
    }

    func testResolveModeForFT4() {
        let result = ModeManager.resolveMode("FT4")
        XCTAssertEqual(result.mode, "MFSK")
        XCTAssertEqual(result.submode, "FT4")
    }

    func testResolveModeForFT8StandaloneMode() {
        let result = ModeManager.resolveMode("FT8")
        XCTAssertEqual(result.mode, "FT8")
        XCTAssertNil(result.submode)
    }

    func testResolveModeForPCW() {
        let result = ModeManager.resolveMode("PCW")
        XCTAssertEqual(result.mode, "CW")
        XCTAssertEqual(result.submode, "PCW")
    }

    func testResolveModeForASCI() {
        let result = ModeManager.resolveMode("ASCI")
        XCTAssertEqual(result.mode, "RTTY")
        XCTAssertEqual(result.submode, "ASCI")
    }

    func testResolveModeForUnknownMode() {
        let result = ModeManager.resolveMode("MYMODE")
        XCTAssertEqual(result.mode, "MYMODE")
        XCTAssertNil(result.submode)
    }

    func testResolveModeCaseInsensitive() {
        let result = ModeManager.resolveMode("lsb")
        XCTAssertEqual(result.mode, "SSB")
        XCTAssertEqual(result.submode, "LSB")
    }

    // MARK: - ModeManager.parentMode

    func testParentModeForSubmode() {
        XCTAssertEqual(ModeManager.parentMode(for: "LSB"), "SSB")
        XCTAssertEqual(ModeManager.parentMode(for: "USB"), "SSB")
        XCTAssertEqual(ModeManager.parentMode(for: "PCW"), "CW")
        XCTAssertEqual(ModeManager.parentMode(for: "FT4"), "MFSK")
        XCTAssertEqual(ModeManager.parentMode(for: "ASCI"), "RTTY")
        XCTAssertEqual(ModeManager.parentMode(for: "C4FM"), "DIGITALVOICE")
        XCTAssertEqual(ModeManager.parentMode(for: "DSTAR"), "DIGITALVOICE")
        XCTAssertEqual(ModeManager.parentMode(for: "PSK31"), "PSK")
    }

    func testParentModeForTopLevelModeIsNil() {
        XCTAssertNil(ModeManager.parentMode(for: "SSB"))
        XCTAssertNil(ModeManager.parentMode(for: "CW"))
        XCTAssertNil(ModeManager.parentMode(for: "FT8"))
        XCTAssertNil(ModeManager.parentMode(for: "FM"))
    }

    func testParentModeForUnknownIsNil() {
        XCTAssertNil(ModeManager.parentMode(for: "UNKNOWN_MODE"))
    }

    // MARK: - ModeManager.isKnownSubmode

    func testIsKnownSubmode() {
        XCTAssertTrue(ModeManager.isKnownSubmode("LSB"))
        XCTAssertTrue(ModeManager.isKnownSubmode("USB"))
        XCTAssertTrue(ModeManager.isKnownSubmode("FT4"))
        XCTAssertTrue(ModeManager.isKnownSubmode("PSK31"))
        XCTAssertFalse(ModeManager.isKnownSubmode("SSB"))
        XCTAssertFalse(ModeManager.isKnownSubmode("FT8"))
        XCTAssertFalse(ModeManager.isKnownSubmode("UNKNOWN"))
    }

    // MARK: - ModeManager.isVoiceMode / isCWMode

    func testIsVoiceModeForSSB() {
        XCTAssertTrue(ModeManager.isVoiceMode(mode: "SSB", submode: nil))
        XCTAssertTrue(ModeManager.isVoiceMode(mode: "SSB", submode: "LSB"))
        XCTAssertTrue(ModeManager.isVoiceMode(mode: "SSB", submode: "USB"))
    }

    func testIsVoiceModeForFMAndAM() {
        XCTAssertTrue(ModeManager.isVoiceMode(mode: "FM", submode: nil))
        XCTAssertTrue(ModeManager.isVoiceMode(mode: "AM", submode: nil))
    }

    func testIsVoiceModeForDigitalIsFalse() {
        XCTAssertFalse(ModeManager.isVoiceMode(mode: "FT8", submode: nil))
        XCTAssertFalse(ModeManager.isVoiceMode(mode: "CW", submode: nil))
        XCTAssertFalse(ModeManager.isVoiceMode(mode: "MFSK", submode: "FT4"))
    }

    func testIsCWMode() {
        XCTAssertTrue(ModeManager.isCWMode(mode: "CW", submode: nil))
        XCTAssertTrue(ModeManager.isCWMode(mode: "CW", submode: "PCW"))
        XCTAssertFalse(ModeManager.isCWMode(mode: "SSB", submode: nil))
    }

    // MARK: - ModeManager.pickerItems

    func testPickerItemsContainsModeAndSubmodes() {
        let manager = ModeManager.shared
        let items = manager.pickerItems(currentMode: "SSB", currentSubmode: "")
        let ssbItem = items.first { $0.tagValue == "SSB" }
        XCTAssertNotNil(ssbItem, "SSB should be in picker items")
        XCTAssertFalse(ssbItem!.isSubmode)

        let lsbItem = items.first { $0.tagValue == "LSB" }
        let usbItem = items.first { $0.tagValue == "USB" }

        if !manager.isHidden("SSB") {
            XCTAssertNotNil(lsbItem, "LSB should be in picker when SSB is visible")
            XCTAssertNotNil(usbItem, "USB should be in picker when SSB is visible")
            XCTAssertTrue(lsbItem!.isSubmode)
            XCTAssertEqual(lsbItem!.adifMode, "SSB")
        }
    }

    func testPickerItemSubmodeIndentation() {
        let manager = ModeManager.shared
        let items = manager.pickerItems(currentMode: "SSB", currentSubmode: "")

        for item in items where item.isSubmode {
            XCTAssertTrue(item.displayLabel.hasPrefix("    "),
                          "Submode \(item.tagValue) should be indented in display")
        }

        for item in items where !item.isSubmode {
            XCTAssertFalse(item.displayLabel.hasPrefix("    "),
                           "Mode \(item.tagValue) should NOT be indented")
        }
    }

    func testPickerItemsIncludeCurrentValueEvenIfHidden() {
        let manager = ModeManager.shared
        let items = manager.pickerItems(currentMode: "OLIVIA", currentSubmode: "OLIVIA 8/500")

        let modeItem = items.first { $0.tagValue == "OLIVIA" }
        XCTAssertNotNil(modeItem, "Current mode should be in picker even if hidden")

        let submodeItem = items.first { $0.tagValue == "OLIVIA 8/500" }
        XCTAssertNotNil(submodeItem, "Current submode should be in picker even if hidden")
    }

    // MARK: - ModePickerItem tag values

    func testModePickerItemTagValueForMode() {
        let item = ModePickerItem(id: "m_SSB", adifMode: "SSB", adifSubmode: nil, isSubmode: false)
        XCTAssertEqual(item.tagValue, "SSB")
    }

    func testModePickerItemTagValueForSubmode() {
        let item = ModePickerItem(id: "s_LSB", adifMode: "SSB", adifSubmode: "LSB", isSubmode: true)
        XCTAssertEqual(item.tagValue, "LSB")
    }

    // MARK: - ADIF Import: submode-as-mode fault tolerance

    func testImportFaultToleranceLSBAsMode() {
        let record = QSORecord(context: context)
        record.callsign = "TEST1"
        record.date = Date()
        record.band = "20m"
        record.rstSent = "59"
        record.rstReceived = "59"

        var importedMode = "LSB"
        var importedSubmode = ""

        if importedSubmode.isEmpty, let parent = ModeManager.parentMode(for: importedMode) {
            importedSubmode = importedMode
            importedMode = parent
        }

        record.mode = importedMode
        var fields = record.adifFields
        if !importedSubmode.isEmpty {
            fields["SUBMODE"] = importedSubmode
        }
        record.adifFields = fields

        XCTAssertEqual(record.mode, "SSB")
        XCTAssertEqual(record.adifFields["SUBMODE"], "LSB")
    }

    func testImportFaultToleranceFT4AsMode() {
        var importedMode = "FT4"
        var importedSubmode = ""

        if importedSubmode.isEmpty, let parent = ModeManager.parentMode(for: importedMode) {
            importedSubmode = importedMode
            importedMode = parent
        }

        XCTAssertEqual(importedMode, "MFSK")
        XCTAssertEqual(importedSubmode, "FT4")
    }

    func testImportNoFaultToleranceWhenSubmodePresent() {
        var importedMode = "SSB"
        var importedSubmode = "USB"

        if importedSubmode.isEmpty, let parent = ModeManager.parentMode(for: importedMode) {
            importedSubmode = importedMode
            importedMode = parent
        }

        XCTAssertEqual(importedMode, "SSB", "Should not change mode when SUBMODE already present")
        XCTAssertEqual(importedSubmode, "USB")
    }

    func testImportNoFaultToleranceForRealMode() {
        var importedMode = "FT8"
        var importedSubmode = ""

        if importedSubmode.isEmpty, let parent = ModeManager.parentMode(for: importedMode) {
            importedSubmode = importedMode
            importedMode = parent
        }

        XCTAssertEqual(importedMode, "FT8", "FT8 is a real mode, should not be resolved")
        XCTAssertEqual(importedSubmode, "")
    }

    // MARK: - ADIF Export: SUBMODE output

    func testExportIncludesSubmode() throws {
        let record = QSORecord(context: context)
        record.callsign = "BG5EXP"
        record.date = Date()
        record.band = "20m"
        record.mode = "SSB"
        record.rstSent = "59"
        record.rstReceived = "59"
        record.adifFields = ["SUBMODE": "LSB"]
        try context.save()

        let adifData = ADIFHelper.generateADIF(from: [record])
        let parsed = ADIFHelper.parseADIFRecords(adifData)

        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0]["MODE"], "SSB")
        XCTAssertEqual(parsed[0]["SUBMODE"], "LSB")
    }

    func testExportOmitsSubmodeWhenEmpty() throws {
        let record = QSORecord(context: context)
        record.callsign = "BG5EXP"
        record.date = Date()
        record.band = "20m"
        record.mode = "FT8"
        record.rstSent = "-10"
        record.rstReceived = "-12"
        try context.save()

        let adifData = ADIFHelper.generateADIF(from: [record])
        let parsed = ADIFHelper.parseADIFRecords(adifData)

        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0]["MODE"], "FT8")
        XCTAssertNil(parsed[0]["SUBMODE"])
    }

    func testExportSubmodeNotDuplicated() throws {
        let record = QSORecord(context: context)
        record.callsign = "BG5DUP"
        record.date = Date()
        record.band = "40m"
        record.mode = "CW"
        record.rstSent = "599"
        record.rstReceived = "599"
        record.adifFields = ["SUBMODE": "PCW", "CONTEST_ID": "CQ-WW-CW"]
        try context.save()

        let adifData = ADIFHelper.generateADIF(from: [record])
        let adifString = String(data: adifData, encoding: .utf8)!

        let submodeCount = adifString.components(separatedBy: "<SUBMODE:").count - 1
        XCTAssertEqual(submodeCount, 1, "SUBMODE should appear exactly once")
    }

    // MARK: - Submode migration logic

    func testMigrationFixesSubmodeAsMode() throws {
        let record = QSORecord(context: context)
        record.callsign = "BG5MIG"
        record.date = Date()
        record.band = "20m"
        record.mode = "LSB"
        record.rstSent = "59"
        record.rstReceived = "59"
        try context.save()

        let request = NSFetchRequest<QSORecord>(entityName: "QSORecord")
        let records = try context.fetch(request)

        for r in records {
            if let parentMode = ModeManager.parentMode(for: r.mode) {
                var fields = r.adifFields
                if (fields["SUBMODE"] ?? "").isEmpty {
                    fields["SUBMODE"] = r.mode
                    r.adifFields = fields
                    r.mode = parentMode
                }
            }
        }
        try context.save()

        let updated = try context.fetch(request)
        let migrated = updated.first!
        XCTAssertEqual(migrated.mode, "SSB")
        XCTAssertEqual(migrated.adifFields["SUBMODE"], "LSB")
    }

    func testMigrationSkipsRecordWithExistingSubmode() throws {
        let record = QSORecord(context: context)
        record.callsign = "BG5SKP"
        record.date = Date()
        record.band = "20m"
        record.mode = "SSB"
        record.rstSent = "59"
        record.rstReceived = "59"
        record.adifFields = ["SUBMODE": "USB"]
        try context.save()

        let request = NSFetchRequest<QSORecord>(entityName: "QSORecord")
        let records = try context.fetch(request)

        for r in records {
            if let parentMode = ModeManager.parentMode(for: r.mode) {
                var fields = r.adifFields
                if (fields["SUBMODE"] ?? "").isEmpty {
                    fields["SUBMODE"] = r.mode
                    r.adifFields = fields
                    r.mode = parentMode
                }
            }
        }
        try context.save()

        let updated = try context.fetch(request)
        let same = updated.first!
        XCTAssertEqual(same.mode, "SSB", "Mode should stay SSB")
        XCTAssertEqual(same.adifFields["SUBMODE"], "USB", "Submode should stay USB")
    }

    func testMigrationDoesNotTouchRegularModes() throws {
        let record = QSORecord(context: context)
        record.callsign = "BG5REG"
        record.date = Date()
        record.band = "20m"
        record.mode = "FT8"
        record.rstSent = "-10"
        record.rstReceived = "-12"
        try context.save()

        let request = NSFetchRequest<QSORecord>(entityName: "QSORecord")
        let records = try context.fetch(request)

        for r in records {
            if let parentMode = ModeManager.parentMode(for: r.mode) {
                var fields = r.adifFields
                if (fields["SUBMODE"] ?? "").isEmpty {
                    fields["SUBMODE"] = r.mode
                    r.adifFields = fields
                    r.mode = parentMode
                }
            }
        }
        try context.save()

        let updated = try context.fetch(request)
        let same = updated.first!
        XCTAssertEqual(same.mode, "FT8", "FT8 is a real mode, should not be migrated")
        XCTAssertNil(same.adifFields["SUBMODE"])
    }

    // MARK: - ADIFFields group_mode

    func testSubmodeIsInModeGroup() {
        let group = ADIFFields.group(for: "SUBMODE")
        XCTAssertNotNil(group)
        XCTAssertEqual(group?.id, "group_mode")
    }

    func testModeIsInModeGroup() {
        let group = ADIFFields.group(for: "MODE")
        XCTAssertNotNil(group)
        XCTAssertEqual(group?.id, "group_mode")
    }

    func testSubmodeNotInDynamicFields() {
        let grouped = ADIFFields.groupedFieldIds
        XCTAssertTrue(grouped.contains("SUBMODE"),
                      "SUBMODE should be in grouped fields so it doesn't appear as standalone dynamic field")
    }

    // MARK: - ADIF 3.1.7 data integrity

    func testAllSubmodesMappedBackToValidMode() {
        for (mode, submodes) in ModeManager.modeSubmodes {
            for sub in submodes {
                let parent = ModeManager.submodeToMode[sub.uppercased()]
                XCTAssertEqual(parent, mode,
                               "Submode \(sub) should map back to mode \(mode), got \(parent ?? "nil")")
            }
        }
    }

    func testNoSubmodeDuplicatesAcrossModes() {
        var seen = [String: String]()
        for (mode, submodes) in ModeManager.modeSubmodes {
            for sub in submodes {
                let upper = sub.uppercased()
                if let existing = seen[upper] {
                    XCTFail("Submode \(sub) appears in both \(existing) and \(mode)")
                }
                seen[upper] = mode
            }
        }
    }

    func testDefaultEnabledModesAreAllValid() {
        for mode in ModeManager.defaultEnabledModes {
            XCTAssertTrue(ModeManager.allAdifModes.contains(mode),
                          "\(mode) in defaultEnabledModes but not in allAdifModes")
        }
    }

    func testDefaultEnabledSubmodesAreAllValid() {
        for sub in ModeManager.defaultEnabledSubmodes {
            XCTAssertNotNil(ModeManager.presetSubmodeToMode[sub],
                            "\(sub) in defaultEnabledSubmodes but not a known preset submode")
        }
    }

    func testEnabledItemCountIncludesModesPlusSubmodes() {
        let manager = ModeManager.shared

        manager.setHidden(false, for: "SSB")
        manager.setSubmodeHidden(false, for: "LSB")
        manager.setSubmodeHidden(false, for: "USB")

        let count = manager.enabledItemCount
        let modeCount = manager.enabledModes.count
        XCTAssertTrue(count > modeCount,
                      "enabledItemCount (\(count)) should be greater than just mode count (\(modeCount))")
    }

    // MARK: - Submode visibility

    func testSetSubmodeHidden() {
        let manager = ModeManager.shared
        let key = "LSB"

        manager.setSubmodeHidden(false, for: key)
        XCTAssertFalse(manager.isSubmodeHidden(key))

        manager.setSubmodeHidden(true, for: key)
        XCTAssertTrue(manager.isSubmodeHidden(key))

        manager.setSubmodeHidden(false, for: key)
        XCTAssertFalse(manager.isSubmodeHidden(key))
    }

    func testHiddenSubmodeExcludedFromPickerItems() {
        let manager = ModeManager.shared

        manager.setHidden(false, for: "SSB")
        manager.setSubmodeHidden(true, for: "LSB")

        let items = manager.pickerItems(currentMode: "SSB", currentSubmode: "")
        let lsbItem = items.first { $0.tagValue == "LSB" }
        XCTAssertNil(lsbItem, "Hidden submode LSB should not appear in picker")

        let usbItem = items.first { $0.tagValue == "USB" }
        XCTAssertNotNil(usbItem, "Non-hidden submode USB should still appear")

        manager.setSubmodeHidden(false, for: "LSB")
    }

    func testHiddenSubmodeStillIncludedAsCurrentValue() {
        let manager = ModeManager.shared

        manager.setHidden(false, for: "SSB")
        manager.setSubmodeHidden(true, for: "USB")

        let items = manager.pickerItems(currentMode: "SSB", currentSubmode: "USB")
        let usbItem = items.first { $0.tagValue == "USB" }
        XCTAssertNotNil(usbItem, "Hidden submode should appear when it's the current value")

        manager.setSubmodeHidden(false, for: "USB")
    }

    // MARK: - Custom submodes

    func testAddCustomSubmode() {
        let manager = ModeManager.shared
        manager.addCustomSubmode("MYDIGITAL", to: "SSB")
        XCTAssertTrue(manager.customSubmodesForMode("SSB").contains("MYDIGITAL"))
        XCTAssertTrue(manager.allSubmodes(for: "SSB").contains("MYDIGITAL"))
        manager.removeCustomSubmode("MYDIGITAL", from: "SSB")
    }

    func testRemoveCustomSubmode() {
        let manager = ModeManager.shared
        manager.addCustomSubmode("TESTSUB", to: "CW")
        XCTAssertTrue(manager.customSubmodesForMode("CW").contains("TESTSUB"))
        manager.removeCustomSubmode("TESTSUB", from: "CW")
        XCTAssertFalse(manager.customSubmodesForMode("CW").contains("TESTSUB"))
    }

    func testCustomSubmodeAppearsInPickerItems() {
        let manager = ModeManager.shared
        manager.setHidden(false, for: "FM")
        manager.addCustomSubmode("NBFM", to: "FM")

        let items = manager.pickerItems(currentMode: "FM", currentSubmode: "")
        let nbfmItem = items.first { $0.tagValue == "NBFM" }
        XCTAssertNotNil(nbfmItem, "Custom submode should appear in picker")
        XCTAssertTrue(nbfmItem?.isSubmode == true)

        manager.removeCustomSubmode("NBFM", from: "FM")
    }

    func testCustomSubmodeIncludedInSubmodeToMode() {
        let manager = ModeManager.shared
        manager.addCustomSubmode("WBFM", to: "FM")

        XCTAssertEqual(ModeManager.submodeToMode["WBFM"], "FM")
        XCTAssertEqual(ModeManager.parentMode(for: "WBFM"), "FM")
        XCTAssertTrue(ModeManager.isKnownSubmode("WBFM"))

        manager.removeCustomSubmode("WBFM", from: "FM")
    }

    func testCustomSubmodeResolveMode() {
        let manager = ModeManager.shared
        manager.addCustomSubmode("CUSTSUB", to: "AM")

        let result = ModeManager.resolveMode("CUSTSUB")
        XCTAssertEqual(result.mode, "AM")
        XCTAssertEqual(result.submode, "CUSTSUB")

        manager.removeCustomSubmode("CUSTSUB", from: "AM")
    }

    func testCannotAddDuplicateCustomSubmode() {
        let manager = ModeManager.shared
        manager.addCustomSubmode("DUPSUB", to: "SSB")
        manager.addCustomSubmode("DUPSUB", to: "SSB")
        XCTAssertEqual(manager.customSubmodesForMode("SSB").filter { $0 == "DUPSUB" }.count, 1)
        manager.removeCustomSubmode("DUPSUB", from: "SSB")
    }

    func testCannotAddPresetSubmodeAsCustom() {
        let manager = ModeManager.shared
        manager.addCustomSubmode("LSB", to: "SSB")
        XCTAssertFalse(manager.customSubmodesForMode("SSB").contains("LSB"),
                       "Should not allow adding preset submode as custom")
    }

    func testCannotAddSubmodeFromOtherModeAsCustom() {
        let manager = ModeManager.shared
        manager.addCustomSubmode("USB", to: "CW")
        XCTAssertFalse(manager.customSubmodesForMode("CW").contains("USB"),
                       "Should not allow adding submode that belongs to another preset mode")
    }

    func testCustomSubmodeOnCustomMode() {
        let manager = ModeManager.shared
        manager.addCustomMode("MYMODE")
        manager.setHidden(false, for: "MYMODE")
        manager.addCustomSubmode("MYSUB", to: "MYMODE")

        XCTAssertTrue(manager.allSubmodes(for: "MYMODE").contains("MYSUB"))
        let items = manager.pickerItems(currentMode: "MYMODE", currentSubmode: "")
        let subItem = items.first { $0.tagValue == "MYSUB" }
        XCTAssertNotNil(subItem)

        manager.removeCustomSubmode("MYSUB", from: "MYMODE")
        manager.removeCustomMode("MYMODE")
    }

    func testRemoveCustomSubmodeAlsoRemovesHidden() {
        let manager = ModeManager.shared
        manager.addCustomSubmode("HIDESUB", to: "FM")
        manager.setSubmodeHidden(true, for: "HIDESUB")
        XCTAssertTrue(manager.isSubmodeHidden("HIDESUB"))

        manager.removeCustomSubmode("HIDESUB", from: "FM")
        XCTAssertFalse(manager.isSubmodeHidden("HIDESUB"),
                       "Removing custom submode should also remove its hidden state")
    }

    func testIsCustomSubmode() {
        let manager = ModeManager.shared
        manager.addCustomSubmode("XSUB", to: "AM")
        XCTAssertTrue(manager.isCustomSubmode("XSUB", under: "AM"))
        XCTAssertFalse(manager.isCustomSubmode("LSB", under: "SSB"))
        manager.removeCustomSubmode("XSUB", from: "AM")
    }

    // MARK: - Full round-trip with submode

    func testExportThenParseRoundTripWithSubmode() throws {
        let record = QSORecord(context: context)
        record.callsign = "BG5RT"
        record.date = TestHelper.makeDate(year: 2025, month: 6, day: 15, hour: 14, minute: 30)
        record.band = "20m"
        record.mode = "SSB"
        record.frequencyMHz = 14.250
        record.rstSent = "59"
        record.rstReceived = "59"
        record.adifFields = ["SUBMODE": "USB"]
        try context.save()

        let adifData = ADIFHelper.generateADIF(from: [record])
        let parsed = ADIFHelper.parseADIFRecords(adifData)

        XCTAssertEqual(parsed.count, 1)
        let fields = parsed[0]
        XCTAssertEqual(fields["MODE"], "SSB")
        XCTAssertEqual(fields["SUBMODE"], "USB")
        XCTAssertEqual(fields["CALL"], "BG5RT")
    }
}
