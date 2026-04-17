import Foundation

/// Helpers for detecting "orphan" and "hidden" picker selections.
///
/// - **Orphan**: value exists on a record but is absent from the manager's
///   known list entirely (deleted custom entry or externally imported).
/// - **Hidden**: value is in the known list but disabled/hidden by the user,
///   so it won't appear in the enabled items shown by default.
enum PickerOrphanDetector {

    /// True when `value` is non-empty and absent from `knownItems` (case-insensitive).
    static func isOrphan(value: String, knownItems: [String]) -> Bool {
        guard !value.isEmpty else { return false }
        let needle = value.uppercased()
        return !knownItems.contains(where: { $0.uppercased() == needle })
    }

    /// True when `value` is in `allKnownItems` but NOT in `enabledItems`.
    /// This means the user hid/disabled the item, yet a record still references it.
    static func isHiddenButKnown(value: String, enabledItems: [String], allKnownItems: [String]) -> Bool {
        guard !value.isEmpty else { return false }
        let needle = value.uppercased()
        let inEnabled = enabledItems.contains(where: { $0.uppercased() == needle })
        let inKnown = allKnownItems.contains(where: { $0.uppercased() == needle })
        return !inEnabled && inKnown
    }

    /// True when the orphan value should be visible given the active search text.
    /// Empty search always matches; otherwise use a case-insensitive substring test.
    static func matchesSearch(value: String, searchText: String) -> Bool {
        guard !searchText.isEmpty else { return true }
        return value.localizedCaseInsensitiveContains(searchText)
    }
}
