import XCTest
import CoreData
@testable import EasyQSO

final class BandManagerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "BandManagerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testCompleteADIF318Enumeration() {
        // ADIF 3.1.8 section III.B.4, including experimental and submillimetre bands.
        let expected = "2190m 630m 560m 160m 80m 60m 40m 30m 20m 17m 15m 12m 10m 8m 6m 5m 4m 2m 1.25m 70cm 33cm 23cm 13cm 9cm 6cm 3cm 1.25cm 6mm 4mm 2.5mm 2mm 1mm submm"
        XCTAssertEqual(BandManager.allBands, expected.split(separator: " ").map(String.init))
    }

    func testADIF318FrequencyBoundaries() {
        // Independent reference values from the ADIF table, in MHz.
        let expected: [(String, Double, Double)] = [
            ("2190m", 0.1357, 0.1378), ("630m", 0.472, 0.479),
            ("560m", 0.501, 0.504), ("160m", 1.8, 2.0),
            ("80m", 3.5, 4.0), ("60m", 5.06, 5.45),
            ("40m", 7.0, 7.3), ("30m", 10.1, 10.15),
            ("20m", 14.0, 14.35), ("17m", 18.068, 18.168),
            ("15m", 21.0, 21.45), ("12m", 24.890, 24.99),
            ("10m", 28.0, 29.7), ("8m", 40, 45),
            ("6m", 50, 54), ("5m", 54.000001, 69.9),
            ("4m", 70, 71), ("2m", 144, 148),
            ("1.25m", 222, 225), ("70cm", 420, 450),
            ("33cm", 902, 928), ("23cm", 1240, 1300),
            ("13cm", 2300, 2450), ("9cm", 3300, 3500),
            ("6cm", 5650, 5925), ("3cm", 10000, 10500),
            ("1.25cm", 24000, 24250), ("6mm", 47000, 47200),
            ("4mm", 75500, 81000), ("2.5mm", 119980, 123000),
            ("2mm", 134000, 149000), ("1mm", 241000, 250000),
            ("submm", 300000, 7500000)
        ]
        for (name, lower, upper) in expected {
            XCTAssertEqual(QSORecord.bandForFrequency(lower), name, "Lower bound: \(name)")
            XCTAssertEqual(QSORecord.bandForFrequency(upper), name, "Upper bound: \(name)")
            XCTAssertEqual(QSORecord.bandForFrequency((lower + upper) / 2), name)
            XCTAssertNotEqual(QSORecord.bandForFrequency(lower - 0.000001), name)
            XCTAssertNotEqual(QSORecord.bandForFrequency(upper + 0.000001), name)
        }
        for gap in [0.138, 0.5, 5.5, 49, 54.0000005, 69.95, 143, 250001, 299999, 7500001] {
            XCTAssertNil(QSORecord.bandForFrequency(gap), "Gap: \(gap)")
        }
        XCTAssertNil(QSORecord.bandForFrequency(0))
        XCTAssertNil(QSORecord.bandForFrequency(-1))
        XCTAssertNil(QSORecord.bandForFrequency(.nan))
        XCTAssertNil(QSORecord.bandForFrequency(.infinity))
    }

    func testDefaultCommonBandsPreservePreviousPicker() {
        let manager = BandManager(defaults: defaults)
        XCTAssertEqual(manager.commonBands, [
            "160m", "80m", "40m", "30m", "20m", "17m",
            "15m", "12m", "10m", "6m", "2m", "70cm"
        ])
        assertCompleteMenu(manager)
    }

    func testCommonBandChangesPersistAndOnlyMoveMenuItems() {
        let manager = BandManager(defaults: defaults)
        manager.setCommon(false, for: "20m")
        manager.setCommon(true, for: "23CM")
        manager.setCommon(true, for: "23cm")
        manager.setCommon(true, for: "unknown")
        XCTAssertFalse(manager.isCommon("20m"))
        XCTAssertTrue(manager.otherBands.contains("20m"))
        XCTAssertTrue(manager.isCommon("23cm"))
        XCTAssertFalse(manager.otherBands.contains("23cm"))
        XCTAssertEqual(manager.commonBands.filter { $0 == "23cm" }.count, 1)
        XCTAssertEqual(BandManager(defaults: defaults).commonBands, manager.commonBands)
        assertCompleteMenu(manager)
        // Common-band preferences never limit frequency inference.
        XCTAssertEqual(QSORecord.bandForFrequency(14.074), "20m")
    }

    func testAllAndNoCommonBandsRemainUsableAfterReload() {
        let manager = BandManager(defaults: defaults)
        for band in BandManager.allBands { manager.setCommon(false, for: band) }
        let empty = BandManager(defaults: defaults)
        XCTAssertTrue(empty.commonBands.isEmpty)
        XCTAssertEqual(empty.otherBands, BandManager.allBands)
        assertCompleteMenu(empty)

        for band in BandManager.allBands { manager.setCommon(true, for: band) }
        let full = BandManager(defaults: defaults)
        XCTAssertEqual(full.commonBands, BandManager.allBands)
        XCTAssertTrue(full.otherBands.isEmpty)
        assertCompleteMenu(full)
    }

    func testStoredPreferencesAreNormalizedAndResettable() {
        defaults.set(["23CM", "20m", "20M", "unknown"], forKey: BandManager.commonBandsKey)
        let manager = BandManager(defaults: defaults)
        XCTAssertEqual(manager.commonBands, ["20m", "23cm"])
        assertCompleteMenu(manager)
        manager.resetCommonBands()
        XCTAssertEqual(manager.commonBands, BandManager.defaultCommonBands)
        XCTAssertEqual(BandManager(defaults: defaults).commonBands, BandManager.defaultCommonBands)
    }

    func testEveryBandSurvivesStorageAndADIADXRoundTrips() throws {
        let context = TestHelper.createInMemoryContext()
        let records = BandManager.bands.map { band -> QSORecord in
            let record = TestHelper.createFullQSORecord(in: context)
            record.band = band.name
            record.frequencyMHz = band.rangeMHz.lowerBound
            record.rxFrequencyMHz = band.rangeMHz.upperBound
            record.adifFields = ["BAND_RX": band.name]
            return record
        }
        try context.save()
        for record in records { context.refresh(record, mergeChanges: false) }

        let adi = ADIFHelper.parseADIFRecords(ADIFHelper.generateADIF(from: records))
        let adx = try XCTUnwrap(ADXHelper.parseADX(ADXHelper.generateADX(from: records)))
        for parsed in [adi, adx] {
            XCTAssertEqual(parsed.count, BandManager.bands.count)
            for (fields, band) in zip(parsed, BandManager.bands) {
                XCTAssertEqual(fields["BAND"], band.name)
                XCTAssertEqual(fields["BAND_RX"], band.name)
                let tx = try XCTUnwrap(fields["FREQ"].flatMap(Double.init))
                let rx = try XCTUnwrap(fields["FREQ_RX"].flatMap(Double.init))
                XCTAssertEqual(tx, band.rangeMHz.lowerBound, accuracy: 0.000001)
                XCTAssertEqual(rx, band.rangeMHz.upperBound, accuracy: 0.000001)
            }
        }
    }

    private func assertCompleteMenu(_ manager: BandManager, file: StaticString = #filePath, line: UInt = #line) {
        let common = Set(manager.commonBands)
        let other = Set(manager.otherBands)
        XCTAssertTrue(common.isDisjoint(with: other), file: file, line: line)
        XCTAssertEqual(common.union(other), Set(BandManager.allBands), file: file, line: line)
    }
}
