import XCTest
import CoreData
@testable import EasyQSO

final class ADIFRoundTripTests: XCTestCase {
    
    private var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        context = TestHelper.createInMemoryContext()
    }
    
    override func tearDown() {
        context = nil
        super.tearDown()
    }
    
    // MARK: - Field Extraction Tests
    
    func testExtractField() {
        let record = "<CALL:5>BG5AB<BAND:3>20m<MODE:3>FT8<EOR>"
        
        XCTAssertEqual(ADIFHelper.extractField(from: record, fieldName: "CALL"), "BG5AB")
        XCTAssertEqual(ADIFHelper.extractField(from: record, fieldName: "BAND"), "20m")
        XCTAssertEqual(ADIFHelper.extractField(from: record, fieldName: "MODE"), "FT8")
        XCTAssertNil(ADIFHelper.extractField(from: record, fieldName: "FREQ"))
    }
    
    func testExtractFieldCaseInsensitive() {
        let record = "<call:5>BG5AB<Band:3>20m"
        XCTAssertEqual(ADIFHelper.extractField(from: record, fieldName: "CALL"), "BG5AB")
        XCTAssertEqual(ADIFHelper.extractField(from: record, fieldName: "BAND"), "20m")
    }
    
    func testExtractFieldWithTypeIndicator() {
        let record = "<CALL:5:S>BG5AB<FREQ:6:N>14.074"
        let fields = ADIFHelper.extractAllFields(from: record)
        XCTAssertEqual(fields["CALL"], "BG5AB")
        XCTAssertEqual(fields["FREQ"], "14.074")
    }
    
    func testExtractFieldZeroLength() {
        let record = "<CALL:5>BG5AB<NAME:0>"
        XCTAssertNil(ADIFHelper.extractField(from: record, fieldName: "NAME"))
    }
    
    func testExtractAllFields() {
        let record = "<CALL:5>BG5AB<BAND:3>20m<MODE:3>FT8<FREQ:6>14.074<RST_SENT:2>59<RST_RCVD:2>59<CONTEST_ID:8>CQ-WW-CW"
        let fields = ADIFHelper.extractAllFields(from: record)
        
        XCTAssertEqual(fields.count, 7)
        XCTAssertEqual(fields["CALL"], "BG5AB")
        XCTAssertEqual(fields["BAND"], "20m")
        XCTAssertEqual(fields["MODE"], "FT8")
        XCTAssertEqual(fields["FREQ"], "14.074")
        XCTAssertEqual(fields["RST_SENT"], "59")
        XCTAssertEqual(fields["RST_RCVD"], "59")
        XCTAssertEqual(fields["CONTEST_ID"], "CQ-WW-CW")
    }
    
    func testExtractFieldLengthTruncation() {
        let record = "<CALL:3>BG5ABCDEF"
        XCTAssertEqual(ADIFHelper.extractField(from: record, fieldName: "CALL"), "BG5")
    }
    
    // MARK: - Parse ADIF Records
    
    func testParseMultipleRecords() {
        let adif = """
        <ADIF_VERS:5>3.1.7<EOH>
        <CALL:5>BG5AB<BAND:3>20m<MODE:3>FT8<EOR>
        <CALL:5>BG9ZZ<BAND:3>40m<MODE:2>CW<EOR>
        """
        let records = ADIFHelper.parseADIFRecords(Data(adif.utf8))
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records[0]["CALL"], "BG5AB")
        XCTAssertEqual(records[1]["CALL"], "BG9ZZ")
        XCTAssertEqual(records[1]["MODE"], "CW")
    }
    
    func testParseSkipsEmptyRecords() {
        let adif = "<EOH>\n<CALL:5>BG5AB<EOR>\n\n\n<EOR>\n"
        let records = ADIFHelper.parseADIFRecords(Data(adif.utf8))
        XCTAssertEqual(records.count, 1)
    }
    
    // MARK: - Full Round-Trip Tests
    
    func testExportThenParseRoundTrip() throws {
        let record = TestHelper.createFullQSORecord(in: context)
        try context.save()
        
        let adifData = ADIFHelper.generateADIF(from: [record])
        let parsed = ADIFHelper.parseADIFRecords(adifData)
        
        XCTAssertEqual(parsed.count, 1)
        let fields = parsed[0]
        
        XCTAssertEqual(fields["CALL"], "BG5ABC")
        XCTAssertEqual(fields["BAND"], "20m")
        XCTAssertEqual(fields["MODE"], "FT8")
        XCTAssertEqual(fields["RST_SENT"], "-10")
        XCTAssertEqual(fields["RST_RCVD"], "-12")
        XCTAssertEqual(fields["TX_PWR"], "100")
        XCTAssertEqual(fields["NAME"], "Zhang San")
        XCTAssertEqual(fields["QTH"], "Beijing")
        XCTAssertEqual(fields["GRIDSQUARE"], "OM89xb")
        XCTAssertEqual(fields["CQZ"], "24")
        XCTAssertEqual(fields["ITUZ"], "44")
        XCTAssertEqual(fields["SAT_NAME"], "SO-50")
        XCTAssertEqual(fields["COMMENT"], "Test QSO record")
        
        XCTAssertNotNil(fields["FREQ"])
        XCTAssertEqual(Double(fields["FREQ"]!)!, 14.074, accuracy: 0.001)
        
        XCTAssertNotNil(fields["FREQ_RX"])
        XCTAssertEqual(Double(fields["FREQ_RX"]!)!, 14.076, accuracy: 0.001)
        
        XCTAssertEqual(fields["SUBMODE"], "FT8")
        XCTAssertEqual(fields["CONTEST_ID"], "CQ-WW-CW")
        XCTAssertEqual(fields["POTA_REF"], "CN-0001")
        XCTAssertEqual(fields["MY_GRIDSQUARE"], "OM89xb")
        XCTAssertEqual(fields["BAND_RX"], "20m")
    }
    
    func testMultiRecordExportRoundTrip() throws {
        for i in 0..<5 {
            let r = QSORecord(context: context)
            r.callsign = "BG\(i)TST"
            r.date = TestHelper.makeDate(year: 2025, month: 6, day: 15 + i, hour: 10)
            r.band = ["20m", "40m", "80m", "15m", "10m"][i]
            r.mode = "SSB"
            r.rstSent = "59"
            r.rstReceived = "59"
            r.frequencyMHz = [14.250, 7.150, 3.750, 21.350, 28.500][i]
        }
        try context.save()
        
        let request = QSORecord.fetchRequest()
        let records = try context.fetch(request)
        
        let adifData = ADIFHelper.generateADIF(from: records)
        let parsed = ADIFHelper.parseADIFRecords(adifData)
        
        XCTAssertEqual(parsed.count, 5)
        
        let parsedCallsigns = Set(parsed.compactMap { $0["CALL"] })
        let originalCallsigns = Set(records.map(\.callsign))
        XCTAssertEqual(parsedCallsigns, originalCallsigns)
    }
    
    func testExtendedFieldsPreservedInExport() throws {
        let record = QSORecord(context: context)
        record.callsign = "BG5TEST"
        record.date = Date()
        record.band = "20m"
        record.mode = "FT8"
        record.rstSent = "-10"
        record.rstReceived = "-12"
        record.adifFields = [
            "SUBMODE": "FT8",
            "CONTEST_ID": "CQ-WW-CW",
            "QSL_SENT": "Y",
            "LOTW_QSL_SENT": "Y",
            "MY_GRIDSQUARE": "OM89xb",
            "IOTA": "AS-001",
            "POTA_REF": "CN-0001",
            "SOTA_REF": "BV/TP-001"
        ]
        try context.save()
        
        let adifData = ADIFHelper.generateADIF(from: [record])
        let parsed = ADIFHelper.parseADIFRecords(adifData)
        
        XCTAssertEqual(parsed.count, 1)
        let fields = parsed[0]
        
        XCTAssertEqual(fields["SUBMODE"], "FT8")
        XCTAssertEqual(fields["CONTEST_ID"], "CQ-WW-CW")
        XCTAssertEqual(fields["QSL_SENT"], "Y")
        XCTAssertEqual(fields["LOTW_QSL_SENT"], "Y")
        XCTAssertEqual(fields["MY_GRIDSQUARE"], "OM89xb")
        XCTAssertEqual(fields["IOTA"], "AS-001")
        XCTAssertEqual(fields["POTA_REF"], "CN-0001")
        XCTAssertEqual(fields["SOTA_REF"], "BV/TP-001")
    }
    
    func testADIFHeaderParsedCorrectly() {
        let adif = "<ADIF_VERS:5>3.1.7<PROGRAMID:6>EasQSO<PROGRAMVERSION:5>1.0.0<EOH>\n<CALL:5>BG5AB<EOR>\n"
        let records = ADIFHelper.parseADIFRecords(Data(adif.utf8))
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0]["CALL"], "BG5AB")
        XCTAssertNil(records[0]["ADIF_VERS"])
    }
}
