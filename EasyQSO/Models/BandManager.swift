/*
 * EasyQSO - 业余无线电通联日志
 * Copyright (C) 2026 ShadowMov
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import Foundation
import Combine

/// The ADIF band enumeration is an interchange definition, not a regional band plan.
/// Source: https://www.adif.org/318/ADIF_318.htm#Band_Enumeration
final class BandManager: ObservableObject {
    static let shared = BandManager()
    static let commonBandsKey = "CommonBands_v1"

    struct Band {
        let name: String
        let rangeMHz: ClosedRange<Double>
    }

    /// ADIF 3.1.8, ordered by ascending frequency. Both endpoints are inclusive.
    static let bands: [Band] = [
        Band(name: "2190m", rangeMHz: 0.1357...0.1378),
        Band(name: "630m", rangeMHz: 0.472...0.479),
        Band(name: "560m", rangeMHz: 0.501...0.504),
        Band(name: "160m", rangeMHz: 1.8...2.0),
        Band(name: "80m", rangeMHz: 3.5...4.0),
        Band(name: "60m", rangeMHz: 5.06...5.45),
        Band(name: "40m", rangeMHz: 7.0...7.3),
        Band(name: "30m", rangeMHz: 10.1...10.15),
        Band(name: "20m", rangeMHz: 14.0...14.35),
        Band(name: "17m", rangeMHz: 18.068...18.168),
        Band(name: "15m", rangeMHz: 21.0...21.45),
        Band(name: "12m", rangeMHz: 24.890...24.99),
        Band(name: "10m", rangeMHz: 28.0...29.7),
        Band(name: "8m", rangeMHz: 40...45),
        Band(name: "6m", rangeMHz: 50...54),
        Band(name: "5m", rangeMHz: 54.000001...69.9),
        Band(name: "4m", rangeMHz: 70...71),
        Band(name: "2m", rangeMHz: 144...148),
        Band(name: "1.25m", rangeMHz: 222...225),
        Band(name: "70cm", rangeMHz: 420...450),
        Band(name: "33cm", rangeMHz: 902...928),
        Band(name: "23cm", rangeMHz: 1240...1300),
        Band(name: "13cm", rangeMHz: 2300...2450),
        Band(name: "9cm", rangeMHz: 3300...3500),
        Band(name: "6cm", rangeMHz: 5650...5925),
        Band(name: "3cm", rangeMHz: 10000...10500),
        Band(name: "1.25cm", rangeMHz: 24000...24250),
        Band(name: "6mm", rangeMHz: 47000...47200),
        Band(name: "4mm", rangeMHz: 75500...81000),
        Band(name: "2.5mm", rangeMHz: 119980...123000),
        Band(name: "2mm", rangeMHz: 134000...149000),
        Band(name: "1mm", rangeMHz: 241000...250000),
        Band(name: "submm", rangeMHz: 300000...7500000)
    ]

    static let allBands = bands.map(\.name)

    // Preserve the previous quick-selection list on first use.
    static let defaultCommonBands = [
        "160m", "80m", "40m", "30m", "20m", "17m",
        "15m", "12m", "10m", "6m", "2m", "70cm"
    ]

    @Published private(set) var commonBands: [String]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // An explicitly empty list is valid: every band remains in the submenu.
        let saved = defaults.stringArray(forKey: Self.commonBandsKey) ?? Self.defaultCommonBands
        let selected = Set(saved.map { $0.lowercased() })
        commonBands = Self.allBands.filter { selected.contains($0) }
    }

    var otherBands: [String] {
        Self.allBands.filter { !commonBands.contains($0) }
    }

    func isCommon(_ band: String) -> Bool {
        commonBands.contains(band.lowercased())
    }

    func setCommon(_ common: Bool, for band: String) {
        let name = band.lowercased()
        guard Self.allBands.contains(name) else { return }
        var selected = Set(commonBands)
        if common {
            selected.insert(name)
        } else {
            selected.remove(name)
        }
        commonBands = Self.allBands.filter { selected.contains($0) }
        defaults.set(commonBands, forKey: Self.commonBandsKey)
    }

    func resetCommonBands() {
        commonBands = Self.defaultCommonBands
        defaults.removeObject(forKey: Self.commonBandsKey)
    }

    static func bandForFrequency(_ frequencyMHz: Double) -> String? {
        guard frequencyMHz.isFinite else { return nil }
        return bands.first { $0.rangeMHz.contains(frequencyMHz) }?.name
    }
}
