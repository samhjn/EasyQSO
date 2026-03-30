import XCTest
import CoreData
@testable import EasyQSO

final class SchemaIntegrityTests: XCTestCase {
    
    private var model: NSManagedObjectModel!
    private var entity: NSEntityDescription!
    
    override func setUp() {
        super.setUp()
        model = EasyQSOModel.createModel()
        entity = model.entitiesByName["QSORecord"]
    }
    
    func testEntityExists() {
        XCTAssertNotNil(entity, "QSORecord entity must exist in the model")
    }
    
    func testAttributeCount() {
        XCTAssertEqual(entity.attributesByName.count, 21,
                       "QSORecord must have exactly 21 attributes")
    }
    
    func testRequiredStringAttributes() {
        let requiredStrings: [(name: String, type: NSAttributeType)] = [
            ("callsign", .stringAttributeType),
            ("band", .stringAttributeType),
            ("mode", .stringAttributeType),
            ("rstSent", .stringAttributeType),
            ("rstReceived", .stringAttributeType),
        ]
        
        for attr in requiredStrings {
            guard let desc = entity.attributesByName[attr.name] else {
                XCTFail("Missing required attribute: \(attr.name)")
                continue
            }
            XCTAssertEqual(desc.attributeType, attr.type, "\(attr.name) should be \(attr.type)")
            XCTAssertFalse(desc.isOptional, "\(attr.name) should be non-optional")
        }
    }
    
    func testRequiredDateAttribute() {
        guard let dateAttr = entity.attributesByName["date"] else {
            XCTFail("Missing 'date' attribute")
            return
        }
        XCTAssertEqual(dateAttr.attributeType, .dateAttributeType)
        XCTAssertFalse(dateAttr.isOptional)
    }
    
    func testFrequencyAttributes() {
        let freqAttrs = ["frequencyHz", "rxFrequencyHz"]
        for name in freqAttrs {
            guard let desc = entity.attributesByName[name] else {
                XCTFail("Missing attribute: \(name)")
                continue
            }
            XCTAssertEqual(desc.attributeType, .integer64AttributeType, "\(name) should be Int64")
            XCTAssertFalse(desc.isOptional, "\(name) should be non-optional")
            XCTAssertEqual(desc.defaultValue as? Int64 ?? -1, 0, "\(name) default should be 0")
        }
    }
    
    func testLegacyFrequencyAttributes() {
        let legacyAttrs = ["frequency", "rxFrequency"]
        for name in legacyAttrs {
            guard let desc = entity.attributesByName[name] else {
                XCTFail("Missing legacy attribute: \(name)")
                continue
            }
            XCTAssertEqual(desc.attributeType, .doubleAttributeType, "\(name) should be Double")
            XCTAssertTrue(desc.isOptional, "\(name) should be optional")
        }
    }
    
    func testOptionalStringAttributes() {
        let optionalStrings = [
            "txPower", "name", "qth", "gridSquare",
            "cqZone", "ituZone", "satellite", "remarks"
        ]
        
        for name in optionalStrings {
            guard let desc = entity.attributesByName[name] else {
                XCTFail("Missing optional attribute: \(name)")
                continue
            }
            XCTAssertEqual(desc.attributeType, .stringAttributeType, "\(name) should be String")
            XCTAssertTrue(desc.isOptional, "\(name) should be optional")
        }
    }
    
    func testCoordinateAttributes() {
        for name in ["latitude", "longitude"] {
            guard let desc = entity.attributesByName[name] else {
                XCTFail("Missing coordinate attribute: \(name)")
                continue
            }
            XCTAssertEqual(desc.attributeType, .doubleAttributeType, "\(name) should be Double")
            XCTAssertFalse(desc.isOptional, "\(name) should be non-optional")
        }
    }
    
    func testAdifFieldsDataAttribute() {
        guard let desc = entity.attributesByName["adifFieldsData"] else {
            XCTFail("Missing adifFieldsData attribute")
            return
        }
        XCTAssertEqual(desc.attributeType, .binaryDataAttributeType)
        XCTAssertTrue(desc.isOptional)
    }
    
    func testAllExpectedAttributeNamesPresent() {
        let expectedNames: Set<String> = [
            "callsign", "date", "band", "mode",
            "frequencyHz", "rxFrequencyHz", "frequency", "rxFrequency",
            "txPower", "rstSent", "rstReceived",
            "name", "qth", "gridSquare", "cqZone", "ituZone",
            "satellite", "remarks",
            "latitude", "longitude",
            "adifFieldsData"
        ]
        
        let actualNames = Set(entity.attributesByName.keys)
        XCTAssertEqual(actualNames, expectedNames,
                       "Attribute names mismatch. Extra: \(actualNames.subtracting(expectedNames)), Missing: \(expectedNames.subtracting(actualNames))")
    }
}
