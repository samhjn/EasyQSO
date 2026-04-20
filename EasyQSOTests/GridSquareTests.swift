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
            let result = QTHManager.calculateGridSquare(from: coord, precision: 6)
            XCTAssertEqual(result.lowercased(), grid.lowercased(),
                           "Round-trip failed for \(grid): got \(result)")
        }
    }

    // MARK: - Extended Precision Round-Trip (8/10/12 chars)

    /// Round-trip for 8-character grids
    func testRoundTrip_8char_batch() {
        let grids = [
            "PM00cg00", "FN31pr99", "JN58td45", "OM89xb12", "IO91wm03",
            "AA00aa00", "RR99xx99"
        ]
        for grid in grids {
            guard let coord = QTHManager.coordinateFromGridSquare(grid) else {
                XCTFail("coordinateFromGridSquare returned nil for \(grid)")
                continue
            }
            let result = QTHManager.calculateGridSquare(from: coord, precision: 8)
            XCTAssertEqual(result.lowercased(), grid.lowercased(),
                           "8-char round-trip failed for \(grid): got \(result)")
        }
    }

    /// Round-trip for 10-character grids
    func testRoundTrip_10char_batch() {
        let grids = [
            "PM00cg00aa", "FN31pr99xx", "JN58td45mn", "OM89xb12cd",
            "AA00aa00aa", "RR99xx99xx"
        ]
        for grid in grids {
            guard let coord = QTHManager.coordinateFromGridSquare(grid) else {
                XCTFail("coordinateFromGridSquare returned nil for \(grid)")
                continue
            }
            let result = QTHManager.calculateGridSquare(from: coord, precision: 10)
            XCTAssertEqual(result.lowercased(), grid.lowercased(),
                           "10-char round-trip failed for \(grid): got \(result)")
        }
    }

    /// Round-trip for 12-character grids
    func testRoundTrip_12char_batch() {
        let grids = [
            "PM00cg00aa00", "FN31pr99xx99", "JN58td45mn34", "OM89xb12cd56",
            "AA00aa00aa00", "RR99xx99xx99"
        ]
        for grid in grids {
            guard let coord = QTHManager.coordinateFromGridSquare(grid) else {
                XCTFail("coordinateFromGridSquare returned nil for \(grid)")
                continue
            }
            let result = QTHManager.calculateGridSquare(from: coord, precision: 12)
            XCTAssertEqual(result.lowercased(), grid.lowercased(),
                           "12-char round-trip failed for \(grid): got \(result)")
        }
    }

    /// 8-char decoded coordinate must fall within the 30″×15″ extended-square cell.
    func testCoordinateFromGridSquare_8char_withinCell() {
        let grid = "PM00cg23"
        guard let coord = QTHManager.coordinateFromGridSquare(grid) else {
            return XCTFail("coordinateFromGridSquare returned nil for \(grid)")
        }
        // PM00cg subsquare lower-left: lon 120 + 2*(2/24) = 120.16667, lat 30 + 6*(1/24) = 30.25
        // extended square (2,3): + 2*(2/240), 3*(1/240) = +0.01667, +0.0125
        // cell span: 2/240 lon = 0.00833, 1/240 lat = 0.00417
        let expectedLonLow = 120.16667 + 2.0 * (2.0/240.0)
        let expectedLatLow = 30.25 + 3.0 * (1.0/240.0)
        XCTAssertGreaterThanOrEqual(coord.longitude, expectedLonLow - 1e-6)
        XCTAssertLessThanOrEqual(coord.longitude, expectedLonLow + (2.0/240.0) + 1e-6)
        XCTAssertGreaterThanOrEqual(coord.latitude, expectedLatLow - 1e-6)
        XCTAssertLessThanOrEqual(coord.latitude, expectedLatLow + (1.0/240.0) + 1e-6)
    }

    /// Default no-precision call uses the user's preference.
    func testCalculateGridSquare_defaultUsesPreference() {
        let original = GridPrecisionManager.shared.displayPrecision
        defer { GridPrecisionManager.shared.displayPrecision = original }

        let coord = CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074)
        for p in [4, 6, 8, 10, 12] {
            GridPrecisionManager.shared.displayPrecision = p
            let grid = QTHManager.calculateGridSquare(from: coord)
            XCTAssertEqual(grid.count, p,
                           "No-arg call should respect preference \(p), got \(grid)")
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

    func testIsValidGridSquare_extended() {
        // Accept all even lengths 4...12
        XCTAssertTrue(QTHManager.isValidGridSquare("AB12cd34"))
        XCTAssertTrue(QTHManager.isValidGridSquare("AB12cd34ef"))
        XCTAssertTrue(QTHManager.isValidGridSquare("AB12cd34ef56"))
        XCTAssertTrue(QTHManager.isValidGridSquare("PM00cg00aa00"))
        // Case insensitive across all positions
        XCTAssertTrue(QTHManager.isValidGridSquare("ab12CD34EF56"))

        // Reject odd lengths and >12
        XCTAssertFalse(QTHManager.isValidGridSquare("AB12c"))
        XCTAssertFalse(QTHManager.isValidGridSquare("AB12cd3"))
        XCTAssertFalse(QTHManager.isValidGridSquare("AB12cd34e"))
        XCTAssertFalse(QTHManager.isValidGridSquare("AB12cd34ef5"))
        XCTAssertFalse(QTHManager.isValidGridSquare("AB12cd34ef56gh"))

        // Reject out-of-range chars in extended subsquare
        XCTAssertFalse(QTHManager.isValidGridSquare("AB12cd34yy"))  // y > x
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

    // MARK: - GridSquareFormatter

    func testFormatter_normalizesCaseAndStripsWhitespace() {
        XCTAssertEqual(GridSquareFormatter.format("ab12CD34EF56"), "AB12cd34ef56")
        XCTAssertEqual(GridSquareFormatter.format("  ab 12 CD 34 ef 56 "), "AB12cd34ef56")
        XCTAssertEqual(GridSquareFormatter.format("pm00cg"), "PM00cg")
    }

    func testFormatter_truncatesAtTwelve() {
        // Extra characters beyond 12 should be discarded
        XCTAssertEqual(GridSquareFormatter.format("AB12cd34ef56gh78"), "AB12cd34ef56")
    }

    func testFormatter_dropsInvalidChars() {
        // Z is out of range A-R at position 1; whole prefix dropped until valid
        XCTAssertEqual(GridSquareFormatter.format("ZZ99"), "")
        // Only the first char invalid: drop it, rest sanitized as if shifted
        XCTAssertEqual(GridSquareFormatter.format("Z" + "AB12cd"), "AB12cd")
        // Digit at position 1 is invalid; dropped
        XCTAssertEqual(GridSquareFormatter.format("1AB12"), "AB12")
    }

    func testFormatter_emptyAndPartial() {
        XCTAssertEqual(GridSquareFormatter.format(""), "")
        XCTAssertEqual(GridSquareFormatter.format("A"), "A")
        XCTAssertEqual(GridSquareFormatter.format("AB"), "AB")
        XCTAssertEqual(GridSquareFormatter.format("AB1"), "AB1")
    }

    // MARK: - GridPrecisionManager

    func testGridPrecisionManager_persistence() {
        let original = GridPrecisionManager.shared.displayPrecision
        defer { GridPrecisionManager.shared.displayPrecision = original }

        for p in [4, 6, 8, 10, 12] {
            GridPrecisionManager.shared.displayPrecision = p
            XCTAssertEqual(UserDefaults.standard.integer(forKey: "gridDisplayPrecision"), p)
        }
    }

    func testGridPrecisionManager_invalidValueClampsToDefault() {
        let original = GridPrecisionManager.shared.displayPrecision
        defer { GridPrecisionManager.shared.displayPrecision = original }

        GridPrecisionManager.shared.displayPrecision = 7  // odd / unsupported
        XCTAssertEqual(GridPrecisionManager.shared.displayPrecision, 6)

        GridPrecisionManager.shared.displayPrecision = 99
        XCTAssertEqual(GridPrecisionManager.shared.displayPrecision, 6)
    }

    func testGridPrecisionManager_supportedList() {
        XCTAssertEqual(GridPrecisionManager.supportedPrecisions, [4, 6, 8, 10, 12])
    }
}
