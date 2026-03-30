import XCTest
import CoreData
@testable import EasyQSO

enum TestHelper {
    
    static func createInMemoryContext() -> NSManagedObjectContext {
        let model = EasyQSOModel.createModel()
        let container = NSPersistentContainer(name: "EasyQSOTest", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        
        if let error = loadError {
            fatalError("Failed to load in-memory store: \(error)")
        }
        
        return container.viewContext
    }
    
    @discardableResult
    static func createFullQSORecord(in context: NSManagedObjectContext) -> QSORecord {
        let record = QSORecord(context: context)
        record.callsign = "BG5ABC"
        record.date = makeDate(year: 2025, month: 6, day: 15, hour: 14, minute: 30, second: 0)
        record.band = "20m"
        record.mode = "FT8"
        record.frequencyMHz = 14.074
        record.rxFrequencyMHz = 14.076
        record.txPower = "100"
        record.rstSent = "-10"
        record.rstReceived = "-12"
        record.name = "Zhang San"
        record.qth = "Beijing"
        record.gridSquare = "OM89xb"
        record.cqZone = "24"
        record.ituZone = "44"
        record.satellite = "SO-50"
        record.remarks = "Test QSO record"
        record.latitude = 39.9042
        record.longitude = 116.4074
        record.adifFields = [
            "SUBMODE": "FT8",
            "CONTEST_ID": "CQ-WW-CW",
            "POTA_REF": "CN-0001",
            "MY_GRIDSQUARE": "OM89xb",
            "TIME_OFF": "1445",
            "QSO_DATE_OFF": "20250615",
            "STATION_CALLSIGN": "BG5ABC",
            "BAND_RX": "20m"
        ]
        return record
    }
    
    static func makeDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0, second: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components)!
    }
}
