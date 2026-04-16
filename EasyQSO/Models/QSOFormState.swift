import Foundation

/// Pure-value snapshot of QSO form fields.
/// Extracted from QSORecordView so that `hasUserInput`, `resetAll()`,
/// and `clearTransient()` can be unit-tested without a live SwiftUI view.
struct QSOFormState {

    // MARK: - Contact fields (always count as user input when non-empty)

    var callsign: String = ""
    var rstSent: String = ""
    var rstReceived: String = ""
    var name: String = ""
    var qth: String = ""
    var gridSquare: String = ""
    var cqZone: String = ""
    var ituZone: String = ""
    var satellite: String = ""
    var remarks: String = ""
    var extendedFields: [String: String] = [:]

    // MARK: - Radio / technical fields (preserved during transient clear)

    var band: String = "20m"
    var mode: String = "SSB"
    var submode: String = ""
    var frequency: String = ""
    var rxFrequency: String = ""
    var rxBand: String = ""
    var txPower: String = ""

    // MARK: - Autofill tracking

    /// ADIF field IDs whose current values were set by the autofill engine.
    /// Fields in this set are excluded from the radio-field user-input check.
    var autoFilledFields: Set<String> = []

    // MARK: - Computed

    /// Whether the form contains any user-entered data that warrants
    /// showing the "reset form?" confirmation dialog on pull-to-refresh.
    ///
    /// Contact fields (callsign, RST, name, etc.) always count when non-empty.
    /// Radio fields (band, mode, freq, etc.) only count when they differ from
    /// their defaults AND were not set by autofill.
    var hasUserInput: Bool {
        !callsign.isEmpty || !rstSent.isEmpty || !rstReceived.isEmpty ||
        !name.isEmpty || !qth.isEmpty || !gridSquare.isEmpty ||
        !cqZone.isEmpty || !ituZone.isEmpty || !satellite.isEmpty ||
        !remarks.isEmpty || !extendedFields.isEmpty ||
        isManualEdit("BAND", value: band, defaultValue: "20m") ||
        isManualEdit("MODE", value: mode, defaultValue: "SSB") ||
        isManualEdit("SUBMODE", value: submode) ||
        isManualEdit("FREQ", value: frequency) ||
        isManualEdit("RX_FREQ", value: rxFrequency) ||
        isManualEdit("TX_PWR", value: txPower)
    }

    /// Returns true when the field was changed from its default AND not by autofill.
    private func isManualEdit(_ fieldId: String, value: String, defaultValue: String = "") -> Bool {
        value != defaultValue && !autoFilledFields.contains(fieldId)
    }

    // MARK: - Reset

    /// Reset every field to its factory default.
    mutating func resetAll() {
        callsign = ""
        band = "20m"
        mode = "SSB"
        submode = ""
        frequency = ""
        rxFrequency = ""
        rxBand = ""
        txPower = ""
        rstSent = ""
        rstReceived = ""
        name = ""
        qth = ""
        gridSquare = ""
        cqZone = ""
        ituZone = ""
        satellite = ""
        remarks = ""
        extendedFields = [:]
    }

    // MARK: - Transient clear

    /// ADIF keys for own-station data that should survive a transient clear.
    static let ownStationKeys: Set<String> = [
        "STATION_CALLSIGN", "OPERATOR", "MY_RIG", "MY_ANTENNA",
        "MY_POTA_REF", "MY_SOTA_REF", "MY_WWFF_REF",
        "MY_SIG", "MY_SIG_INFO", "MY_CITY", "MY_GRIDSQUARE",
        "MY_CQ_ZONE", "MY_ITU_ZONE", "MY_LAT", "MY_LON"
    ]

    /// Clear contact-specific fields while preserving radio settings,
    /// satellite, and own-station extended fields.
    mutating func clearTransient() {
        let preservedExtended = extendedFields.filter {
            Self.ownStationKeys.contains($0.key)
        }
        callsign = ""
        rstSent = ""
        rstReceived = ""
        name = ""
        qth = ""
        gridSquare = ""
        cqZone = ""
        ituZone = ""
        remarks = ""
        extendedFields = preservedExtended
        // band, mode, submode, frequency, rxFrequency, txPower, satellite
        // are intentionally preserved.
    }
}
