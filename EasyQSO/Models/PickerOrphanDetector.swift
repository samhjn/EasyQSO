import Foundation

/// Helpers for detecting "orphan" picker selections — values that exist on a
/// record but are no longer part of the manager's known list. Happens when a
/// custom entry is deleted after being used, or when a QSO is imported with
/// an unfamiliar value.
enum PickerOrphanDetector {

    /// True when `value` is non-empty and absent from `knownItems` (case-insensitive).
    static func isOrphan(value: String, knownItems: [String]) -> Bool {
        guard !value.isEmpty else { return false }
        let needle = value.uppercased()
        return !knownItems.contains(where: { $0.uppercased() == needle })
    }

    /// True when the orphan value should be visible given the active search text.
    /// Empty search always matches; otherwise use a case-insensitive substring test.
    static func matchesSearch(value: String, searchText: String) -> Bool {
        guard !searchText.isEmpty else { return true }
        return value.localizedCaseInsensitiveContains(searchText)
    }
}
