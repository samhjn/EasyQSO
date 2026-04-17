import Foundation

/// Value snapshot of the editable fields on a QSO record.
/// Equatable comparison powers EditQSOView's `hasUnsavedChanges` check.
/// Lives outside the view so unit tests can verify that edits to each
/// tracked field (notably satellite, contest, DXCC, and extended fields)
/// are detected as changes.
struct EditQSOSnapshot: Equatable {
    var callsign: String
    var date: Date
    var endDate: Date
    var band: String
    var mode: String
    var submode: String
    var frequency: String
    var rxFrequency: String
    var txPower: String
    var rstSent: String
    var rstReceived: String
    var name: String
    var qth: String
    var gridSquare: String
    var cqZone: String
    var ituZone: String
    var satellite: String
    var remarks: String
    var extendedFields: [String: String]
    var rxBand: String
    var ownQTH: String
    var ownGridSquare: String
    var ownCQZone: String
    var ownITUZone: String
}
