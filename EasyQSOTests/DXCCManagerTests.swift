import XCTest
@testable import EasyQSO

final class DXCCManagerTests: XCTestCase {

    private var manager: DXCCManager!

    override func setUp() {
        super.setUp()
        manager = DXCCManager.shared
    }

    override func tearDown() {
        // Reset manager to empty state after each test
        manager.loadTestData(entities: [], prefixes: [])
        super.tearDown()
    }

    // MARK: - CSV Parsing

    func testParseSingleEntity() throws {
        let csv = "1A,Sov Mil Order of Malta,246,EU,15,28,41.90,-12.43,-1.0,1A;\n"

        let (entities, prefixes) = try manager.parseCTYCsv(csv)

        XCTAssertEqual(entities.count, 1)
        let entity = entities[0]
        XCTAssertEqual(entity.code, 246)
        XCTAssertEqual(entity.name, "Sov Mil Order of Malta")
        XCTAssertEqual(entity.continent, "EU")
        XCTAssertEqual(entity.cqZone, 15)
        XCTAssertEqual(entity.ituZone, 28)
        XCTAssertEqual(entity.latitude, 41.90, accuracy: 0.01)
        XCTAssertEqual(entity.longitude, -12.43, accuracy: 0.01)
        XCTAssertEqual(entity.timeOffset, -1.0, accuracy: 0.1)
        XCTAssertEqual(entity.primaryPrefix, "1A")

        XCTAssertTrue(prefixes.contains { $0.prefix == "1A" && $0.entityCode == 246 && !$0.exact })
    }

    func testParseMultipleEntities() throws {
        let csv = """
        3A,Monaco,260,EU,14,27,43.73,-7.40,-1.0,3A =3A/4Z5KJ/LH;
        3B8,Mauritius,165,AF,39,53,-20.35,-57.50,-4.0,3B8;
        4X,Israel,336,AS,20,39,31.32,-34.82,-2.0,4X 4Z;
        """

        let (entities, prefixes) = try manager.parseCTYCsv(csv)

        XCTAssertEqual(entities.count, 3)
        let codes = Set(entities.map { $0.code })
        XCTAssertTrue(codes.contains(260))
        XCTAssertTrue(codes.contains(165))
        XCTAssertTrue(codes.contains(336))

        // Israel aliases
        let israelPrefixes = prefixes.filter { $0.entityCode == 336 && !$0.exact }
        let israelPrefixStrings = Set(israelPrefixes.map { $0.prefix })
        XCTAssertTrue(israelPrefixStrings.contains("4X"))
        XCTAssertTrue(israelPrefixStrings.contains("4Z"))
    }

    func testParseExactMatchAlias() throws {
        let csv = "3A,Monaco,260,EU,14,27,43.73,-7.40,-1.0,3A =3A/4Z5KJ/LH;\n"

        let (_, prefixes) = try manager.parseCTYCsv(csv)

        let exactEntries = prefixes.filter { $0.exact }
        XCTAssertEqual(exactEntries.count, 1)
        XCTAssertEqual(exactEntries[0].prefix, "3A/4Z5KJ/LH")
        XCTAssertEqual(exactEntries[0].entityCode, 260)
    }

    func testParseDedupesEntitiesBySameCode() throws {
        let csv = """
        3A,Monaco,260,EU,14,27,43.73,-7.40,-1.0,3A;
        3A,Monaco Duplicate,260,EU,14,27,43.73,-7.40,-1.0,3A;
        """

        let (entities, _) = try manager.parseCTYCsv(csv)
        XCTAssertEqual(entities.count, 1)
    }

    func testParseStarPrefix() throws {
        let csv = "*4U1V,Vienna Intl Ctr,117,EU,15,28,48.20,-16.30,-1.0,=4U1VIC;\n"

        let (entities, _) = try manager.parseCTYCsv(csv)
        XCTAssertEqual(entities.count, 1)
        XCTAssertEqual(entities[0].primaryPrefix, "4U1V")
    }

    func testParseEmptyContent() throws {
        let (entities, prefixes) = try manager.parseCTYCsv("")
        XCTAssertTrue(entities.isEmpty)
        XCTAssertTrue(prefixes.isEmpty)
    }

    func testParseInvalidLine() throws {
        let (entities, _) = try manager.parseCTYCsv("invalid,data;\n")
        XCTAssertTrue(entities.isEmpty)
    }

    func testEntitiesAreSortedByName() throws {
        let csv = """
        ZS,South Africa,462,AF,38,57,-29.07,-22.63,-2.0,ZS;
        3A,Monaco,260,EU,14,27,43.73,-7.40,-1.0,3A;
        4X,Israel,336,AS,20,39,31.32,-34.82,-2.0,4X;
        """

        let (entities, _) = try manager.parseCTYCsv(csv)
        let names = entities.map { $0.name }
        XCTAssertEqual(names, names.sorted())
    }

    // MARK: - Callsign Lookup

    func testLookupSimpleCallsign() {
        loadStandardTestData()

        let result = manager.lookupCallsign("W1AW")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.code, 291)
    }

    func testLookupLongestPrefixMatch() {
        loadStandardTestData()

        let result = manager.lookupCallsign("4X1ABC")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.code, 336)
    }

    func testLookupExactMatch() {
        loadStandardTestData()

        let result = manager.lookupCallsign("4U1VIC")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.code, 117)
    }

    func testLookupPortableCallsignModifier() {
        loadStandardTestData()

        // /P is a modifier → use base callsign
        let result = manager.lookupCallsign("W1AW/P")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.code, 291)
    }

    func testLookupCaseInsensitive() {
        loadStandardTestData()

        let result = manager.lookupCallsign("w1aw")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.code, 291)
    }

    func testLookupNoMatch() {
        loadStandardTestData()
        XCTAssertNil(manager.lookupCallsign("QQ0ZZZ"))
    }

    func testLookupEmptyCallsign() {
        loadStandardTestData()
        XCTAssertNil(manager.lookupCallsign(""))
    }

    func testLookupMultiplePrefixesSameEntity() {
        loadStandardTestData()

        // Both K and W should resolve to USA (291)
        let kResult = manager.lookupCallsign("K1ABC")
        let wResult = manager.lookupCallsign("W2DEF")
        let nResult = manager.lookupCallsign("N3GHI")

        XCTAssertEqual(kResult?.code, 291)
        XCTAssertEqual(wResult?.code, 291)
        XCTAssertEqual(nResult?.code, 291)
    }

    func testLookupAlternatePrefix() {
        loadStandardTestData()

        // 4Z is an alternate prefix for Israel
        let result = manager.lookupCallsign("4Z5ABC")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.code, 336)
    }

    func testLookupDXCCSuffixAfterCallsign() {
        loadStandardTestData()

        // BH5HSU/VR2 → DXCC should be Hong Kong (VR2), not China (BH)
        let result = manager.lookupCallsign("BH5HSU/VR2")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.code, 321) // Hong Kong
    }

    func testLookupDXCCPrefixBeforeCallsign() {
        loadStandardTestData()

        // VR2/BH5HSU → DXCC should be Hong Kong (VR2)
        let result = manager.lookupCallsign("VR2/BH5HSU")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.code, 321)
    }

    func testLookupModifierP() {
        loadStandardTestData()

        // W1AW/P → portable modifier, DXCC should be USA
        let result = manager.lookupCallsign("W1AW/P")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.code, 291)
    }

    func testLookupModifierMM() {
        loadStandardTestData()

        // W1AW/MM → maritime mobile modifier, DXCC from base callsign
        let result = manager.lookupCallsign("W1AW/MM")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.code, 291)
    }

    func testLookupModifierQRP() {
        loadStandardTestData()

        // W1AW/QRP → QRP modifier, DXCC should be USA
        let result = manager.lookupCallsign("W1AW/QRP")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.code, 291)
    }

    func testLookupNumericAreaIndicator() {
        loadStandardTestData()

        // W1AW/4 → numeric area indicator, DXCC should be USA
        let result = manager.lookupCallsign("W1AW/4")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.code, 291)
    }

    func testLookupDXCCSuffixWithModifier() {
        loadStandardTestData()

        // VR2/BH5HSU/P → strip /P, then VR2 prefix → Hong Kong
        let result = manager.lookupCallsign("VR2/BH5HSU/P")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.code, 321)
    }

    func testLookupShortDXCCPrefix() {
        loadStandardTestData()

        // W1AW/3A → 3A is Monaco, not a modifier
        let result = manager.lookupCallsign("W1AW/3A")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.code, 260) // Monaco
    }

    // MARK: - Entity Lookup by Code

    func testEntityForCode() {
        loadStandardTestData()

        let entity = manager.entity(forCode: 291)
        XCTAssertNotNil(entity)
        XCTAssertEqual(entity?.name, "United States")
    }

    func testEntityForCodeString() {
        loadStandardTestData()

        XCTAssertNotNil(manager.entity(forCodeString: "291"))
        XCTAssertNil(manager.entity(forCodeString: "abc"))
        XCTAssertNil(manager.entity(forCodeString: ""))
    }

    func testEntityForInvalidCode() {
        loadStandardTestData()
        XCTAssertNil(manager.entity(forCode: 99999))
    }

    // MARK: - Search

    func testSearchByName() {
        loadStandardTestData()
        let results = manager.searchEntities("Israel")
        XCTAssertTrue(results.contains { $0.code == 336 })
    }

    func testSearchByPrefix() {
        loadStandardTestData()
        let results = manager.searchEntities("4X")
        XCTAssertTrue(results.contains { $0.code == 336 })
    }

    func testSearchByCode() {
        loadStandardTestData()
        let results = manager.searchEntities("291")
        XCTAssertTrue(results.contains { $0.code == 291 })
    }

    func testSearchCaseInsensitive() {
        loadStandardTestData()
        let results = manager.searchEntities("israel")
        XCTAssertTrue(results.contains { $0.code == 336 })
    }

    func testSearchEmptyQuery() {
        loadStandardTestData()
        let results = manager.searchEntities("")
        XCTAssertEqual(results.count, manager.entities.count)
    }

    func testSearchNoResults() {
        loadStandardTestData()
        XCTAssertTrue(manager.searchEntities("ZZZZNONEXISTENT").isEmpty)
    }

    // MARK: - DXCCEntity Model

    func testDisplayName() {
        let entity = DXCCEntity(
            code: 291, name: "United States", cqZone: 5, ituZone: 8,
            continent: "NA", latitude: 40.0, longitude: -100.0,
            timeOffset: 5.0, primaryPrefix: "K"
        )
        XCTAssertEqual(entity.displayName, "United States (K)")
    }

    func testEntityIdentifiable() {
        let entity = DXCCEntity(
            code: 291, name: "United States", cqZone: 5, ituZone: 8,
            continent: "NA", latitude: 40.0, longitude: -100.0,
            timeOffset: 5.0, primaryPrefix: "K"
        )
        XCTAssertEqual(entity.id, 291)
    }

    // MARK: - isDataAvailable

    func testIsDataAvailableWhenEmpty() {
        manager.loadTestData(entities: [], prefixes: [])
        XCTAssertFalse(manager.isDataAvailable)
    }

    func testIsDataAvailableWithData() {
        loadStandardTestData()
        XCTAssertTrue(manager.isDataAvailable)
    }

    // MARK: - Helpers

    private func loadStandardTestData() {
        let entities = [
            DXCCEntity(code: 291, name: "United States", cqZone: 5, ituZone: 8, continent: "NA", latitude: 40.0, longitude: -100.0, timeOffset: 5.0, primaryPrefix: "K"),
            DXCCEntity(code: 336, name: "Israel", cqZone: 20, ituZone: 39, continent: "AS", latitude: 31.32, longitude: -34.82, timeOffset: -2.0, primaryPrefix: "4X"),
            DXCCEntity(code: 117, name: "Vienna Intl Ctr", cqZone: 15, ituZone: 28, continent: "EU", latitude: 48.20, longitude: -16.30, timeOffset: -1.0, primaryPrefix: "4U1V"),
            DXCCEntity(code: 260, name: "Monaco", cqZone: 14, ituZone: 27, continent: "EU", latitude: 43.73, longitude: -7.40, timeOffset: -1.0, primaryPrefix: "3A"),
            DXCCEntity(code: 321, name: "Hong Kong", cqZone: 24, ituZone: 44, continent: "AS", latitude: 22.28, longitude: -114.18, timeOffset: -8.0, primaryPrefix: "VR2"),
            DXCCEntity(code: 318, name: "China", cqZone: 24, ituZone: 44, continent: "AS", latitude: 36.0, longitude: -102.0, timeOffset: -8.0, primaryPrefix: "BY"),
        ]

        let prefixes = [
            DXCCPrefixEntry(prefix: "K", entityCode: 291, exact: false),
            DXCCPrefixEntry(prefix: "W", entityCode: 291, exact: false),
            DXCCPrefixEntry(prefix: "N", entityCode: 291, exact: false),
            DXCCPrefixEntry(prefix: "AA", entityCode: 291, exact: false),
            DXCCPrefixEntry(prefix: "4X", entityCode: 336, exact: false),
            DXCCPrefixEntry(prefix: "4Z", entityCode: 336, exact: false),
            DXCCPrefixEntry(prefix: "4U1VIC", entityCode: 117, exact: true),
            DXCCPrefixEntry(prefix: "4U1V", entityCode: 117, exact: false),
            DXCCPrefixEntry(prefix: "3A", entityCode: 260, exact: false),
            DXCCPrefixEntry(prefix: "VR2", entityCode: 321, exact: false),
            DXCCPrefixEntry(prefix: "BY", entityCode: 318, exact: false),
            DXCCPrefixEntry(prefix: "BH", entityCode: 318, exact: false),
            DXCCPrefixEntry(prefix: "BV", entityCode: 318, exact: false),
        ]

        manager.loadTestData(entities: entities, prefixes: prefixes)
    }
}
