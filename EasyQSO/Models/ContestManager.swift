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

// MARK: - Contest Picker Item

struct ContestPickerItem: Identifiable, Equatable {
    let id: String
    let contestId: String
    let displayLabel: String
}

// MARK: - ContestManager

class ContestManager: ObservableObject {
    static let shared = ContestManager()

    @Published private(set) var revision = 0

    private static let customKey = "CustomContests"
    private static let hiddenKey = "HiddenContests"

    private init() {}

    // MARK: - ADIF 3.1.7 CONTEST_ID enumeration (commonly used contests)

    static let presetContests: [(id: String, description: String)] = [
        // ARRL Contests
        ("ARRL-10",            "ARRL 10 Meter Contest"),
        ("ARRL-160",           "ARRL 160 Meter Contest"),
        ("ARRL-DX-CW",         "ARRL International DX Contest (CW)"),
        ("ARRL-DX-SSB",        "ARRL International DX Contest (SSB)"),
        ("ARRL-EME",           "ARRL EME Contest"),
        ("ARRL-FIELD-DAY",     "ARRL Field Day"),
        ("ARRL-RR-CW",         "ARRL Rookie Roundup CW"),
        ("ARRL-RR-RTTY",       "ARRL Rookie Roundup RTTY"),
        ("ARRL-RR-SSB",        "ARRL Rookie Roundup SSB"),
        ("ARRL-RTTY",          "ARRL RTTY Roundup"),
        ("ARRL-SCR",           "ARRL School Club Roundup"),
        ("ARRL-SS-CW",         "ARRL Sweepstakes (CW)"),
        ("ARRL-SS-SSB",        "ARRL Sweepstakes (SSB)"),
        ("ARRL-UHF-AUG",       "ARRL August UHF Contest"),
        ("ARRL-VHF-JAN",       "ARRL January VHF Sweepstakes"),
        ("ARRL-VHF-JUN",       "ARRL June VHF Contest"),
        ("ARRL-VHF-SEP",       "ARRL September VHF Contest"),

        // CQ Contests
        ("CQ-160-CW",          "CQ WW 160 Meter Contest (CW)"),
        ("CQ-160-SSB",         "CQ WW 160 Meter Contest (SSB)"),
        ("CQ-WPX-CW",          "CQ WPX Contest (CW)"),
        ("CQ-WPX-SSB",         "CQ WPX Contest (SSB)"),
        ("CQ-WPX-RTTY",        "CQ WPX RTTY Contest"),
        ("CQ-WW-CW",           "CQ World Wide DX Contest (CW)"),
        ("CQ-WW-RTTY",         "CQ World Wide RTTY DX Contest"),
        ("CQ-WW-SSB",          "CQ World Wide DX Contest (SSB)"),
        ("CQ-VHF",             "CQ World Wide VHF Contest"),

        // IARU
        ("IARU-HF",            "IARU HF World Championship"),

        // Regional & National Contests
        ("ALL-ASIAN-CW",       "All Asian DX Contest (CW)"),
        ("ALL-ASIAN-SSB",      "All Asian DX Contest (SSB)"),
        ("AP-SPRINT",          "Asia-Pacific Sprint"),
        ("BALTIC-CONT",        "Baltic Contest"),
        ("BARTG-RTTY",         "BARTG Spring RTTY Contest"),
        ("CQMM",               "CQ Manchester Mineira"),
        ("CW-OPS",             "CWops Mini-CWT"),
        ("DARC-WAEDC-CW",      "DARC WAE DX Contest (CW)"),
        ("DARC-WAEDC-RTTY",    "DARC WAE DX Contest (RTTY)"),
        ("DARC-WAEDC-SSB",     "DARC WAE DX Contest (SSB)"),
        ("EA-CNCW",            "EA Concurso Nacional CW"),
        ("FCG-FQP",            "Florida QSO Party"),
        ("HA-DX",              "Hungarian DX Contest"),
        ("HELVETIA",           "Helvetia Contest"),
        ("JARTS-WW-RTTY",      "JARTS WW RTTY Contest"),
        ("JIDX-CW",            "JIDX CW Contest"),
        ("JIDX-SSB",           "JIDX SSB Contest"),
        ("NAQP-CW",            "North American QSO Party (CW)"),
        ("NAQP-RTTY",          "North American QSO Party (RTTY)"),
        ("NAQP-SSB",           "North American QSO Party (SSB)"),
        ("OCEANIA-DX-CW",      "Oceania DX Contest (CW)"),
        ("OCEANIA-DX-SSB",     "Oceania DX Contest (SSB)"),
        ("RAC-CANADA-DAY",     "RAC Canada Day Contest"),
        ("RAC-CANADA-WINTER",  "RAC Canada Winter Contest"),
        ("RDXC",               "Russian DX Contest"),
        ("REF-CW",             "REF Contest (CW)"),
        ("REF-SSB",            "REF Contest (SSB)"),
        ("SAC-CW",             "Scandinavian Activity Contest (CW)"),
        ("SAC-SSB",            "Scandinavian Activity Contest (SSB)"),
        ("SPDX-RTTY",          "SP DX RTTY Contest"),
        ("STEW-PERRY",         "Stew Perry Topband Distance Challenge"),
        ("TARA-RTTY",          "TARA RTTY Melee"),
        ("UBA-DX-CW",          "UBA DX Contest (CW)"),
        ("UBA-DX-SSB",         "UBA DX Contest (SSB)"),
        ("UKEIDX-CW",          "UK/EI DX Contest (CW)"),
        ("UKEIDX-SSB",         "UK/EI DX Contest (SSB)"),

        // Portable / Field / Activation
        ("POTA",               "Parks on the Air"),
        ("SOTA",               "Summits on the Air"),
        ("WWFF",               "World Wide Flora & Fauna"),
        ("IOTA",               "Islands on the Air Contest"),
        ("VK-SHIRES",          "VK Shires Contest"),

        // Digital mode contests
        ("FT-ROUNDUP",         "FT Roundup"),
        ("MAKROTHEN-RTTY",     "Makrothen RTTY Contest"),
        ("VOLTA-RTTY",         "Alessandro Volta RTTY DX Contest"),

        // Other popular contests
        ("CQIR",               "CQ-IRC"),
        ("DRCG-WW-RTTY",       "DRCG WW RTTY Contest"),
        ("HOLYLAND",           "Holyland DX Contest"),
        ("KING-OF-SPAIN-CW",   "King of Spain Contest (CW)"),
        ("KING-OF-SPAIN-SSB",  "King of Spain Contest (SSB)"),
        ("PACC",               "PACC Contest"),
        ("RSGB-IOTA",          "RSGB IOTA Contest"),
        ("WAG",                "Worked All Germany Contest"),
        ("YO-DX-HF",           "YO DX HF Contest"),
    ]

    /// All preset contest IDs
    static let allPresetIds: [String] = presetContests.map(\.id)

    /// Lookup: contest ID → description
    static let presetIdToDescription: [String: String] = {
        var map = [String: String]()
        for contest in presetContests {
            map[contest.id.uppercased()] = contest.description
        }
        return map
    }()

    // MARK: - User preferences

    var customContests: [String] {
        UserDefaults.standard.stringArray(forKey: Self.customKey) ?? []
    }

    var hiddenContests: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: Self.hiddenKey) ?? [])
    }

    var allKnownContests: [String] {
        var contests = Self.allPresetIds
        for custom in customContests {
            if !contests.contains(where: { $0.uppercased() == custom.uppercased() }) {
                contests.append(custom)
            }
        }
        return contests
    }

    var enabledContests: [String] {
        let hidden = hiddenContests
        return allKnownContests.filter { !hidden.contains($0.uppercased()) }
    }

    func pickerItems(current: String) -> [ContestPickerItem] {
        var items: [ContestPickerItem] = []
        let enabled = enabledContests

        for contest in enabled {
            items.append(ContestPickerItem(
                id: contest.uppercased(),
                contestId: contest,
                displayLabel: contest
            ))
        }

        // Ensure current value is in the list
        if !current.isEmpty && !items.contains(where: { $0.contestId.uppercased() == current.uppercased() }) {
            items.append(ContestPickerItem(
                id: current.uppercased(),
                contestId: current,
                displayLabel: current
            ))
        }

        return items
    }

    // MARK: - Custom/Hidden contest management

    func addCustomContest(_ contest: String) {
        let id = contest.uppercased().trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty else { return }
        var contests = customContests
        guard !Self.allPresetIds.contains(where: { $0.uppercased() == id }) &&
              !contests.contains(where: { $0.uppercased() == id }) else { return }
        contests.append(id)
        UserDefaults.standard.set(contests, forKey: Self.customKey)
        objectWillChange.send()
        revision += 1
    }

    func removeCustomContest(_ contest: String) {
        var contests = customContests
        contests.removeAll { $0.uppercased() == contest.uppercased() }
        UserDefaults.standard.set(contests, forKey: Self.customKey)
        var hidden = hiddenContests
        hidden.remove(contest.uppercased())
        UserDefaults.standard.set(Array(hidden), forKey: Self.hiddenKey)
        objectWillChange.send()
        revision += 1
    }

    func setHidden(_ hidden: Bool, for contest: String) {
        var set = hiddenContests
        if hidden { set.insert(contest.uppercased()) } else { set.remove(contest.uppercased()) }
        UserDefaults.standard.set(Array(set), forKey: Self.hiddenKey)
        objectWillChange.send()
        revision += 1
    }

    func isHidden(_ contest: String) -> Bool {
        hiddenContests.contains(contest.uppercased())
    }

    func isCustom(_ contest: String) -> Bool {
        customContests.contains(where: { $0.uppercased() == contest.uppercased() })
    }

    func isPreset(_ contest: String) -> Bool {
        Self.allPresetIds.contains(where: { $0.uppercased() == contest.uppercased() })
    }

    /// Description for a contest ID (preset only)
    static func description(for id: String) -> String? {
        presetIdToDescription[id.uppercased()]
    }

    /// Enabled item count (for settings display)
    var enabledItemCount: Int {
        enabledContests.count
    }
}
