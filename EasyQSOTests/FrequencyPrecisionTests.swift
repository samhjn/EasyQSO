import XCTest
import CoreData
@testable import EasyQSO

final class FrequencyPrecisionTests: XCTestCase {
    
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
    
    func testMHzToHzRoundTrip() {
        let record = makeRecord()
        let testFreqs: [Double] = [14.074, 7.074, 3.573, 144.174, 432.065, 0.1357, 28.074]
        
        for freq in testFreqs {
            record.frequencyMHz = freq
            let recovered = record.frequencyMHz
            XCTAssertEqual(recovered, freq, accuracy: 0.000001,
                           "Frequency \(freq) MHz round-trip failed: got \(recovered)")
        }
    }
    
    func testHzStoragePrecision() {
        let record = makeRecord()
        record.frequencyMHz = 14.074
        XCTAssertEqual(record.frequencyHz, 14_074_000)
        
        record.frequencyMHz = 432.065
        XCTAssertEqual(record.frequencyHz, 432_065_000)
    }
    
    func testRxFrequencyRoundTrip() {
        let record = makeRecord()
        record.rxFrequencyMHz = 14.076
        XCTAssertEqual(record.rxFrequencyMHz, 14.076, accuracy: 0.000001)
        XCTAssertEqual(record.rxFrequencyHz, 14_076_000)
    }
    
    func testZeroFrequency() {
        let record = makeRecord()
        record.frequencyMHz = 0.0
        XCTAssertEqual(record.frequencyHz, 0)
        XCTAssertEqual(record.frequencyMHz, 0.0)
    }
    
    func testBoundaryFrequencies() {
        let record = makeRecord()
        
        record.frequencyMHz = 0.1
        XCTAssertEqual(record.frequencyMHz, 0.1, accuracy: 0.000001)
        
        record.frequencyMHz = 5900.0
        XCTAssertEqual(record.frequencyMHz, 5900.0, accuracy: 0.001)
    }
    
    func testFrequencyPersistsThroughSave() throws {
        let record = makeRecord()
        record.frequencyMHz = 14.074123
        try context.save()
        
        context.refresh(record, mergeChanges: false)
        XCTAssertEqual(record.frequencyMHz, 14.074123, accuracy: 0.000001)
    }
    
    func testFrequencyInHzAccessor() {
        let record = makeRecord()
        record.frequencyInHz = 14_074_000
        XCTAssertEqual(record.frequencyMHz, 14.074, accuracy: 0.000001)
        XCTAssertEqual(record.frequencyInHz, 14_074_000)
    }
    
    func testFormatFreqForADIF() {
        XCTAssertEqual(ADIFHelper.formatFreqForADIF(14.074), "14.074")
        XCTAssertEqual(ADIFHelper.formatFreqForADIF(7.0), "7")
        XCTAssertEqual(ADIFHelper.formatFreqForADIF(144.174), "144.174")
        XCTAssertEqual(ADIFHelper.formatFreqForADIF(432.065000), "432.065")
        XCTAssertEqual(ADIFHelper.formatFreqForADIF(14.074123), "14.074123")
    }
}
