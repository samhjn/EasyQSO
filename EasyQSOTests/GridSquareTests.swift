import XCTest
import CoreLocation
@testable import EasyQSO

final class GridSquareTests: XCTestCase {

    // MARK: - Round-Trip Tests (coordinateFromGridSquare → calculateGridSquare)

    /// 本次 bug 的直接回归测试：PM00cg 不应变成 PM00os
    func testRoundTrip_PM00cg() {
        let grid = "PM00cg"
        guard let coord = QTHManager.coordinateFromGridSquare(grid) else {
            return XCTFail("coordinateFromGridSquare returned nil for \(grid)")
        }
        let result = QTHManager.calculateGridSquare(from: coord)
        XCTAssertEqual(result.lowercased(), grid.lowercased(),
                       "Round-trip failed: \(grid) → (\(coord.latitude), \(coord.longitude)) → \(result)")
    }

    /// 批量测试多个6字符网格的 round-trip
    func testRoundTrip_6char_batch() {
        let grids = [
            "PM00cg", "FN31pr", "JN58td", "OM89xb", "IO91wm",
            "BL11bh", "QF56od", "RE78ir", "CM97ai", "DO21xa"
        ]
        for grid in grids {
            guard let coord = QTHManager.coordinateFromGridSquare(grid) else {
                XCTFail("coordinateFromGridSquare returned nil for \(grid)")
                continue
            }
            let result = QTHManager.calculateGridSquare(from: coord)
            XCTAssertEqual(result.lowercased(), grid.lowercased(),
                           "Round-trip failed for \(grid): got \(result)")
        }
    }

    /// 4字符网格 round-trip：结果的前4字符应匹配
    func testRoundTrip_4char() {
        let grids = ["PM00", "FN31", "JN58", "IO91", "BL11"]
        for grid in grids {
            guard let coord = QTHManager.coordinateFromGridSquare(grid) else {
                XCTFail("coordinateFromGridSquare returned nil for \(grid)")
                continue
            }
            let result = QTHManager.calculateGridSquare(from: coord)
            let prefix = String(result.prefix(4)).uppercased()
            XCTAssertEqual(prefix, grid.uppercased(),
                           "4-char round-trip failed for \(grid): got \(result)")
        }
    }

    // MARK: - 边界子网格 Round-Trip

    /// 子网格边界值 aa 和 xx
    func testRoundTrip_subsquareBoundaries() {
        let grids = ["JN58aa", "JN58xx", "AA00aa", "RR99xx"]
        for grid in grids {
            guard let coord = QTHManager.coordinateFromGridSquare(grid) else {
                XCTFail("coordinateFromGridSquare returned nil for \(grid)")
                continue
            }
            let result = QTHManager.calculateGridSquare(from: coord)
            XCTAssertEqual(result.lowercased(), grid.lowercased(),
                           "Boundary round-trip failed for \(grid): got \(result)")
        }
    }

    // MARK: - calculateGridSquare 已知坐标测试

    func testCalculateGridSquare_knownLocations() {
        // 北京 (39.9042°N, 116.4074°E) → OM89
        let beijing = CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074)
        let bjGrid = QTHManager.calculateGridSquare(from: beijing)
        XCTAssertTrue(bjGrid.uppercased().hasPrefix("OM89"),
                      "北京应在 OM89，实际: \(bjGrid)")

        // 纽约 (40.7128°N, -74.0060°W) → FN30
        let newYork = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let nyGrid = QTHManager.calculateGridSquare(from: newYork)
        XCTAssertTrue(nyGrid.uppercased().hasPrefix("FN30"),
                      "纽约应在 FN30，实际: \(nyGrid)")

        // 伦敦 (51.5074°N, -0.1278°W) → IO91
        let london = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        let lonGrid = QTHManager.calculateGridSquare(from: london)
        XCTAssertTrue(lonGrid.uppercased().hasPrefix("IO91"),
                      "伦敦应在 IO91，实际: \(lonGrid)")

        // 悉尼 (-33.8688°S, 151.2093°E) → QF56
        let sydney = CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)
        let syGrid = QTHManager.calculateGridSquare(from: sydney)
        XCTAssertTrue(syGrid.uppercased().hasPrefix("QF56"),
                      "悉尼应在 QF56，实际: \(syGrid)")
    }

    // MARK: - coordinateFromGridSquare 坐标范围测试

    func testCoordinateFromGridSquare_6char_withinSubsquare() {
        // 6字符网格返回的坐标应落在对应子网格范围内
        let grid = "PM00cg"
        guard let coord = QTHManager.coordinateFromGridSquare(grid) else {
            return XCTFail("coordinateFromGridSquare returned nil")
        }

        // PM00cg 的子网格范围:
        // lon: 120 + 2*(2/24) = 120.1667 到 120.1667 + 2/24 = 120.25
        // lat: 30 + 6*(1/24) = 30.25 到 30.25 + 1/24 = 30.2917
        XCTAssertGreaterThanOrEqual(coord.longitude, 120.1666, "经度下界")
        XCTAssertLessThanOrEqual(coord.longitude, 120.2501, "经度上界")
        XCTAssertGreaterThanOrEqual(coord.latitude, 30.2499, "纬度下界")
        XCTAssertLessThanOrEqual(coord.latitude, 30.2918, "纬度上界")
    }

    func testCoordinateFromGridSquare_4char_withinSquare() {
        // 4字符网格返回的坐标应落在对应 square 范围内
        let grid = "PM00"
        guard let coord = QTHManager.coordinateFromGridSquare(grid) else {
            return XCTFail("coordinateFromGridSquare returned nil")
        }

        // PM00 范围: lon 120~122, lat 30~31
        XCTAssertGreaterThanOrEqual(coord.longitude, 120.0)
        XCTAssertLessThanOrEqual(coord.longitude, 122.0)
        XCTAssertGreaterThanOrEqual(coord.latitude, 30.0)
        XCTAssertLessThanOrEqual(coord.latitude, 31.0)
    }

    // MARK: - isValidGridSquare 验证测试

    func testIsValidGridSquare_valid() {
        XCTAssertTrue(QTHManager.isValidGridSquare("PM00"))
        XCTAssertTrue(QTHManager.isValidGridSquare("PM00cg"))
        XCTAssertTrue(QTHManager.isValidGridSquare("AA00aa"))
        XCTAssertTrue(QTHManager.isValidGridSquare("RR99xx"))
        XCTAssertTrue(QTHManager.isValidGridSquare("FN31pr"))
        // 大小写不敏感
        XCTAssertTrue(QTHManager.isValidGridSquare("fn31PR"))
        XCTAssertTrue(QTHManager.isValidGridSquare("Fn31Pr"))
    }

    func testIsValidGridSquare_invalid() {
        XCTAssertFalse(QTHManager.isValidGridSquare(""))
        XCTAssertFalse(QTHManager.isValidGridSquare("AB"))
        XCTAssertFalse(QTHManager.isValidGridSquare("AB1"))
        XCTAssertFalse(QTHManager.isValidGridSquare("12AB"))
        XCTAssertFalse(QTHManager.isValidGridSquare("ABCDEF"))
        XCTAssertFalse(QTHManager.isValidGridSquare("SS00aa"))  // S > R
        XCTAssertFalse(QTHManager.isValidGridSquare("PM00cy"))  // y > x
    }

    func testCoordinateFromGridSquare_invalidReturnsNil() {
        XCTAssertNil(QTHManager.coordinateFromGridSquare(""))
        XCTAssertNil(QTHManager.coordinateFromGridSquare("AB"))
        XCTAssertNil(QTHManager.coordinateFromGridSquare("invalid"))
        XCTAssertNil(QTHManager.coordinateFromGridSquare("SS00"))
    }

    // MARK: - Zone 验证测试

    func testIsValidCQZone() {
        XCTAssertTrue(QTHManager.isValidCQZone("1"))
        XCTAssertTrue(QTHManager.isValidCQZone("24"))
        XCTAssertTrue(QTHManager.isValidCQZone("40"))
        XCTAssertFalse(QTHManager.isValidCQZone("0"))
        XCTAssertFalse(QTHManager.isValidCQZone("41"))
        XCTAssertFalse(QTHManager.isValidCQZone("abc"))
    }

    func testIsValidITUZone() {
        XCTAssertTrue(QTHManager.isValidITUZone("1"))
        XCTAssertTrue(QTHManager.isValidITUZone("44"))
        XCTAssertTrue(QTHManager.isValidITUZone("90"))
        XCTAssertFalse(QTHManager.isValidITUZone("0"))
        XCTAssertFalse(QTHManager.isValidITUZone("91"))
        XCTAssertFalse(QTHManager.isValidITUZone("xyz"))
    }
}
