import XCTest
import CoreLocation
@testable import EasyQSO

final class GridSquareTests: XCTestCase {

    // MARK: - Round-Trip Tests (coordinateFromGridSquare → calculateGridSquare)

    /// Regression test for PM00cg → PM00os bug
    func testRoundTrip_PM00cg() {
        let grid = "PM00cg"
        guard let coord = QTHManager.coordinateFromGridSquare(grid) else {
            return XCTFail("coordinateFromGridSquare returned nil for \(grid)")
        }
        let result = QTHManager.calculateGridSquare(from: coord)
        XCTAssertEqual(result.lowercased(), grid.lowercased(),
                       "Round-trip failed: \(grid) → (\(coord.latitude), \(coord.longitude)) → \(result)")
    }

    /// Batch round-trip for various 6-char grids
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

    /// 4-char grid round-trip: first 4 characters must match
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

    // MARK: - Subsquare Boundary Round-Trip

    /// Subsquare boundary values: aa (lower-left) and xx (upper-right)
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

    // MARK: - calculateGridSquare with Known Coordinates

    func testCalculateGridSquare_knownLocations() {
        // Beijing (39.9042°N, 116.4074°E) → OM89
        let beijing = CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074)
        let bjGrid = QTHManager.calculateGridSquare(from: beijing)
        XCTAssertTrue(bjGrid.uppercased().hasPrefix("OM89"),
                      "Beijing should be in OM89, got: \(bjGrid)")

        // New York (40.7128°N, 74.0060°W) → FN20
        let newYork = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let nyGrid = QTHManager.calculateGridSquare(from: newYork)
        XCTAssertTrue(nyGrid.uppercased().hasPrefix("FN20"),
                      "New York should be in FN20, got: \(nyGrid)")

        // London (51.5074°N, 0.1278°W) → IO91
        let london = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        let lonGrid = QTHManager.calculateGridSquare(from: london)
        XCTAssertTrue(lonGrid.uppercased().hasPrefix("IO91"),
                      "London should be in IO91, got: \(lonGrid)")

        // Sydney (33.8688°S, 151.2093°E) → QF56
        let sydney = CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)
        let syGrid = QTHManager.calculateGridSquare(from: sydney)
        XCTAssertTrue(syGrid.uppercased().hasPrefix("QF56"),
                      "Sydney should be in QF56, got: \(syGrid)")
    }

    // MARK: - coordinateFromGridSquare Range Tests

    func testCoordinateFromGridSquare_6char_withinSubsquare() {
        // Returned coordinate must fall within the subsquare cell
        let grid = "PM00cg"
        guard let coord = QTHManager.coordinateFromGridSquare(grid) else {
            return XCTFail("coordinateFromGridSquare returned nil")
        }

        // PM00cg subsquare bounds:
        // lon: 120 + 2*(2/24) = 120.1667 to 120.1667 + 2/24 = 120.25
        // lat: 30 + 6*(1/24) = 30.25 to 30.25 + 1/24 = 30.2917
        XCTAssertGreaterThanOrEqual(coord.longitude, 120.1666, "longitude lower bound")
        XCTAssertLessThanOrEqual(coord.longitude, 120.2501, "longitude upper bound")
        XCTAssertGreaterThanOrEqual(coord.latitude, 30.2499, "latitude lower bound")
        XCTAssertLessThanOrEqual(coord.latitude, 30.2918, "latitude upper bound")
    }

    func testCoordinateFromGridSquare_4char_withinSquare() {
        // Returned coordinate must fall within the square cell
        let grid = "PM00"
        guard let coord = QTHManager.coordinateFromGridSquare(grid) else {
            return XCTFail("coordinateFromGridSquare returned nil")
        }

        // PM00 bounds: lon 120~122, lat 30~31
        XCTAssertGreaterThanOrEqual(coord.longitude, 120.0)
        XCTAssertLessThanOrEqual(coord.longitude, 122.0)
        XCTAssertGreaterThanOrEqual(coord.latitude, 30.0)
        XCTAssertLessThanOrEqual(coord.latitude, 31.0)
    }

    // MARK: - isValidGridSquare Tests

    func testIsValidGridSquare_valid() {
        XCTAssertTrue(QTHManager.isValidGridSquare("PM00"))
        XCTAssertTrue(QTHManager.isValidGridSquare("PM00cg"))
        XCTAssertTrue(QTHManager.isValidGridSquare("AA00aa"))
        XCTAssertTrue(QTHManager.isValidGridSquare("RR99xx"))
        XCTAssertTrue(QTHManager.isValidGridSquare("FN31pr"))
        // Case insensitive
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

    // MARK: - Zone Validation Tests

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
