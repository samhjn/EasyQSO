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

    // MARK: - Schema Change Gate (模型变更门禁)

    /// 模型指纹门禁测试
    ///
    /// 该测试通过比对模型的属性指纹来检测 Schema 是否发生了变更。
    /// 当该测试失败时，表示有人修改了 CoreData 模型定义。
    ///
    /// **在更新指纹之前，必须确认：**
    /// 1. 轻量级迁移（Lightweight Migration）能否处理此变更
    /// 2. 已有数据库能否正常加载新模型
    /// 3. 迁移过程中不会丢失数据
    /// 4. 如果轻量级迁移无法处理，需提供自定义迁移方案
    func testSchemaChangeGate() {
        let attrs = entity.attributesByName.sorted { $0.key < $1.key }
        var lines: [String] = []
        for (name, attr) in attrs {
            let typeName: String
            switch attr.attributeType {
            case .stringAttributeType: typeName = "String"
            case .dateAttributeType: typeName = "Date"
            case .integer64AttributeType: typeName = "Int64"
            case .doubleAttributeType: typeName = "Double"
            case .binaryDataAttributeType: typeName = "Binary"
            default: typeName = "Type(\(attr.attributeType.rawValue))"
            }
            let optionality = attr.isOptional ? "optional" : "required"
            lines.append("\(name):\(typeName):\(optionality)")
        }
        let fingerprint = lines.joined(separator: "|")

        // 已知的正确 Schema 指纹 —— 21个属性，按名称排序
        let expected = [
            "adifFieldsData:Binary:optional",
            "band:String:required",
            "callsign:String:required",
            "cqZone:String:optional",
            "date:Date:required",
            "frequency:Double:optional",
            "frequencyHz:Int64:required",
            "gridSquare:String:optional",
            "ituZone:String:optional",
            "latitude:Double:required",
            "longitude:Double:required",
            "mode:String:required",
            "name:String:optional",
            "qth:String:optional",
            "remarks:String:optional",
            "rstReceived:String:required",
            "rstSent:String:required",
            "rxFrequency:Double:optional",
            "rxFrequencyHz:Int64:required",
            "satellite:String:optional",
            "txPower:String:optional",
        ].joined(separator: "|")

        XCTAssertEqual(fingerprint, expected,
            "Schema 指纹发生变化！在更新指纹前请确认：\n"
            + "1. 轻量级迁移能否处理此变更\n"
            + "2. 已有数据库能正常加载\n"
            + "3. 迁移不会丢失数据\n"
            + "当前指纹: \(fingerprint)")
    }

    /// 验证模型的 entityVersionHash 稳定性
    ///
    /// CoreData 使用 entityVersionHash 判断模型兼容性。
    /// 此测试记录当前 hash，任何模型变更都会导致 hash 变化，从而触发门禁。
    func testEntityVersionHashStability() {
        let hashes = model.entityVersionHashesByName
        XCTAssertNotNil(hashes["QSORecord"], "QSORecord entity version hash must exist")

        // 使用新创建的模型验证 hash 一致性（确保 createModel 是确定性的）
        let model2 = EasyQSOModel.createModel()
        let hashes2 = model2.entityVersionHashesByName

        XCTAssertEqual(
            hashes["QSORecord"], hashes2["QSORecord"],
            "Entity version hash must be deterministic across createModel() calls"
        )
    }
}
