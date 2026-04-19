import XCTest
import CoreData
@testable import EasyQSO

final class ADXRoundTripTests: XCTestCase {

    private var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        context = TestHelper.createInMemoryContext()
    }

    override func tearDown() {
        context = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func adxString(from data: Data) -> String {
        String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - Header

    func testHeaderContainsRequiredFields() throws {
        let record = TestHelper.createFullQSORecord(in: context)
        try context.save()

        let xml = adxString(from: ADXHelper.generateADX(from: [record]))
        XCTAssertTrue(xml.hasPrefix("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
        XCTAssertTrue(xml.contains("<ADX>"))
        XCTAssertTrue(xml.contains("<ADIF_VERS>3.1.7</ADIF_VERS>"))
        XCTAssertTrue(xml.contains("<PROGRAMID>EasyQSO</PROGRAMID>"))
        XCTAssertTrue(xml.contains("<RECORDS>"))
        XCTAssertTrue(xml.contains("</ADX>"))
    }

    // MARK: - Record Count

    func testRecordCountMatches() throws {
        for i in 0..<3 {
            let r = QSORecord(context: context)
            r.callsign = "BG\(i)TST"
            r.date = TestHelper.makeDate(year: 2025, month: 6, day: 15 + i, hour: 10)
            r.band = "20m"
            r.mode = "SSB"
            r.rstSent = "59"
            r.rstReceived = "59"
        }
        try context.save()

        let request = QSORecord.fetchRequest()
        let records = try context.fetch(request)

        let parsed = ADXHelper.parseADX(ADXHelper.generateADX(from: records))
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.count, 3)
    }

    // MARK: - Round-Trip Core Fields

    func testCoreFieldsRoundTrip() throws {
        let record = TestHelper.createFullQSORecord(in: context)
        try context.save()

        let parsed = ADXHelper.parseADX(ADXHelper.generateADX(from: [record]))
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.count, 1)
        guard let fields = parsed?.first else { return }

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
        XCTAssertEqual(fields["QSO_DATE"]?.count, 8)
        XCTAssertNotNil(fields["TIME_ON"])

        XCTAssertNotNil(fields["FREQ"])
        XCTAssertEqual(Double(fields["FREQ"]!)!, 14.074, accuracy: 0.001)
        XCTAssertNotNil(fields["FREQ_RX"])
        XCTAssertEqual(Double(fields["FREQ_RX"]!)!, 14.076, accuracy: 0.001)
    }

    // MARK: - XML Escaping

    func testSpecialCharactersEscaped() throws {
        let record = QSORecord(context: context)
        record.callsign = "BG5TEST"
        record.date = Date()
        record.band = "20m"
        record.mode = "FT8"
        record.rstSent = "59"
        record.rstReceived = "59"
        record.qth = "A & B <test>"
        record.remarks = "He said \"hi\" and 'bye'"
        try context.save()

        let data = ADXHelper.generateADX(from: [record])
        let xml = adxString(from: data)

        // Raw output uses entity references, not literal characters.
        XCTAssertTrue(xml.contains("A &amp; B &lt;test&gt;"))
        XCTAssertFalse(xml.contains("A & B <test>"))
        XCTAssertTrue(xml.contains("&quot;hi&quot;"))
        XCTAssertTrue(xml.contains("&apos;bye&apos;"))

        // After parsing, the literal characters are restored.
        let parsed = ADXHelper.parseADX(data)
        XCTAssertEqual(parsed?.first?["QTH"], "A & B <test>")
        XCTAssertEqual(parsed?.first?["COMMENT"], "He said \"hi\" and 'bye'")
    }

    // MARK: - Empty Field Handling

    func testEmptyOptionalFieldsOmitted() throws {
        let record = QSORecord(context: context)
        record.callsign = "BG5MIN"
        record.date = TestHelper.makeDate(year: 2025, month: 1, day: 1, hour: 12)
        record.band = "40m"
        record.mode = "CW"
        record.rstSent = "599"
        record.rstReceived = "599"
        // name, qth, gridSquare, cqZone, ituZone, satellite, remarks left nil
        try context.save()

        let xml = adxString(from: ADXHelper.generateADX(from: [record]))
        XCTAssertFalse(xml.contains("<NAME>"))
        XCTAssertFalse(xml.contains("<QTH>"))
        XCTAssertFalse(xml.contains("<GRIDSQUARE>"))
        XCTAssertFalse(xml.contains("<SAT_NAME>"))
        XCTAssertFalse(xml.contains("<COMMENT>"))
    }

    // MARK: - Extended ADIF Fields

    func testExtendedAdifFieldsEmittedAndRoundTrip() throws {
        let record = QSORecord(context: context)
        record.callsign = "BG5EXT"
        record.date = TestHelper.makeDate(year: 2025, month: 3, day: 10, hour: 9)
        record.band = "15m"
        record.mode = "FT8"
        record.rstSent = "-10"
        record.rstReceived = "-12"
        record.adifFields = [
            "DXCC": "318",
            "SUBMODE": "FT8",
            "POTA_REF": "CN-0001",
            "QSL_SENT": "Y"
        ]
        try context.save()

        let data = ADXHelper.generateADX(from: [record])
        let xml = adxString(from: data)
        XCTAssertTrue(xml.contains("<DXCC>318</DXCC>"))
        XCTAssertTrue(xml.contains("<POTA_REF>CN-0001</POTA_REF>"))
        XCTAssertTrue(xml.contains("<SUBMODE>FT8</SUBMODE>"))
        XCTAssertTrue(xml.contains("<QSL_SENT>Y</QSL_SENT>"))

        let parsed = ADXHelper.parseADX(data)
        XCTAssertEqual(parsed?.first?["DXCC"], "318")
        XCTAssertEqual(parsed?.first?["POTA_REF"], "CN-0001")
        XCTAssertEqual(parsed?.first?["SUBMODE"], "FT8")
        XCTAssertEqual(parsed?.first?["QSL_SENT"], "Y")
    }

    // MARK: - parseADX Negative Cases

    func testParseADXReturnsNilForADIText() {
        let adi = "<ADIF_VERS:5>3.1.7<EOH>\n<CALL:5>BG5AB<EOR>\n"
        XCTAssertNil(ADXHelper.parseADX(Data(adi.utf8)))
    }

    func testParseADXReturnsNilForMalformedXML() {
        let bad = "<?xml version=\"1.0\"?><ADX><RECORDS><RECORD><CALL>X"
        XCTAssertNil(ADXHelper.parseADX(Data(bad.utf8)))
    }

    func testParseADXReturnsEmptyForADXWithNoRecords() {
        let empty = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ADX>
          <HEADER><ADIF_VERS>3.1.7</ADIF_VERS></HEADER>
          <RECORDS></RECORDS>
        </ADX>
        """
        let parsed = ADXHelper.parseADX(Data(empty.utf8))
        XCTAssertEqual(parsed, [])
    }

    // MARK: - convertADXToADI

    func testConvertADXToADIFeedsExistingADIFParser() throws {
        let record = TestHelper.createFullQSORecord(in: context)
        try context.save()

        let adxData = ADXHelper.generateADX(from: [record])
        let adiData = ADXHelper.convertADXToADI(adxData)
        XCTAssertNotNil(adiData)

        let parsed = ADIFHelper.parseADIFRecords(adiData!)
        XCTAssertEqual(parsed.count, 1)
        let fields = parsed[0]

        XCTAssertEqual(fields["CALL"], "BG5ABC")
        XCTAssertEqual(fields["BAND"], "20m")
        XCTAssertEqual(fields["MODE"], "FT8")
        XCTAssertEqual(fields["NAME"], "Zhang San")
        XCTAssertEqual(fields["QTH"], "Beijing")
        XCTAssertEqual(fields["GRIDSQUARE"], "OM89xb")
        XCTAssertEqual(fields["SAT_NAME"], "SO-50")
        XCTAssertEqual(fields["COMMENT"], "Test QSO record")
        XCTAssertEqual(fields["SUBMODE"], "FT8")
        XCTAssertEqual(fields["POTA_REF"], "CN-0001")
        XCTAssertEqual(fields["QSO_DATE"]?.count, 8)
    }

    func testConvertADXToADIPreservesUTF8ByteCounts() throws {
        let record = QSORecord(context: context)
        record.callsign = "BG5UTF"
        record.date = TestHelper.makeDate(year: 2025, month: 1, day: 1, hour: 12)
        record.band = "20m"
        record.mode = "FT8"
        record.rstSent = "59"
        record.rstReceived = "59"
        record.qth = "北京"   // 6 UTF-8 bytes, 2 characters
        try context.save()

        let adxData = ADXHelper.generateADX(from: [record])
        let adiData = ADXHelper.convertADXToADI(adxData)
        XCTAssertNotNil(adiData)

        // The re-emitted ADI must use UTF-8 byte counts so ADIFHelper's
        // length-prefixed extractor returns the full string.
        let parsed = ADIFHelper.parseADIFRecords(adiData!)
        XCTAssertEqual(parsed.first?["QTH"], "北京")
    }

    // MARK: - APP / USERDEF graceful handling

    func testParseADXReadsAPPFieldnameAttribute() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ADX>
          <HEADER><ADIF_VERS>3.1.7</ADIF_VERS></HEADER>
          <RECORDS>
            <RECORD>
              <CALL>BG5APP</CALL>
              <BAND>20m</BAND>
              <MODE>FT8</MODE>
              <APP PROGRAMID="LOG4OM" FIELDNAME="MY_FIELD" TYPE="S">customvalue</APP>
            </RECORD>
          </RECORDS>
        </ADX>
        """
        let parsed = ADXHelper.parseADX(Data(xml.utf8))
        XCTAssertEqual(parsed?.first?["CALL"], "BG5APP")
        XCTAssertEqual(parsed?.first?["MY_FIELD"], "customvalue")
    }
}
