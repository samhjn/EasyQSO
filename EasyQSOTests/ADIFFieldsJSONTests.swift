import XCTest
import CoreData
@testable import EasyQSO

final class ADIFFieldsJSONTests: XCTestCase {
    
    private var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        context = TestHelper.createInMemoryContext()
    }
    
    override func tearDown() {
        context = nil
        super.tearDown()
    }
    
    private func makeRecord() -> QSORecord {
        let r = QSORecord(context: context)
        r.callsign = "TEST"
        r.date = Date()
        r.band = "20m"
        r.mode = "FT8"
        r.rstSent = "59"
        r.rstReceived = "59"
        return r
    }
    
    func testBasicRoundTrip() throws {
        let record = makeRecord()
        let fields: [String: String] = [
            "SUBMODE": "FT8",
            "CONTEST_ID": "CQ-WW-CW",
            "POTA_REF": "CN-0001"
        ]
        record.adifFields = fields
        try context.save()
        
        context.refresh(record, mergeChanges: false)
        XCTAssertEqual(record.adifFields, fields)
    }
    
    func testEmptyValuesStripped() {
        let record = makeRecord()
        record.adifFields = [
            "SUBMODE": "FT8",
            "EMPTY_FIELD": "",
            "ANOTHER_EMPTY": ""
        ]
        
        let result = record.adifFields
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result["SUBMODE"], "FT8")
        XCTAssertNil(result["EMPTY_FIELD"])
    }
    
    func testAllEmptyFieldsClearsData() {
        let record = makeRecord()
        record.adifFields = ["A": "", "B": ""]
        XCTAssertNil(record.adifFieldsData)
        XCTAssertTrue(record.adifFields.isEmpty)
    }
    
    func testEmptyDictionaryClearsData() {
        let record = makeRecord()
        record.adifFields = ["SUBMODE": "FT8"]
        XCTAssertNotNil(record.adifFieldsData)
        
        record.adifFields = [:]
        XCTAssertNil(record.adifFieldsData)
    }
    
    func testLargeNumberOfExtendedFields() throws {
        let record = makeRecord()
        var fields = [String: String]()
        for i in 0..<60 {
            fields["CUSTOM_FIELD_\(i)"] = "value_\(i)"
        }
        record.adifFields = fields
        try context.save()
        
        context.refresh(record, mergeChanges: false)
        let recovered = record.adifFields
        XCTAssertEqual(recovered.count, 60)
        for i in 0..<60 {
            XCTAssertEqual(recovered["CUSTOM_FIELD_\(i)"], "value_\(i)")
        }
    }
    
    func testSpecialCharacters() throws {
        let record = makeRecord()
        let fields: [String: String] = [
            "NOTES": "This has special chars: <>&\"'",
            "QTH_EXTRA": "北京市朝阳区",
            "COMMENT_EXT": "Line1\nLine2\nLine3"
        ]
        record.adifFields = fields
        try context.save()
        
        context.refresh(record, mergeChanges: false)
        XCTAssertEqual(record.adifFields["NOTES"], "This has special chars: <>&\"'")
        XCTAssertEqual(record.adifFields["QTH_EXTRA"], "北京市朝阳区")
        XCTAssertEqual(record.adifFields["COMMENT_EXT"], "Line1\nLine2\nLine3")
    }
    
    func testFieldUpdatePreservesOtherFields() throws {
        let record = makeRecord()
        record.adifFields = [
            "SUBMODE": "FT8",
            "CONTEST_ID": "CQWW",
            "POTA_REF": "CN-0001"
        ]
        try context.save()
        
        var fields = record.adifFields
        fields["SOTA_REF"] = "BV/TP-001"
        fields.removeValue(forKey: "CONTEST_ID")
        record.adifFields = fields
        try context.save()
        
        context.refresh(record, mergeChanges: false)
        let result = record.adifFields
        XCTAssertEqual(result["SUBMODE"], "FT8")
        XCTAssertEqual(result["POTA_REF"], "CN-0001")
        XCTAssertEqual(result["SOTA_REF"], "BV/TP-001")
        XCTAssertNil(result["CONTEST_ID"])
    }
    
    func testKnownADIFExtendedTags() throws {
        let record = makeRecord()
        let extendedTags: [String: String] = [
            "TIME_OFF": "1430",
            "QSO_DATE_OFF": "20250615",
            "BAND_RX": "20m",
            "MY_GRIDSQUARE": "OM89xb",
            "STATION_CALLSIGN": "BG5ABC",
            "OPERATOR": "BG5ABC",
            "MY_CQ_ZONE": "24",
            "MY_ITU_ZONE": "44",
            "IOTA": "AS-001",
            "QSL_SENT": "Y",
            "QSL_RCVD": "N",
            "LOTW_QSL_SENT": "Y"
        ]
        record.adifFields = extendedTags
        try context.save()
        
        context.refresh(record, mergeChanges: false)
        let recovered = record.adifFields
        for (key, value) in extendedTags {
            XCTAssertEqual(recovered[key], value, "Extended tag \(key) mismatch")
        }
    }
}
