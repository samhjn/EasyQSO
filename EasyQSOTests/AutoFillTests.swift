import XCTest
import CoreData
@testable import EasyQSO

final class AutoFillTests: XCTestCase {
    
    private var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        context = TestHelper.createInMemoryContext()
    }
    
    override func tearDown() {
        context = nil
        super.tearDown()
    }
    
    // MARK: - lastOwnQTHInfo: priority 1 — Band + Mode match
    
    func testOwnQTH_BandAndModeMatch() throws {
        let r1 = QSORecord(context: context)
        r1.callsign = "BG1AAA"
        r1.date = TestHelper.makeDate(year: 2025, month: 1, day: 1)
        r1.band = "20m"
        r1.mode = "SSB"
        r1.rstSent = "59"
        r1.rstReceived = "59"
        r1.adifFields = ["MY_CITY": "Beijing", "MY_GRIDSQUARE": "OM89xb"]
        
        let r2 = QSORecord(context: context)
        r2.callsign = "BG2BBB"
        r2.date = TestHelper.makeDate(year: 2025, month: 1, day: 2)
        r2.band = "40m"
        r2.mode = "CW"
        r2.rstSent = "599"
        r2.rstReceived = "599"
        r2.adifFields = ["MY_CITY": "Shanghai", "MY_GRIDSQUARE": "PM01ab"]
        
        try context.save()
        
        let result = QSORecord.lastOwnQTHInfo(band: "20m", mode: "SSB", context: context)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.myCity, "Beijing")
        XCTAssertEqual(result?.myGridSquare, "OM89xb")
        
        let result2 = QSORecord.lastOwnQTHInfo(band: "40m", mode: "CW", context: context)
        XCTAssertNotNil(result2)
        XCTAssertEqual(result2?.myCity, "Shanghai")
    }
    
    // MARK: - lastOwnQTHInfo: priority 2 — Band-only match
    
    func testOwnQTH_BandOnlyFallback() throws {
        let r1 = QSORecord(context: context)
        r1.callsign = "BG1AAA"
        r1.date = TestHelper.makeDate(year: 2025, month: 1, day: 1)
        r1.band = "20m"
        r1.mode = "CW"
        r1.rstSent = "599"
        r1.rstReceived = "599"
        r1.adifFields = ["MY_CITY": "Shenzhen", "MY_GRIDSQUARE": "OL72ab"]
        
        try context.save()
        
        // Query 20m SSB — no exact band+mode match, falls back to band-only (20m CW)
        let result = QSORecord.lastOwnQTHInfo(band: "20m", mode: "SSB", context: context)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.myCity, "Shenzhen")
    }
    
    // MARK: - lastOwnQTHInfo: priority 3 — Any record fallback
    
    func testOwnQTH_AnyRecordFallback() throws {
        let r1 = QSORecord(context: context)
        r1.callsign = "BG1AAA"
        r1.date = TestHelper.makeDate(year: 2025, month: 1, day: 1)
        r1.band = "40m"
        r1.mode = "CW"
        r1.rstSent = "599"
        r1.rstReceived = "599"
        r1.adifFields = ["MY_CITY": "Guangzhou"]
        
        try context.save()
        
        // Query 20m SSB — no band match, no band+mode match, falls back to any
        let result = QSORecord.lastOwnQTHInfo(band: "20m", mode: "SSB", context: context)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.myCity, "Guangzhou")
    }
    
    // MARK: - lastOwnQTHInfo: priority 4 — nil (no records)
    
    func testOwnQTH_NoRecords() throws {
        let result = QSORecord.lastOwnQTHInfo(band: "20m", mode: "SSB", context: context)
        XCTAssertNil(result)
    }
    
    func testOwnQTH_RecordsWithoutMyCity() throws {
        let r1 = QSORecord(context: context)
        r1.callsign = "BG1AAA"
        r1.date = Date()
        r1.band = "20m"
        r1.mode = "SSB"
        r1.rstSent = "59"
        r1.rstReceived = "59"
        // No MY_CITY in adifFields
        
        try context.save()
        
        let result = QSORecord.lastOwnQTHInfo(band: "20m", mode: "SSB", context: context)
        XCTAssertNil(result)
    }
    
    // MARK: - lastOwnQTHInfo: picks most recent record
    
    func testOwnQTH_PicksMostRecent() throws {
        let older = QSORecord(context: context)
        older.callsign = "BG1AAA"
        older.date = TestHelper.makeDate(year: 2025, month: 1, day: 1)
        older.band = "20m"
        older.mode = "SSB"
        older.rstSent = "59"
        older.rstReceived = "59"
        older.adifFields = ["MY_CITY": "OldCity"]
        
        let newer = QSORecord(context: context)
        newer.callsign = "BG2BBB"
        newer.date = TestHelper.makeDate(year: 2025, month: 6, day: 15)
        newer.band = "20m"
        newer.mode = "SSB"
        newer.rstSent = "59"
        newer.rstReceived = "59"
        newer.adifFields = ["MY_CITY": "NewCity", "MY_CQ_ZONE": "24"]
        
        try context.save()
        
        let result = QSORecord.lastOwnQTHInfo(band: "20m", mode: "SSB", context: context)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.myCity, "NewCity")
        XCTAssertEqual(result?.myCQZone, "24")
    }
    
    // MARK: - Priority order: exact match beats band-only
    
    func testOwnQTH_ExactMatchBeats_BandOnly() throws {
        let bandOnly = QSORecord(context: context)
        bandOnly.callsign = "BG1AAA"
        bandOnly.date = TestHelper.makeDate(year: 2025, month: 6, day: 20)
        bandOnly.band = "20m"
        bandOnly.mode = "CW"
        bandOnly.rstSent = "599"
        bandOnly.rstReceived = "599"
        bandOnly.adifFields = ["MY_CITY": "BandOnlyCity"]
        
        let exactMatch = QSORecord(context: context)
        exactMatch.callsign = "BG2BBB"
        exactMatch.date = TestHelper.makeDate(year: 2025, month: 1, day: 1)
        exactMatch.band = "20m"
        exactMatch.mode = "SSB"
        exactMatch.rstSent = "59"
        exactMatch.rstReceived = "59"
        exactMatch.adifFields = ["MY_CITY": "ExactMatchCity"]
        
        try context.save()
        
        // Even though bandOnly is newer, exact band+mode match should be preferred
        let result = QSORecord.lastOwnQTHInfo(band: "20m", mode: "SSB", context: context)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.myCity, "ExactMatchCity")
    }
    
    // MARK: - All fields are returned
    
    func testOwnQTH_AllFieldsReturned() throws {
        let r = QSORecord(context: context)
        r.callsign = "BG1AAA"
        r.date = Date()
        r.band = "20m"
        r.mode = "SSB"
        r.rstSent = "59"
        r.rstReceived = "59"
        r.adifFields = [
            "MY_CITY": "Beijing",
            "MY_GRIDSQUARE": "OM89xb",
            "MY_CQ_ZONE": "24",
            "MY_ITU_ZONE": "44",
            "MY_LAT": "N039 54.252",
            "MY_LON": "E116 24.444"
        ]
        
        try context.save()
        
        let result = QSORecord.lastOwnQTHInfo(band: "20m", mode: "SSB", context: context)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.myCity, "Beijing")
        XCTAssertEqual(result?.myGridSquare, "OM89xb")
        XCTAssertEqual(result?.myCQZone, "24")
        XCTAssertEqual(result?.myITUZone, "44")
        XCTAssertEqual(result?.myLat, "N039 54.252")
        XCTAssertEqual(result?.myLon, "E116 24.444")
    }
    
    // MARK: - Partial MY_CITY: skips records without MY_CITY
    
    func testOwnQTH_SkipsRecordsWithoutMyCity() throws {
        let noCity = QSORecord(context: context)
        noCity.callsign = "BG1AAA"
        noCity.date = TestHelper.makeDate(year: 2025, month: 6, day: 20)
        noCity.band = "20m"
        noCity.mode = "SSB"
        noCity.rstSent = "59"
        noCity.rstReceived = "59"
        noCity.adifFields = ["MY_GRIDSQUARE": "OM89xb"]
        
        let withCity = QSORecord(context: context)
        withCity.callsign = "BG2BBB"
        withCity.date = TestHelper.makeDate(year: 2025, month: 1, day: 1)
        withCity.band = "20m"
        withCity.mode = "SSB"
        withCity.rstSent = "59"
        withCity.rstReceived = "59"
        withCity.adifFields = ["MY_CITY": "Chengdu"]
        
        try context.save()
        
        let result = QSORecord.lastOwnQTHInfo(band: "20m", mode: "SSB", context: context)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.myCity, "Chengdu")
    }
    
    // MARK: - AutoFillManager defaults
    
    func testAutoFillManagerDefaults() {
        let manager = AutoFillManager.shared
        XCTAssertTrue(manager.autoFillFrequencyAndMode)
        XCTAssertTrue(manager.autoFillOwnQTH)
    }
    
    // MARK: - Multiple bands with different QTH
    
    func testOwnQTH_DifferentBandsDifferentQTH() throws {
        let r1 = QSORecord(context: context)
        r1.callsign = "BG1AAA"
        r1.date = TestHelper.makeDate(year: 2025, month: 6, day: 1)
        r1.band = "20m"
        r1.mode = "SSB"
        r1.rstSent = "59"
        r1.rstReceived = "59"
        r1.adifFields = ["MY_CITY": "HomeQTH_20m"]
        
        let r2 = QSORecord(context: context)
        r2.callsign = "BG2BBB"
        r2.date = TestHelper.makeDate(year: 2025, month: 6, day: 2)
        r2.band = "2m"
        r2.mode = "FM"
        r2.rstSent = "59"
        r2.rstReceived = "59"
        r2.adifFields = ["MY_CITY": "PortableQTH_2m"]
        
        try context.save()
        
        let result20m = QSORecord.lastOwnQTHInfo(band: "20m", mode: "SSB", context: context)
        XCTAssertEqual(result20m?.myCity, "HomeQTH_20m")
        
        let result2m = QSORecord.lastOwnQTHInfo(band: "2m", mode: "FM", context: context)
        XCTAssertEqual(result2m?.myCity, "PortableQTH_2m")
    }
    
    // MARK: - Empty MY_CITY string is treated as absent
    
    func testOwnQTH_EmptyMyCityTreatedAsAbsent() throws {
        let r1 = QSORecord(context: context)
        r1.callsign = "BG1AAA"
        r1.date = TestHelper.makeDate(year: 2025, month: 6, day: 20)
        r1.band = "20m"
        r1.mode = "SSB"
        r1.rstSent = "59"
        r1.rstReceived = "59"
        r1.adifFields = ["MY_CITY": ""]
        
        try context.save()
        
        // Empty MY_CITY should not be considered a valid own QTH
        let result = QSORecord.lastOwnQTHInfo(band: "20m", mode: "SSB", context: context)
        XCTAssertNil(result)
    }
}
