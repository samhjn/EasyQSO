import XCTest
import CoreData
@testable import EasyQSO

final class CorePropertyMappingTests: XCTestCase {
    
    private var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        context = TestHelper.createInMemoryContext()
    }
    
    override func tearDown() {
        context = nil
        super.tearDown()
    }
    
    func testCoreFieldsHaveCoreProperty() {
        let coreFields = ADIFFields.coreFields
        XCTAssertFalse(coreFields.isEmpty, "Should have core fields defined")
        
        for field in coreFields {
            XCTAssertNotNil(field.coreProperty,
                            "Core field \(field.id) should have a coreProperty mapping")
        }
    }
    
    func testExtendedFieldsHaveNoCoreProperty() {
        let extendedFields = ADIFFields.extendedFields
        XCTAssertFalse(extendedFields.isEmpty, "Should have extended fields defined")
        
        for field in extendedFields {
            XCTAssertNil(field.coreProperty,
                         "Extended field \(field.id) should NOT have a coreProperty mapping")
        }
    }
    
    func testSetAndGetViaAdifValue() {
        let record = TestHelper.createFullQSORecord(in: context)
        
        let coreTagsAndExpected: [(tag: String, expected: String)] = [
            ("CALL", "BG5ABC"),
            ("BAND", "20m"),
            ("MODE", "FT8"),
            ("RST_SENT", "-10"),
            ("RST_RCVD", "-12"),
            ("TX_PWR", "100"),
            ("NAME", "Zhang San"),
            ("QTH", "Beijing"),
            ("GRIDSQUARE", "OM89xb"),
            ("CQZ", "24"),
            ("ITUZ", "44"),
            ("SAT_NAME", "SO-50"),
            ("COMMENT", "Test QSO record"),
        ]
        
        for (tag, expected) in coreTagsAndExpected {
            let value = record.adifValue(for: tag)
            XCTAssertEqual(value, expected, "adifValue(for: \"\(tag)\") mismatch")
        }
    }
    
    func testSetAdifValueUpdatesCoreProperty() {
        let record = TestHelper.createFullQSORecord(in: context)
        
        record.setAdifValue("BG9ZZZ", for: "CALL")
        XCTAssertEqual(record.callsign, "BG9ZZZ")
        
        record.setAdifValue("40m", for: "BAND")
        XCTAssertEqual(record.band, "40m")
        
        record.setAdifValue("New Name", for: "NAME")
        XCTAssertEqual(record.name, "New Name")
        
        record.setAdifValue(nil, for: "NAME")
        XCTAssertNil(record.name)
    }
    
    func testCoreTagsNotLeakedToJSON() throws {
        let record = TestHelper.createFullQSORecord(in: context)
        try context.save()
        
        let jsonFields = record.adifFields
        let coreTags = ["CALL", "BAND", "MODE", "FREQ", "RST_SENT", "RST_RCVD",
                        "TX_PWR", "NAME", "QTH", "GRIDSQUARE", "CQZ", "ITUZ",
                        "SAT_NAME", "COMMENT", "LAT", "LON"]
        
        for tag in coreTags {
            XCTAssertNil(jsonFields[tag],
                         "Core tag \(tag) should NOT appear in adifFields JSON")
        }
    }
    
    func testAllAdifValuesIncludesBothCoreAndExtended() {
        let record = TestHelper.createFullQSORecord(in: context)
        let allValues = record.allAdifValues()
        
        XCTAssertEqual(allValues["CALL"], "BG5ABC")
        XCTAssertEqual(allValues["BAND"], "20m")
        XCTAssertEqual(allValues["MODE"], "FT8")
        XCTAssertEqual(allValues["RST_SENT"], "-10")
        
        XCTAssertEqual(allValues["SUBMODE"], "FT8")
        XCTAssertEqual(allValues["CONTEST_ID"], "CQ-WW-CW")
        XCTAssertEqual(allValues["POTA_REF"], "CN-0001")
    }
    
    func testSetAdifValueForExtendedField() {
        let record = TestHelper.createFullQSORecord(in: context)
        
        record.setAdifValue("NEW-CONTEST", for: "CONTEST_ID")
        XCTAssertEqual(record.adifFields["CONTEST_ID"], "NEW-CONTEST")
        
        record.setAdifValue("", for: "CONTEST_ID")
        XCTAssertNil(record.adifFields["CONTEST_ID"])
    }
    
    func testSetAdifValueForUnknownTag() {
        let record = TestHelper.createFullQSORecord(in: context)
        
        record.setAdifValue("custom-value", for: "MY_CUSTOM_TAG")
        XCTAssertEqual(record.adifFields["MY_CUSTOM_TAG"], "custom-value")
    }
    
    func testFrequencyCoreMappingViaAdifValue() {
        let record = TestHelper.createFullQSORecord(in: context)
        
        let freqValue = record.adifValue(for: "FREQ")
        XCTAssertNotNil(freqValue)
        XCTAssertEqual(Double(freqValue!)!, 14.074, accuracy: 0.001)
        
        let rxFreqValue = record.adifValue(for: "FREQ_RX")
        XCTAssertNotNil(rxFreqValue)
        XCTAssertEqual(Double(rxFreqValue!)!, 14.076, accuracy: 0.001)
    }
    
    func testCoordinateCoreMappingViaAdifValue() {
        let record = TestHelper.createFullQSORecord(in: context)
        
        let lat = record.adifValue(for: "LAT")
        XCTAssertNotNil(lat)
        XCTAssertEqual(Double(lat!)!, 39.9042, accuracy: 0.001)
        
        let lon = record.adifValue(for: "LON")
        XCTAssertNotNil(lon)
        XCTAssertEqual(Double(lon!)!, 116.4074, accuracy: 0.001)
    }
}
