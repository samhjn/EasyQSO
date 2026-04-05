/*
 * EasyQSO - 业余无线电通联日志
 * Copyright (C) 2025 ShadowMov
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import Foundation
import Combine

// MARK: - Mode Picker Item

struct ModePickerItem: Identifiable, Equatable {
    let id: String
    let adifMode: String
    let adifSubmode: String?
    let isSubmode: Bool

    var tagValue: String { adifSubmode ?? adifMode }

    var displayLabel: String {
        if isSubmode, let sub = adifSubmode {
            return "    \(sub)"
        }
        return adifMode
    }
}

// MARK: - ModeManager

class ModeManager: ObservableObject {
    static let shared = ModeManager()

    @Published private(set) var revision = 0

    private static let customKey = "CustomModes"
    private static let customSubmodesKey = "CustomSubmodes"
    private static let hiddenKey = "HiddenModes"
    private static let hiddenSubmodesKey = "HiddenSubmodes"
    private static let submodesMigratedKey = "SubmodeMigrationDone_v2"

    private init() {}

    // MARK: - ADIF 3.1.7 Mode ↔ Submode mapping

    static let modeSubmodes: [(mode: String, submodes: [String])] = [
        ("AM", []),
        ("ARDOP", []),
        ("ATV", []),
        ("CHIP", ["CHIP64", "CHIP128"]),
        ("CLO", []),
        ("CONTESTI", []),
        ("CW", ["PCW"]),
        ("DIGITALVOICE", ["C4FM", "DMR", "DSTAR", "FREEDV", "M17"]),
        ("DOMINO", ["DOM-M", "DOM4", "DOM5", "DOM8", "DOM11", "DOM16", "DOM22", "DOM44", "DOM88", "DOMINOEX", "DOMINOF"]),
        ("DYNAMIC", ["FREEDATA", "VARA HF", "VARA SATELLITE", "VARA FM 1200", "VARA FM 9600"]),
        ("FAX", []),
        ("FM", []),
        ("FSK441", []),
        ("FSK", ["SCAMP_FAST", "SCAMP_SLOW", "SCAMP_VSLOW"]),
        ("FT8", []),
        ("HELL", ["FMHELL", "FSKH105", "FSKH245", "FSKHELL", "HELL80", "HELLX5", "HELLX9", "HFSK", "PSKHELL", "SLOWHELL"]),
        ("ISCAT", ["ISCAT-A", "ISCAT-B"]),
        ("JT4", ["JT4A", "JT4B", "JT4C", "JT4D", "JT4E", "JT4F", "JT4G"]),
        ("JT6M", []),
        ("JT9", ["JT9-1", "JT9-2", "JT9-5", "JT9-10", "JT9-30", "JT9A", "JT9B", "JT9C", "JT9D", "JT9E", "JT9E FAST", "JT9F", "JT9F FAST", "JT9G", "JT9G FAST", "JT9H", "JT9H FAST"]),
        ("JT44", []),
        ("JT65", ["JT65A", "JT65B", "JT65B2", "JT65C", "JT65C2"]),
        ("MFSK", ["FSQCALL", "FST4", "FST4W", "FT2", "FT4", "JS8", "JTMS", "MFSK4", "MFSK8", "MFSK11", "MFSK16", "MFSK22", "MFSK31", "MFSK32", "MFSK64", "MFSK64L", "MFSK128", "MFSK128L", "Q65"]),
        ("MSK144", []),
        ("MTONE", ["SCAMP_OO", "SCAMP_OO_SLW"]),
        ("MT63", []),
        ("OFDM", ["RIBBIT_PIX", "RIBBIT_SMS"]),
        ("OLIVIA", ["OLIVIA 4/125", "OLIVIA 4/250", "OLIVIA 8/250", "OLIVIA 8/500", "OLIVIA 16/500", "OLIVIA 16/1000", "OLIVIA 32/1000"]),
        ("OPERA", ["OPERA-BEACON", "OPERA-QSO"]),
        ("PAC", ["PAC2", "PAC3", "PAC4"]),
        ("PAX", ["PAX2"]),
        ("PKT", []),
        ("PSK", [
            "8PSK125", "8PSK125F", "8PSK125FL", "8PSK250", "8PSK250F", "8PSK250FL",
            "8PSK500", "8PSK500F", "8PSK1000", "8PSK1000F", "8PSK1200F",
            "FSK31", "PSK10", "PSK31", "PSK63", "PSK63F",
            "PSK63RC4", "PSK63RC5", "PSK63RC10", "PSK63RC20", "PSK63RC32",
            "PSK125", "PSK125C12", "PSK125R", "PSK125RC10", "PSK125RC12", "PSK125RC16", "PSK125RC4", "PSK125RC5",
            "PSK250", "PSK250C6", "PSK250R", "PSK250RC2", "PSK250RC3", "PSK250RC5", "PSK250RC6", "PSK250RC7",
            "PSK500", "PSK500C2", "PSK500C4", "PSK500R", "PSK500RC2", "PSK500RC3", "PSK500RC4",
            "PSK800C2", "PSK800RC2",
            "PSK1000", "PSK1000C2", "PSK1000R", "PSK1000RC2",
            "PSKAM10", "PSKAM31", "PSKAM50", "PSKFEC31",
            "QPSK31", "QPSK63", "QPSK125", "QPSK250", "QPSK500", "SIM31"
        ]),
        ("PSK2K", []),
        ("Q15", []),
        ("QRA64", ["QRA64A", "QRA64B", "QRA64C", "QRA64D", "QRA64E"]),
        ("ROS", ["ROS-EME", "ROS-HF", "ROS-MF"]),
        ("RTTY", ["ASCI"]),
        ("RTTYM", []),
        ("SSB", ["LSB", "USB"]),
        ("SSTV", []),
        ("T10", []),
        ("THOR", ["THOR-M", "THOR4", "THOR5", "THOR8", "THOR11", "THOR16", "THOR22", "THOR25X4", "THOR50X1", "THOR50X2", "THOR100"]),
        ("THRB", ["THRBX", "THRBX1", "THRBX2", "THRBX4", "THROB1", "THROB2", "THROB4"]),
        ("TOR", ["AMTORFEC", "GTOR", "NAVTEX", "SITORB"]),
        ("V4", []),
        ("VOI", []),
        ("WINMOR", []),
        ("WSPR", []),
    ]

    /// All ADIF mode names (no submodes)
    static let allAdifModes: [String] = modeSubmodes.map(\.mode)

    /// Reverse lookup (preset only): submode → parent mode
    static let presetSubmodeToMode: [String: String] = {
        var map = [String: String]()
        for entry in modeSubmodes {
            for sub in entry.submodes {
                map[sub.uppercased()] = entry.mode
            }
        }
        return map
    }()

    /// Lookup (preset only): mode → submodes
    static let presetModeToSubmodes: [String: [String]] = {
        var map = [String: [String]]()
        for entry in modeSubmodes {
            map[entry.mode] = entry.submodes
        }
        return map
    }()

    /// Combined submode→mode map including custom submodes
    static var submodeToMode: [String: String] {
        var map = presetSubmodeToMode
        for (mode, subs) in shared.customSubmodes {
            for sub in subs {
                map[sub.uppercased()] = mode.uppercased()
            }
        }
        return map
    }

    /// Combined mode→submodes map including custom submodes
    static var modeToSubmodes: [String: [String]] {
        var map = presetModeToSubmodes
        for (mode, subs) in shared.customSubmodes {
            let key = mode.uppercased()
            var existing = map[key] ?? []
            for sub in subs where !existing.contains(where: { $0.uppercased() == sub.uppercased() }) {
                existing.append(sub)
            }
            map[key] = existing
        }
        return map
    }

    /// Modes enabled by default (user sees these without configuration)
    static let defaultEnabledModes: Set<String> = [
        "SSB", "CW", "FM", "AM", "RTTY", "PSK", "FT8", "MFSK", "JT65"
    ]

    /// Submodes enabled by default (only these are visible on first launch)
    static let defaultEnabledSubmodes: Set<String> = ["LSB", "USB"]

    /// Legacy presetModes list (for backward compat of settings display)
    static let presetModes: [String] = Array(defaultEnabledModes).sorted()

    // MARK: - Resolve mode/submode from a picker value or imported string

    /// Given a string (could be a mode or submode name), resolve to (mode, submode?)
    static func resolveMode(_ value: String) -> (mode: String, submode: String?) {
        let upper = value.uppercased()
        let allSubmodeMap = submodeToMode
        if let parent = allSubmodeMap[upper] {
            return (parent, upper)
        }
        return (upper, nil)
    }

    /// Check if a string is a known submode (preset or custom)
    static func isKnownSubmode(_ value: String) -> Bool {
        submodeToMode[value.uppercased()] != nil
    }

    /// Get parent mode for a submode, nil if not a submode
    static func parentMode(for submode: String) -> String? {
        submodeToMode[submode.uppercased()]
    }

    /// Check if a mode is voice-type (considers both mode and submode)
    static func isVoiceMode(mode: String, submode: String?) -> Bool {
        let m = mode.uppercased()
        let s = (submode ?? "").uppercased()
        if ["SSB", "FM", "AM"].contains(m) { return true }
        if ["LSB", "USB"].contains(s) { return true }
        return false
    }

    /// Check if a mode is CW-type
    static func isCWMode(mode: String, submode: String?) -> Bool {
        mode.uppercased() == "CW"
    }

    // MARK: - User preferences

    var customModes: [String] {
        UserDefaults.standard.stringArray(forKey: Self.customKey) ?? []
    }

    /// Custom submodes stored as JSON dictionary: { "MODE": ["SUB1", "SUB2"] }
    var customSubmodes: [String: [String]] {
        guard let data = UserDefaults.standard.data(forKey: Self.customSubmodesKey),
              let dict = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return [:]
        }
        return dict
    }

    /// Get all submodes (preset + custom) for a given mode
    func allSubmodes(for mode: String) -> [String] {
        let modeUpper = mode.uppercased()
        var subs = Self.presetModeToSubmodes[modeUpper] ?? []
        if let custom = customSubmodes[modeUpper] {
            for c in custom where !subs.contains(where: { $0.uppercased() == c.uppercased() }) {
                subs.append(c)
            }
        }
        return subs
    }

    func customSubmodesForMode(_ mode: String) -> [String] {
        customSubmodes[mode.uppercased()] ?? []
    }

    func isCustomSubmode(_ submode: String, under mode: String) -> Bool {
        customSubmodesForMode(mode).contains(where: { $0.uppercased() == submode.uppercased() })
    }

    func addCustomSubmode(_ submode: String, to mode: String) {
        let sub = submode.uppercased().trimmingCharacters(in: .whitespaces)
        let modeKey = mode.uppercased()
        guard !sub.isEmpty else { return }
        let presetSubs = Self.presetModeToSubmodes[modeKey] ?? []
        if presetSubs.contains(where: { $0.uppercased() == sub }) { return }
        var dict = customSubmodes
        var subs = dict[modeKey] ?? []
        if subs.contains(where: { $0.uppercased() == sub }) { return }
        if Self.presetSubmodeToMode[sub] != nil { return }
        subs.append(sub)
        dict[modeKey] = subs
        saveCustomSubmodes(dict)
        objectWillChange.send()
        revision += 1
    }

    func removeCustomSubmode(_ submode: String, from mode: String) {
        let modeKey = mode.uppercased()
        var dict = customSubmodes
        guard var subs = dict[modeKey] else { return }
        subs.removeAll { $0.uppercased() == submode.uppercased() }
        if subs.isEmpty {
            dict.removeValue(forKey: modeKey)
        } else {
            dict[modeKey] = subs
        }
        saveCustomSubmodes(dict)
        var hiddenSubs = hiddenSubmodes
        hiddenSubs.remove(submode.uppercased())
        UserDefaults.standard.set(Array(hiddenSubs), forKey: Self.hiddenSubmodesKey)
        objectWillChange.send()
        revision += 1
    }

    private func saveCustomSubmodes(_ dict: [String: [String]]) {
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: Self.customSubmodesKey)
        }
    }

    var hiddenModes: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: Self.hiddenKey) ?? [])
    }

    var hiddenSubmodes: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: Self.hiddenSubmodesKey) ?? [])
    }

    var allKnownModes: [String] {
        var modes = Self.allAdifModes
        for custom in customModes {
            if !modes.contains(where: { $0.uppercased() == custom.uppercased() }) {
                modes.append(custom)
            }
        }
        return modes
    }

    var enabledModes: [String] {
        let hidden = hiddenModes
        return allKnownModes.filter { !hidden.contains($0) }
    }

    var availableModes: [String] { enabledModes }

    /// Total count of enabled modes + enabled submodes (for settings display)
    var enabledItemCount: Int {
        let hidden = hiddenModes
        let hiddenSubs = hiddenSubmodes
        let enabled = allKnownModes.filter { !hidden.contains($0) }
        var count = enabled.count
        for mode in enabled {
            let subs = allSubmodes(for: mode)
            count += subs.filter { !hiddenSubs.contains($0.uppercased()) }.count
        }
        return count
    }

    /// Build the flat picker item list with modes and indented submodes
    func pickerItems(currentMode: String, currentSubmode: String) -> [ModePickerItem] {
        var items: [ModePickerItem] = []
        let hidden = hiddenModes
        let hiddenSubs = hiddenSubmodes
        let enabled = allKnownModes.filter { !hidden.contains($0) }

        for mode in enabled {
            let modeUpper = mode.uppercased()
            items.append(ModePickerItem(
                id: "m_\(modeUpper)",
                adifMode: mode,
                adifSubmode: nil,
                isSubmode: false
            ))
            let subs = allSubmodes(for: modeUpper)
            for sub in subs where !hiddenSubs.contains(sub.uppercased()) {
                items.append(ModePickerItem(
                    id: "s_\(sub.uppercased())",
                    adifMode: mode,
                    adifSubmode: sub,
                    isSubmode: true
                ))
            }
        }

        // Ensure current mode is in the list (for legacy data)
        let currentTag = currentSubmode.isEmpty ? currentMode : currentSubmode
        if !currentTag.isEmpty && !items.contains(where: { $0.tagValue.uppercased() == currentTag.uppercased() }) {
            if currentSubmode.isEmpty {
                items.append(ModePickerItem(
                    id: "m_\(currentMode.uppercased())",
                    adifMode: currentMode,
                    adifSubmode: nil,
                    isSubmode: false
                ))
            } else {
                if !items.contains(where: { $0.tagValue.uppercased() == currentMode.uppercased() }) {
                    items.append(ModePickerItem(
                        id: "m_\(currentMode.uppercased())",
                        adifMode: currentMode,
                        adifSubmode: nil,
                        isSubmode: false
                    ))
                }
                items.append(ModePickerItem(
                    id: "s_\(currentSubmode.uppercased())",
                    adifMode: currentMode,
                    adifSubmode: currentSubmode,
                    isSubmode: true
                ))
            }
        }

        return items
    }

    /// Backward-compatible flat mode list (for filters etc.)
    func pickerModes(current: String) -> [String] {
        var modes = enabledModes
        if !current.isEmpty && !modes.contains(where: { $0.uppercased() == current.uppercased() }) {
            modes.append(current)
        }
        return modes
    }

    // MARK: - Custom/Hidden mode management

    func addCustomMode(_ mode: String) {
        let upper = mode.uppercased().trimmingCharacters(in: .whitespaces)
        guard !upper.isEmpty else { return }
        var modes = customModes
        guard !Self.allAdifModes.contains(where: { $0.uppercased() == upper }) && !modes.contains(upper) else { return }
        modes.append(upper)
        UserDefaults.standard.set(modes, forKey: Self.customKey)
        objectWillChange.send()
        revision += 1
    }

    func removeCustomMode(_ mode: String) {
        var modes = customModes
        modes.removeAll { $0 == mode }
        UserDefaults.standard.set(modes, forKey: Self.customKey)
        var hidden = hiddenModes
        hidden.remove(mode)
        UserDefaults.standard.set(Array(hidden), forKey: Self.hiddenKey)
        objectWillChange.send()
        revision += 1
    }

    func setHidden(_ hidden: Bool, for mode: String) {
        var set = hiddenModes
        if hidden { set.insert(mode) } else { set.remove(mode) }
        UserDefaults.standard.set(Array(set), forKey: Self.hiddenKey)
        objectWillChange.send()
        revision += 1
    }

    func isHidden(_ mode: String) -> Bool {
        hiddenModes.contains(mode)
    }

    func setSubmodeHidden(_ hidden: Bool, for submode: String) {
        var set = hiddenSubmodes
        if hidden { set.insert(submode.uppercased()) } else { set.remove(submode.uppercased()) }
        UserDefaults.standard.set(Array(set), forKey: Self.hiddenSubmodesKey)
        objectWillChange.send()
        revision += 1
    }

    func isSubmodeHidden(_ submode: String) -> Bool {
        hiddenSubmodes.contains(submode.uppercased())
    }

    func isCustom(_ mode: String) -> Bool {
        customModes.contains(mode)
    }

    func isAdifPreset(_ mode: String) -> Bool {
        Self.allAdifModes.contains(where: { $0.uppercased() == mode.uppercased() })
    }

    // MARK: - Initial setup: hide non-default modes/submodes on first launch

    func ensureDefaultVisibility() {
        let modeKey = "ModeDefaultVisibilitySet_v2"
        let submodeKey = "SubmodeDefaultVisibilitySet_v1"
        var changed = false

        if !UserDefaults.standard.bool(forKey: modeKey) {
            var hidden = hiddenModes
            for entry in Self.modeSubmodes {
                if !Self.defaultEnabledModes.contains(entry.mode) {
                    hidden.insert(entry.mode)
                }
            }
            UserDefaults.standard.set(Array(hidden), forKey: Self.hiddenKey)
            UserDefaults.standard.set(true, forKey: modeKey)
            changed = true
        }

        if !UserDefaults.standard.bool(forKey: submodeKey) {
            var hiddenSubs = hiddenSubmodes
            for entry in Self.modeSubmodes {
                for sub in entry.submodes {
                    if !Self.defaultEnabledSubmodes.contains(sub.uppercased()) {
                        hiddenSubs.insert(sub.uppercased())
                    }
                }
            }
            UserDefaults.standard.set(Array(hiddenSubs), forKey: Self.hiddenSubmodesKey)
            UserDefaults.standard.set(true, forKey: submodeKey)
            changed = true
        }

        if changed {
            objectWillChange.send()
            revision += 1
        }
    }
}
