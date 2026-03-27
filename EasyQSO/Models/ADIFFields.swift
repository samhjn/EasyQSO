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

// MARK: - ADIF Field Category

enum ADIFFieldCategory: String, CaseIterable, Identifiable {
    case basic = "adif_cat_basic"
    case signal = "adif_cat_signal"
    case technical = "adif_cat_technical"
    case ownStation = "adif_cat_own_station"
    case contactedStation = "adif_cat_contacted_station"
    case contactedOp = "adif_cat_contacted_op"
    case satellite = "adif_cat_satellite"
    case contest = "adif_cat_contest"
    case qsl = "adif_cat_qsl"
    case onlineServices = "adif_cat_online_services"
    case awards = "adif_cat_awards"
    case propagation = "adif_cat_propagation"
    case notes = "adif_cat_notes"
    
    var id: String { rawValue }
    
    var displayName: String {
        rawValue.localized
    }
    
    var sortOrder: Int {
        switch self {
        case .basic: return 0
        case .signal: return 1
        case .technical: return 2
        case .ownStation: return 3
        case .contactedStation: return 4
        case .contactedOp: return 5
        case .satellite: return 6
        case .contest: return 7
        case .qsl: return 8
        case .onlineServices: return 9
        case .awards: return 10
        case .propagation: return 11
        case .notes: return 12
        }
    }
}

// MARK: - Field Visibility

enum ADIFFieldVisibility: String, Codable, CaseIterable {
    case visible
    case collapsed
    case hidden
    
    var displayName: String {
        "adif_vis_\(rawValue)".localized
    }
    
    var iconName: String {
        switch self {
        case .visible: return "eye"
        case .collapsed: return "eye.trianglebadge.exclamationmark"
        case .hidden: return "eye.slash"
        }
    }
}

// MARK: - ADIF Field Definition

struct ADIFFieldDef: Identifiable, Hashable {
    let id: String
    let category: ADIFFieldCategory
    let coreProperty: String?
    let isRequired: Bool
    let defaultVisible: Bool
    
    var displayName: String {
        "adif_field_\(id.lowercased())".localized
    }
    
    var isCore: Bool { coreProperty != nil }
    var isExtended: Bool { coreProperty == nil }
    
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: ADIFFieldDef, rhs: ADIFFieldDef) -> Bool { lhs.id == rhs.id }
}

// MARK: - Field Group (bundled UI controls → multiple ADIF fields)

struct ADIFFieldGroup: Identifiable, Hashable {
    let id: String
    let memberFieldIds: [String]
    let category: ADIFFieldCategory
    let supportsCollapsed: Bool
    
    var displayName: String {
        "adif_\(id)".localized
    }
    
    var hasRequiredMembers: Bool {
        memberFieldIds.contains { id in
            ADIFFields.field(for: id)?.isRequired == true
        }
    }
    
    var defaultVisible: Bool {
        memberFieldIds.contains { id in
            ADIFFields.field(for: id)?.defaultVisible == true
        }
    }
    
    var allowedVisibilities: [ADIFFieldVisibility] {
        if hasRequiredMembers {
            return supportsCollapsed ? [.visible, .collapsed] : [.visible]
        }
        return supportsCollapsed ? ADIFFieldVisibility.allCases : [.visible, .hidden]
    }
    
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: ADIFFieldGroup, rhs: ADIFFieldGroup) -> Bool { lhs.id == rhs.id }
}

// MARK: - All ADIF 3.1.7 QSO Fields

struct ADIFFields {
    
    private static func f(_ id: String, _ cat: ADIFFieldCategory,
                          core: String? = nil, req: Bool = false, vis: Bool = false) -> ADIFFieldDef {
        ADIFFieldDef(id: id, category: cat,
                     coreProperty: core, isRequired: req, defaultVisible: vis)
    }
    
    static let all: [ADIFFieldDef] = [
        // ═══════════════ Basic Information ═══════════════
        f("CALL",         .basic, core: "callsign", req: true, vis: true),
        f("QSO_DATE",     .basic, core: "date",      req: true, vis: true),
        f("TIME_ON",      .basic, core: "date",      req: true, vis: true),
        f("BAND",         .basic, core: "band",      req: true, vis: true),
        f("MODE",         .basic, core: "mode",      req: true, vis: true),
        f("FREQ",         .basic, core: "frequencyHz", vis: true),
        f("SUBMODE",      .basic),
        f("TIME_OFF",     .basic),
        f("QSO_DATE_OFF", .basic),
        
        // ═══════════════ Signal Report ═══════════════
        f("RST_SENT",     .signal, core: "rstSent",     req: true, vis: true),
        f("RST_RCVD",     .signal, core: "rstReceived", req: true, vis: true),
        
        // ═══════════════ Technical ═══════════════
        f("FREQ_RX",      .technical, core: "rxFrequencyHz", vis: true),
        f("TX_PWR",       .technical, core: "txPower",       vis: true),
        f("RX_PWR",       .technical),
        f("BAND_RX",      .technical),
        f("ANT_AZ",       .technical),
        f("ANT_EL",       .technical),
        f("ANT_PATH",     .technical),
        f("PROP_MODE",    .technical),
        f("DISTANCE",     .technical),
        f("RIG",          .technical),
        f("MY_RIG",       .technical),
        f("MY_ANTENNA",   .technical),
        f("MY_ALTITUDE",  .technical),
        
        // ═══════════════ Own Station ═══════════════
        f("STATION_CALLSIGN", .ownStation),
        f("OPERATOR",         .ownStation),
        f("OWNER_CALLSIGN",   .ownStation),
        f("MY_NAME",          .ownStation),
        f("MY_CITY",          .ownStation, vis: true),
        f("MY_COUNTRY",       .ownStation),
        f("MY_STATE",         .ownStation),
        f("MY_CNTY",          .ownStation),
        f("MY_GRIDSQUARE",    .ownStation, vis: true),
        f("MY_GRIDSQUARE_EXT",.ownStation),
        f("MY_CQ_ZONE",       .ownStation, vis: true),
        f("MY_ITU_ZONE",      .ownStation, vis: true),
        f("MY_LAT",           .ownStation),
        f("MY_LON",           .ownStation),
        f("MY_DXCC",          .ownStation),
        f("MY_POSTAL_CODE",   .ownStation),
        f("MY_STREET",        .ownStation),
        f("MY_ARRL_SECT",     .ownStation),
        f("MY_CNTY_ALT",      .ownStation),
        f("MY_DARC_DOK",      .ownStation),
        f("MY_FISTS",         .ownStation),
        f("MY_IOTA",          .ownStation),
        f("MY_IOTA_ISLAND_ID",.ownStation),
        f("MY_POTA_REF",      .ownStation),
        f("MY_SOTA_REF",      .ownStation),
        f("MY_WWFF_REF",      .ownStation),
        f("MY_SIG",           .ownStation),
        f("MY_SIG_INFO",      .ownStation),
        f("MY_USACA_COUNTIES",.ownStation),
        f("MY_VUCC_GRIDS",    .ownStation),
        f("MY_MORSE_KEY_INFO",.ownStation),
        f("MY_MORSE_KEY_TYPE",.ownStation),
        
        // ═══════════════ Contacted Station ═══════════════
        f("QTH",           .contactedStation, core: "qth", vis: true),
        f("GRIDSQUARE",    .contactedStation, core: "gridSquare", vis: true),
        f("CQZ",           .contactedStation, core: "cqZone", vis: true),
        f("ITUZ",          .contactedStation, core: "ituZone", vis: true),
        f("LAT",           .contactedStation, core: "latitude"),
        f("LON",           .contactedStation, core: "longitude"),
        f("GRIDSQUARE_EXT",.contactedStation),
        f("COUNTRY",       .contactedStation),
        f("STATE",         .contactedStation),
        f("CNTY",          .contactedStation),
        f("CNTY_ALT",      .contactedStation),
        f("DXCC",          .contactedStation),
        f("CONT",          .contactedStation),
        f("REGION",        .contactedStation),
        f("PFX",           .contactedStation),
        f("ALTITUDE",      .contactedStation),
        f("ADDRESS",       .contactedStation),
        f("USACA_COUNTIES",.contactedStation),
        f("VUCC_GRIDS",    .contactedStation),
        
        // ═══════════════ Contacted Operator ═══════════════
        f("NAME",          .contactedOp, core: "name", vis: true),
        f("AGE",           .contactedOp),
        f("EMAIL",         .contactedOp),
        f("WEB",           .contactedOp),
        f("CONTACTED_OP",  .contactedOp),
        f("EQ_CALL",       .contactedOp),
        f("SILENT_KEY",    .contactedOp),
        f("FISTS",         .contactedOp),
        f("FISTS_CC",      .contactedOp),
        f("SKCC",          .contactedOp),
        f("TEN_TEN",       .contactedOp),
        f("UKSMG",         .contactedOp),
        f("DARC_DOK",      .contactedOp),
        f("MORSE_KEY_INFO",.contactedOp),
        f("MORSE_KEY_TYPE",.contactedOp),
        
        // ═══════════════ Satellite ═══════════════
        f("SAT_NAME",     .satellite, core: "satellite", vis: true),
        f("SAT_MODE",     .satellite),
        
        // ═══════════════ Contest ═══════════════
        f("CONTEST_ID",   .contest),
        f("CHECK",        .contest),
        f("CLASS",        .contest),
        f("PRECEDENCE",   .contest),
        f("SRX",          .contest),
        f("SRX_STRING",   .contest),
        f("STX",          .contest),
        f("STX_STRING",   .contest),
        f("QSO_COMPLETE", .contest),
        f("QSO_RANDOM",   .contest),
        f("SWL",          .contest),
        f("ARRL_SECT",    .contest),
        
        // ═══════════════ QSL ═══════════════
        f("QSL_SENT",       .qsl),
        f("QSL_RCVD",       .qsl),
        f("QSLSDATE",       .qsl),
        f("QSLRDATE",       .qsl),
        f("QSL_SENT_VIA",   .qsl),
        f("QSL_RCVD_VIA",   .qsl),
        f("QSL_VIA",        .qsl),
        f("QSLMSG",         .qsl),
        f("QSLMSG_RCVD",    .qsl),
        f("EQSL_QSL_SENT",  .qsl),
        f("EQSL_QSL_RCVD",  .qsl),
        f("EQSL_QSLSDATE",  .qsl),
        f("EQSL_QSLRDATE",  .qsl),
        f("EQSL_AG",        .qsl),
        f("LOTW_QSL_SENT",  .qsl),
        f("LOTW_QSL_RCVD",  .qsl),
        f("LOTW_QSLSDATE",  .qsl),
        f("LOTW_QSLRDATE",  .qsl),
        f("DCL_QSL_SENT",   .qsl),
        f("DCL_QSL_RCVD",   .qsl),
        f("DCL_QSLSDATE",   .qsl),
        f("DCL_QSLRDATE",   .qsl),
        
        // ═══════════════ Online Services ═══════════════
        f("CLUBLOG_QSO_UPLOAD_DATE",   .onlineServices),
        f("CLUBLOG_QSO_UPLOAD_STATUS", .onlineServices),
        f("HAMLOGEU_QSO_UPLOAD_DATE",  .onlineServices),
        f("HAMLOGEU_QSO_UPLOAD_STATUS",.onlineServices),
        f("HAMQTH_QSO_UPLOAD_DATE",    .onlineServices),
        f("HAMQTH_QSO_UPLOAD_STATUS",  .onlineServices),
        f("HRDLOG_QSO_UPLOAD_DATE",    .onlineServices),
        f("HRDLOG_QSO_UPLOAD_STATUS",  .onlineServices),
        f("QRZCOM_QSO_UPLOAD_DATE",    .onlineServices),
        f("QRZCOM_QSO_UPLOAD_STATUS",  .onlineServices),
        f("QRZCOM_QSO_DOWNLOAD_DATE",  .onlineServices),
        f("QRZCOM_QSO_DOWNLOAD_STATUS",.onlineServices),
        
        // ═══════════════ Awards & Memberships ═══════════════
        f("IOTA",           .awards),
        f("IOTA_ISLAND_ID", .awards),
        f("SOTA_REF",       .awards),
        f("POTA_REF",       .awards),
        f("WWFF_REF",       .awards),
        f("SIG",            .awards),
        f("SIG_INFO",       .awards),
        f("AWARD_SUBMITTED",.awards),
        f("AWARD_GRANTED",  .awards),
        f("CREDIT_SUBMITTED",.awards),
        f("CREDIT_GRANTED", .awards),
        
        // ═══════════════ Propagation & Conditions ═══════════════
        f("A_INDEX",       .propagation),
        f("K_INDEX",       .propagation),
        f("SFI",           .propagation),
        f("MAX_BURSTS",    .propagation),
        f("NR_BURSTS",     .propagation),
        f("NR_PINGS",      .propagation),
        f("MS_SHOWER",     .propagation),
        f("FORCE_INIT",    .propagation),
        
        // ═══════════════ Notes & Comments ═══════════════
        f("COMMENT",       .notes, core: "remarks", vis: true),
        f("NOTES",         .notes),
        f("PUBLIC_KEY",    .notes),
    ]
    
    // MARK: - Lookup helpers
    
    static let byId: [String: ADIFFieldDef] = {
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    }()
    
    static let byCategory: [ADIFFieldCategory: [ADIFFieldDef]] = {
        Dictionary(grouping: all, by: { $0.category })
    }()
    
    static let coreFields: [ADIFFieldDef] = all.filter { $0.isCore }
    static let extendedFields: [ADIFFieldDef] = all.filter { $0.isExtended }
    static let requiredFields: [ADIFFieldDef] = all.filter { $0.isRequired }
    static let defaultVisibleFields: [ADIFFieldDef] = all.filter { $0.defaultVisible }
    
    static func field(for tag: String) -> ADIFFieldDef? {
        byId[tag.uppercased()]
    }
    
    static func fieldsForCategory(_ category: ADIFFieldCategory) -> [ADIFFieldDef] {
        byCategory[category] ?? []
    }
    
    static let sortedCategories: [ADIFFieldCategory] = {
        ADIFFieldCategory.allCases.sorted { $0.sortOrder < $1.sortOrder }
    }()
    
    // MARK: - Field Groups
    
    static let fieldGroups: [ADIFFieldGroup] = [
        ADIFFieldGroup(
            id: "group_datetime",
            memberFieldIds: ["QSO_DATE", "TIME_ON"],
            category: .basic, supportsCollapsed: true
        ),
        ADIFFieldGroup(
            id: "group_end_datetime",
            memberFieldIds: ["TIME_OFF", "QSO_DATE_OFF"],
            category: .basic, supportsCollapsed: true
        ),
        ADIFFieldGroup(
            id: "group_contacted_qth",
            memberFieldIds: ["QTH", "GRIDSQUARE", "CQZ", "ITUZ", "LAT", "LON"],
            category: .contactedStation, supportsCollapsed: true
        ),
        ADIFFieldGroup(
            id: "group_own_qth",
            memberFieldIds: ["MY_CITY", "MY_GRIDSQUARE", "MY_CQ_ZONE", "MY_ITU_ZONE", "MY_LAT", "MY_LON"],
            category: .ownStation, supportsCollapsed: true
        ),
    ]
    
    static let fieldIdToGroup: [String: ADIFFieldGroup] = {
        var map: [String: ADIFFieldGroup] = [:]
        for group in fieldGroups {
            for fieldId in group.memberFieldIds {
                map[fieldId] = group
            }
        }
        return map
    }()
    
    static func group(for fieldId: String) -> ADIFFieldGroup? {
        fieldIdToGroup[fieldId]
    }
    
    static let groupedFieldIds: Set<String> = {
        Set(fieldGroups.flatMap { $0.memberFieldIds })
    }()
    
    static let groupsByCategory: [ADIFFieldCategory: [ADIFFieldGroup]] = {
        Dictionary(grouping: fieldGroups, by: { $0.category })
    }()
    
    static func groupsForCategory(_ category: ADIFFieldCategory) -> [ADIFFieldGroup] {
        groupsByCategory[category] ?? []
    }
    
    /// All known ADIF tags (for lossless import - includes _INTL variants)
    static let allKnownTags: Set<String> = {
        var tags = Set(all.map { $0.id })
        let intlVariants = [
            "ADDRESS_INTL", "COMMENT_INTL", "COUNTRY_INTL", "MY_ANTENNA_INTL",
            "MY_CITY_INTL", "MY_COUNTRY_INTL", "MY_NAME_INTL", "MY_POSTAL_CODE_INTL",
            "MY_RIG_INTL", "MY_SIG_INTL", "MY_SIG_INFO_INTL", "MY_STREET_INTL",
            "NAME_INTL", "NOTES_INTL", "QTH_INTL", "QSLMSG_INTL", "RIG_INTL",
            "SIG_INTL", "SIG_INFO_INTL"
        ]
        tags.formUnion(intlVariants)
        tags.insert("GUEST_OP")
        tags.insert("VE_PROV")
        return tags
    }()
}
