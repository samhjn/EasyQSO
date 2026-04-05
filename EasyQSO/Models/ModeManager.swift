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
    private static let hiddenKey = "HiddenModes"
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

    /// Reverse lookup: submode → parent mode
    static let submodeToMode: [String: String] = {
        var map = [String: String]()
        for entry in modeSubmodes {
            for sub in entry.submodes {
                map[sub.uppercased()] = entry.mode
            }
        }
        return map
    }()

    /// Lookup: mode → submodes
    static let modeToSubmodes: [String: [String]] = {
        var map = [String: [String]]()
        for entry in modeSubmodes {
            map[entry.mode] = entry.submodes
        }
        return map
    }()

    /// Modes enabled by default (user sees these without configuration)
    static let defaultEnabledModes: Set<String> = [
        "SSB", "CW", "FM", "AM", "RTTY", "PSK", "FT8", "MFSK", "JT65"
    ]

    /// Legacy presetModes list (for backward compat of settings display)
    static let presetModes: [String] = Array(defaultEnabledModes).sorted()

    // MARK: - Resolve mode/submode from a picker value or imported string

    /// Given a string (could be a mode or submode name), resolve to (mode, submode?)
    static func resolveMode(_ value: String) -> (mode: String, submode: String?) {
        let upper = value.uppercased()
        if let parent = submodeToMode[upper] {
            return (parent, value.uppercased())
        }
        if allAdifModes.contains(where: { $0.uppercased() == upper }) {
            return (value.uppercased(), nil)
        }
        return (value.uppercased(), nil)
    }

    /// Check if a string is a known submode
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

    var hiddenModes: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: Self.hiddenKey) ?? [])
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

    /// Build the flat picker item list with modes and indented submodes
    func pickerItems(currentMode: String, currentSubmode: String) -> [ModePickerItem] {
        var items: [ModePickerItem] = []
        let hidden = hiddenModes
        let enabled = allKnownModes.filter { !hidden.contains($0) }

        for mode in enabled {
            let modeUpper = mode.uppercased()
            items.append(ModePickerItem(
                id: "m_\(modeUpper)",
                adifMode: mode,
                adifSubmode: nil,
                isSubmode: false
            ))
            if let subs = Self.modeToSubmodes[modeUpper] {
                for sub in subs {
                    items.append(ModePickerItem(
                        id: "s_\(sub.uppercased())",
                        adifMode: mode,
                        adifSubmode: sub,
                        isSubmode: true
                    ))
                }
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

    func isCustom(_ mode: String) -> Bool {
        customModes.contains(mode)
    }

    func isAdifPreset(_ mode: String) -> Bool {
        Self.allAdifModes.contains(where: { $0.uppercased() == mode.uppercased() })
    }

    // MARK: - Initial setup: hide non-default modes on first launch

    func ensureDefaultVisibility() {
        let key = "ModeDefaultVisibilitySet_v2"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        var hidden = hiddenModes
        for entry in Self.modeSubmodes {
            if !Self.defaultEnabledModes.contains(entry.mode) {
                hidden.insert(entry.mode)
            }
        }
        UserDefaults.standard.set(Array(hidden), forKey: Self.hiddenKey)
        UserDefaults.standard.set(true, forKey: key)
        objectWillChange.send()
        revision += 1
    }
}
