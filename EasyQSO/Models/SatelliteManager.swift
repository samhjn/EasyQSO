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

// MARK: - Satellite Picker Item

struct SatellitePickerItem: Identifiable, Equatable {
    let id: String
    let satName: String
    let displayLabel: String
}

// MARK: - SatelliteManager

class SatelliteManager: ObservableObject {
    static let shared = SatelliteManager()

    @Published private(set) var revision = 0

    private static let customKey = "CustomSatellites"
    private static let hiddenKey = "HiddenSatellites"

    private init() {}

    // MARK: - ADIF 3.1.7 Satellite Names (SAT_NAME enumeration)

    static let presetSatellites: [(name: String, description: String)] = [
        // Active amateur radio satellites
        ("AO-7",       "AMSAT-OSCAR 7"),
        ("AO-27",      "AMRAD-OSCAR 27"),
        ("AO-73",      "FUNcube-1"),
        ("AO-91",      "RadFxSat / Fox-1B"),
        ("AO-92",      "Fox-1D"),
        ("AO-109",     "RadFxSat-2 / Fox-1E"),
        ("SO-50",      "SaudiSat-1C / OSCAR 50"),
        ("SO-121",     "HADES-D"),
        ("RS-44",      "DOSAAF-85"),
        ("IO-86",      "LAPAN-OSCAR 86"),
        ("IO-117",     "GreenCube"),
        ("XW-2A",      "CAS-3A"),
        ("XW-2B",      "CAS-3B"),
        ("XW-2C",      "CAS-3C"),
        ("XW-2D",      "CAS-3D"),
        ("XW-2E",      "CAS-3E"),
        ("XW-2F",      "CAS-3F"),
        ("CAS-4A",     "ZHUHAI-1 01"),
        ("CAS-4B",     "ZHUHAI-1 02"),
        ("CAS-5A",     "FO-118"),
        ("CAS-6",      "TIANQIN-1"),
        ("CAS-9",      "XW-3"),
        ("CAS-10",     "XW-4"),
        ("JO-97",      "JY1SAT"),
        ("LO-87",      "Nayif-1"),
        ("LO-90",      "OSCAR 90"),
        ("PO-101",     "Diwata-2B"),
        ("HO-113",     "ESHAIL-2 / QO-100"),
        ("FO-29",      "JAS-2"),
        ("FO-99",      "NEXUS"),
        ("FO-118",     "CAS-5A"),
        ("TO-108",     "CAS-6"),
        ("EO-88",      "Nayif-1"),
        ("TEVEL-1",    "TEVEL-1"),
        ("TEVEL-2",    "TEVEL-2"),
        ("TEVEL-3",    "TEVEL-3"),
        ("TEVEL-4",    "TEVEL-4"),
        ("TEVEL-5",    "TEVEL-5"),
        ("TEVEL-6",    "TEVEL-6"),
        ("TEVEL-7",    "TEVEL-7"),
        ("TEVEL-8",    "TEVEL-8"),
        ("MESAT-1",    "MESAT-1"),
        ("ISS",        "International Space Station"),
        ("ARISS",      "Amateur Radio on the ISS"),
        ("SONATE-2",   "SONATE-2"),
        ("GREENCUBE",  "IO-117 GreenCube"),
        ("QO-100",     "Qatar OSCAR 100 / Es'hail-2"),
        // Historical / inactive but commonly logged
        ("AO-85",      "Fox-1A"),
        ("AO-95",      "Fox-1Cliff"),
        ("AO-10",      "AMSAT-OSCAR 10"),
        ("AO-13",      "AMSAT-OSCAR 13"),
        ("AO-40",      "AMSAT-OSCAR 40"),
        ("AO-51",      "Echo / AMSAT-OSCAR 51"),
        ("SO-67",      "SumbandilaSat"),
        ("FO-12",      "Fuji-OSCAR 12"),
        ("FO-20",      "Fuji-OSCAR 20"),
        ("VO-52",      "HAMSAT"),
        ("RS-15",      "Radio Sputnik 15"),
        ("RS-22",      "MOZHAYETS 4"),
        ("DO-64",      "Delfi-C3"),
        ("UO-14",      "UoSAT-3"),
        ("NO-44",      "Navy-OSCAR 44 / PCsat"),
        ("NO-84",      "PSAT-2"),
    ]

    /// All preset satellite names
    static let allPresetNames: [String] = presetSatellites.map(\.name)

    /// Lookup: name → description
    static let presetNameToDescription: [String: String] = {
        var map = [String: String]()
        for sat in presetSatellites {
            map[sat.name.uppercased()] = sat.description
        }
        return map
    }()

    // MARK: - User preferences

    var customSatellites: [String] {
        UserDefaults.standard.stringArray(forKey: Self.customKey) ?? []
    }

    var hiddenSatellites: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: Self.hiddenKey) ?? [])
    }

    var allKnownSatellites: [String] {
        var satellites = Self.allPresetNames
        for custom in customSatellites {
            if !satellites.contains(where: { $0.uppercased() == custom.uppercased() }) {
                satellites.append(custom)
            }
        }
        return satellites
    }

    var enabledSatellites: [String] {
        let hidden = hiddenSatellites
        return allKnownSatellites.filter { !hidden.contains($0.uppercased()) }
    }

    func pickerItems(current: String) -> [SatellitePickerItem] {
        var items: [SatellitePickerItem] = []
        let enabled = enabledSatellites

        for sat in enabled {
            items.append(SatellitePickerItem(
                id: sat.uppercased(),
                satName: sat,
                displayLabel: sat
            ))
        }

        // Ensure current value is in the list
        if !current.isEmpty && !items.contains(where: { $0.satName.uppercased() == current.uppercased() }) {
            items.append(SatellitePickerItem(
                id: current.uppercased(),
                satName: current,
                displayLabel: current
            ))
        }

        return items
    }

    // MARK: - Custom/Hidden satellite management

    func addCustomSatellite(_ satellite: String) {
        let name = satellite.uppercased().trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        var satellites = customSatellites
        guard !Self.allPresetNames.contains(where: { $0.uppercased() == name }) &&
              !satellites.contains(where: { $0.uppercased() == name }) else { return }
        satellites.append(name)
        UserDefaults.standard.set(satellites, forKey: Self.customKey)
        objectWillChange.send()
        revision += 1
    }

    func removeCustomSatellite(_ satellite: String) {
        var satellites = customSatellites
        satellites.removeAll { $0.uppercased() == satellite.uppercased() }
        UserDefaults.standard.set(satellites, forKey: Self.customKey)
        var hidden = hiddenSatellites
        hidden.remove(satellite.uppercased())
        UserDefaults.standard.set(Array(hidden), forKey: Self.hiddenKey)
        objectWillChange.send()
        revision += 1
    }

    func setHidden(_ hidden: Bool, for satellite: String) {
        var set = hiddenSatellites
        if hidden { set.insert(satellite.uppercased()) } else { set.remove(satellite.uppercased()) }
        UserDefaults.standard.set(Array(set), forKey: Self.hiddenKey)
        objectWillChange.send()
        revision += 1
    }

    func isHidden(_ satellite: String) -> Bool {
        hiddenSatellites.contains(satellite.uppercased())
    }

    func isCustom(_ satellite: String) -> Bool {
        customSatellites.contains(where: { $0.uppercased() == satellite.uppercased() })
    }

    func isPreset(_ satellite: String) -> Bool {
        Self.allPresetNames.contains(where: { $0.uppercased() == satellite.uppercased() })
    }

    /// Description for a satellite name (preset only)
    static func description(for name: String) -> String? {
        presetNameToDescription[name.uppercased()]
    }

    /// Enabled item count (for settings display)
    var enabledItemCount: Int {
        enabledSatellites.count
    }
}
