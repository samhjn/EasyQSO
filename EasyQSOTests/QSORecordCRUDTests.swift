import XCTest
import CoreData
@testable import EasyQSO

final class QSORecordCRUDTests: XCTestCase {
    
    private var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        context = TestHelper.createInMemoryContext()
    }
    
    override func tearDown() {
        context = nil
        super.tearDown()
    }
    
    func testCreateAndFetchAllCoreFields() throws {
        let _ = TestHelper.createFullQSORecord(in: context)
        try context.save()
        
        let request = QSORecord.fetchRequest()
        let fetched = try context.fetch(request)
        XCTAssertEqual(fetched.count, 1)
        
        let r = fetched[0]
        XCTAssertEqual(r.callsign, "BG5ABC")
        XCTAssertEqual(r.band, "20m")
        XCTAssertEqual(r.mode, "FT8")
        XCTAssertEqual(r.frequencyMHz, 14.074, accuracy: 0.0001)
        XCTAssertEqual(r.rxFrequencyMHz, 14.076, accuracy: 0.0001)
        XCTAssertEqual(r.txPower, "100")
        XCTAssertEqual(r.rstSent, "-10")
        XCTAssertEqual(r.rstReceived, "-12")
        XCTAssertEqual(r.name, "Zhang San")
        XCTAssertEqual(r.qth, "Beijing")
        XCTAssertEqual(r.gridSquare, "OM89xb")
        XCTAssertEqual(r.cqZone, "24")
        XCTAssertEqual(r.ituZone, "44")
        XCTAssertEqual(r.satellite, "SO-50")
        XCTAssertEqual(r.remarks, "Test QSO record")
        XCTAssertEqual(r.latitude, 39.9042, accuracy: 0.0001)
        XCTAssertEqual(r.longitude, 116.4074, accuracy: 0.0001)
        
        XCTAssertEqual(Calendar.current.component(.year, from: r.date), 2025)
    }
    
    func testOptionalFieldsNil() throws {
        let record = QSORecord(context: context)
        record.callsign = "BG1XYZ"
        record.date = Date()
        record.band = "40m"
        record.mode = "CW"
        record.rstSent = "599"
        record.rstReceived = "599"
        try context.save()
        
        let request = QSORecord.fetchRequest()
        let fetched = try context.fetch(request)
        let r = fetched[0]
        
        XCTAssertNil(r.txPower)
        XCTAssertNil(r.name)
        XCTAssertNil(r.qth)
        XCTAssertNil(r.gridSquare)
        XCTAssertNil(r.cqZone)
        XCTAssertNil(r.ituZone)
        XCTAssertNil(r.satellite)
        XCTAssertNil(r.remarks)
        XCTAssertEqual(r.frequencyMHz, 0.0)
        XCTAssertEqual(r.rxFrequencyMHz, 0.0)
        XCTAssertEqual(r.latitude, 0.0)
        XCTAssertEqual(r.longitude, 0.0)
    }
    
    func testUpdateFields() throws {
        let record = TestHelper.createFullQSORecord(in: context)
        try context.save()
        
        record.callsign = "BG9ZZZ"
        record.band = "40m"
        record.frequencyMHz = 7.074
        record.remarks = "Updated remarks"
        try context.save()
        
        let request = QSORecord.fetchRequest()
        let fetched = try context.fetch(request)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].callsign, "BG9ZZZ")
        XCTAssertEqual(fetched[0].band, "40m")
        XCTAssertEqual(fetched[0].frequencyMHz, 7.074, accuracy: 0.0001)
        XCTAssertEqual(fetched[0].remarks, "Updated remarks")
        XCTAssertEqual(fetched[0].name, "Zhang San")
    }
    
    func testDeleteRecord() throws {
        let record = TestHelper.createFullQSORecord(in: context)
        try context.save()
        
        context.delete(record)
        try context.save()
        
        let request = QSORecord.fetchRequest()
        let fetched = try context.fetch(request)
        XCTAssertEqual(fetched.count, 0)
    }
    
    func testMultipleRecords() throws {
        for i in 0..<10 {
            let r = QSORecord(context: context)
            r.callsign = "BG\(i)ABC"
            r.date = Date()
            r.band = "20m"
            r.mode = "SSB"
            r.rstSent = "59"
            r.rstReceived = "59"
        }
        try context.save()
        
        let request = QSORecord.fetchRequest()
        let fetched = try context.fetch(request)
        XCTAssertEqual(fetched.count, 10)
        
        let callsigns = Set(fetched.map(\.callsign))
        XCTAssertEqual(callsigns.count, 10)
    }
}
