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
    
    var displayNameEN: String {
        switch self {
        case .basic: return "Basic Information"
        case .signal: return "Signal Report"
        case .technical: return "Technical"
        case .ownStation: return "Own Station"
        case .contactedStation: return "Contacted Station"
        case .contactedOp: return "Contacted Operator"
        case .satellite: return "Satellite"
        case .contest: return "Contest"
        case .qsl: return "QSL"
        case .onlineServices: return "Online Services"
        case .awards: return "Awards & Memberships"
        case .propagation: return "Propagation & Conditions"
        case .notes: return "Notes & Comments"
        }
    }
    
    var displayNameZH: String {
        switch self {
        case .basic: return "基本信息"
        case .signal: return "信号报告"
        case .technical: return "技术信息"
        case .ownStation: return "己方电台"
        case .contactedStation: return "对方电台"
        case .contactedOp: return "对方操作员"
        case .satellite: return "卫星"
        case .contest: return "竞赛"
        case .qsl: return "QSL"
        case .onlineServices: return "在线服务"
        case .awards: return "奖项与会员"
        case .propagation: return "传播与条件"
        case .notes: return "备注与注释"
        }
    }
    
    var displayName: String {
        let lang = Locale.preferredLanguages.first ?? "en"
        return lang.hasPrefix("zh") ? displayNameZH : displayNameEN
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
    
    var displayNameEN: String {
        switch self {
        case .visible: return "Visible"
        case .collapsed: return "Collapsed"
        case .hidden: return "Hidden"
        }
    }
    
    var displayNameZH: String {
        switch self {
        case .visible: return "显示"
        case .collapsed: return "折叠"
        case .hidden: return "隐藏"
        }
    }
    
    var displayName: String {
        let lang = Locale.preferredLanguages.first ?? "en"
        return lang.hasPrefix("zh") ? displayNameZH : displayNameEN
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
    let nameEN: String
    let nameZH: String
    let category: ADIFFieldCategory
    let coreProperty: String?
    let isRequired: Bool
    let defaultVisible: Bool
    
    var displayName: String {
        let lang = Locale.preferredLanguages.first ?? "en"
        return lang.hasPrefix("zh") ? nameZH : nameEN
    }
    
    var isCore: Bool { coreProperty != nil }
    var isExtended: Bool { coreProperty == nil }
    
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: ADIFFieldDef, rhs: ADIFFieldDef) -> Bool { lhs.id == rhs.id }
}

// MARK: - Field Group (bundled UI controls → multiple ADIF fields)

struct ADIFFieldGroup: Identifiable, Hashable {
    let id: String
    let nameEN: String
    let nameZH: String
    let memberFieldIds: [String]
    let category: ADIFFieldCategory
    let supportsCollapsed: Bool
    
    var displayName: String {
        let lang = Locale.preferredLanguages.first ?? "en"
        return lang.hasPrefix("zh") ? nameZH : nameEN
    }
    
    var hasRequiredMembers: Bool {
        memberFieldIds.contains { id in
            ADIFFields.field(for: id)?.isRequired == true
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
    
    private static func f(_ id: String, _ en: String, _ zh: String, _ cat: ADIFFieldCategory,
                          core: String? = nil, req: Bool = false, vis: Bool = false) -> ADIFFieldDef {
        ADIFFieldDef(id: id, nameEN: en, nameZH: zh, category: cat,
                     coreProperty: core, isRequired: req, defaultVisible: vis)
    }
    
    static let all: [ADIFFieldDef] = [
        // ═══════════════ Basic Information ═══════════════
        f("CALL",         "Callsign",           "通联呼号",     .basic, core: "callsign", req: true, vis: true),
        f("QSO_DATE",     "QSO Date",           "通联日期",     .basic, core: "date",      req: true, vis: true),
        f("TIME_ON",      "Time On",            "开始时间",     .basic, core: "date",      req: true, vis: true),
        f("BAND",         "Band",               "波段",         .basic, core: "band",      req: true, vis: true),
        f("MODE",         "Mode",               "模式",         .basic, core: "mode",      req: true, vis: true),
        f("FREQ",         "Frequency (MHz)",    "频率 (MHz)",   .basic, core: "frequencyHz", vis: true),
        f("SUBMODE",      "Submode",            "子模式",       .basic),
        f("TIME_OFF",     "Time Off",           "结束时间",     .basic),
        f("QSO_DATE_OFF", "QSO Date Off",       "结束日期",     .basic),
        
        // ═══════════════ Signal Report ═══════════════
        f("RST_SENT",     "RST Sent",           "发出的RST",    .signal, core: "rstSent",     req: true, vis: true),
        f("RST_RCVD",     "RST Received",       "接收的RST",    .signal, core: "rstReceived", req: true, vis: true),
        
        // ═══════════════ Technical ═══════════════
        f("FREQ_RX",      "RX Frequency (MHz)", "接收频率 (MHz)", .technical, core: "rxFrequencyHz", vis: true),
        f("TX_PWR",       "TX Power (W)",       "发射功率 (W)",   .technical, core: "txPower",       vis: true),
        f("RX_PWR",       "RX Power (W)",       "接收功率 (W)",   .technical),
        f("BAND_RX",      "RX Band",            "接收波段",       .technical),
        f("ANT_AZ",       "Antenna Azimuth",    "天线方位角",     .technical),
        f("ANT_EL",       "Antenna Elevation",  "天线仰角",       .technical),
        f("ANT_PATH",     "Antenna Path",       "信号路径",       .technical),
        f("PROP_MODE",    "Propagation Mode",   "传播模式",       .technical),
        f("DISTANCE",     "Distance (km)",      "距离 (km)",      .technical),
        f("RIG",          "Rig (Contacted)",     "设备 (对方)",    .technical),
        f("MY_RIG",       "Rig (Own)",           "设备 (己方)",    .technical),
        f("MY_ANTENNA",   "Antenna (Own)",       "天线 (己方)",    .technical),
        f("MY_ALTITUDE",  "Altitude (Own, m)",   "海拔 (己方, m)", .technical),
        
        // ═══════════════ Own Station ═══════════════
        f("STATION_CALLSIGN", "Station Callsign",    "电台呼号",       .ownStation),
        f("OPERATOR",         "Operator",            "操作员",         .ownStation),
        f("OWNER_CALLSIGN",   "Owner Callsign",      "电台所有者呼号", .ownStation),
        f("MY_NAME",          "My Name",             "己方姓名",       .ownStation),
        f("MY_CITY",          "My City",             "己方城市",       .ownStation),
        f("MY_COUNTRY",       "My Country",          "己方国家",       .ownStation),
        f("MY_STATE",         "My State/Province",   "己方州/省",      .ownStation),
        f("MY_CNTY",          "My County",           "己方县/郡",      .ownStation),
        f("MY_GRIDSQUARE",    "My Grid Square",      "己方网格",       .ownStation),
        f("MY_GRIDSQUARE_EXT","My Grid Ext",         "己方网格扩展",   .ownStation),
        f("MY_CQ_ZONE",       "My CQ Zone",          "己方CQ Zone",    .ownStation),
        f("MY_ITU_ZONE",      "My ITU Zone",         "己方ITU Zone",   .ownStation),
        f("MY_LAT",           "My Latitude",         "己方纬度",       .ownStation),
        f("MY_LON",           "My Longitude",        "己方经度",       .ownStation),
        f("MY_DXCC",          "My DXCC",             "己方DXCC",       .ownStation),
        f("MY_POSTAL_CODE",   "My Postal Code",      "己方邮编",       .ownStation),
        f("MY_STREET",        "My Street",           "己方街道",       .ownStation),
        f("MY_ARRL_SECT",     "My ARRL Section",     "己方ARRL分区",   .ownStation),
        f("MY_CNTY_ALT",      "My County (Alt)",     "己方县(替代)",   .ownStation),
        f("MY_DARC_DOK",      "My DARC DOK",         "己方DARC DOK",   .ownStation),
        f("MY_FISTS",         "My FISTS #",          "己方FISTS编号",  .ownStation),
        f("MY_IOTA",          "My IOTA",             "己方IOTA",       .ownStation),
        f("MY_IOTA_ISLAND_ID","My IOTA Island ID",   "己方IOTA岛屿ID", .ownStation),
        f("MY_POTA_REF",      "My POTA Ref",         "己方POTA参考",   .ownStation),
        f("MY_SOTA_REF",      "My SOTA Ref",         "己方SOTA参考",   .ownStation),
        f("MY_WWFF_REF",      "My WWFF Ref",         "己方WWFF参考",   .ownStation),
        f("MY_SIG",           "My Special Interest",  "己方特殊活动",   .ownStation),
        f("MY_SIG_INFO",      "My SIG Info",          "己方活动信息",   .ownStation),
        f("MY_USACA_COUNTIES","My USACA Counties",    "己方USACA Counties", .ownStation),
        f("MY_VUCC_GRIDS",    "My VUCC Grids",        "己方VUCC网格",   .ownStation),
        f("MY_MORSE_KEY_INFO","My Morse Key Info",     "己方电键信息",   .ownStation),
        f("MY_MORSE_KEY_TYPE","My Morse Key Type",     "己方电键类型",   .ownStation),
        
        // ═══════════════ Contacted Station ═══════════════
        f("QTH",           "QTH",               "位置描述",     .contactedStation, core: "qth", vis: true),
        f("GRIDSQUARE",    "Grid Square",        "网格信息",     .contactedStation, core: "gridSquare", vis: true),
        f("CQZ",           "CQ Zone",            "CQ Zone",      .contactedStation, core: "cqZone", vis: true),
        f("ITUZ",          "ITU Zone",           "ITU Zone",     .contactedStation, core: "ituZone", vis: true),
        f("LAT",           "Latitude",           "纬度",         .contactedStation, core: "latitude"),
        f("LON",           "Longitude",          "经度",         .contactedStation, core: "longitude"),
        f("GRIDSQUARE_EXT","Grid Square Ext",    "网格扩展",     .contactedStation),
        f("COUNTRY",       "Country",            "国家",         .contactedStation),
        f("STATE",         "State/Province",     "州/省",        .contactedStation),
        f("CNTY",          "County",             "县/郡",        .contactedStation),
        f("CNTY_ALT",      "County (Alt)",       "县(替代)",     .contactedStation),
        f("DXCC",          "DXCC Entity",        "DXCC实体",     .contactedStation),
        f("CONT",          "Continent",          "大洲",         .contactedStation),
        f("REGION",        "Region",             "区域",         .contactedStation),
        f("PFX",           "WPX Prefix",         "WPX前缀",     .contactedStation),
        f("ALTITUDE",      "Altitude (m)",       "海拔 (m)",     .contactedStation),
        f("ADDRESS",       "Address",            "地址",         .contactedStation),
        f("USACA_COUNTIES","USACA Counties",     "USACA Counties", .contactedStation),
        f("VUCC_GRIDS",    "VUCC Grids",         "VUCC网格",     .contactedStation),
        
        // ═══════════════ Contacted Operator ═══════════════
        f("NAME",          "Name",               "姓名",         .contactedOp, core: "name", vis: true),
        f("AGE",           "Age",                "年龄",         .contactedOp),
        f("EMAIL",         "Email",              "邮箱",         .contactedOp),
        f("WEB",           "Website",            "网站",         .contactedOp),
        f("CONTACTED_OP",  "Contacted Operator", "对方操作员",   .contactedOp),
        f("EQ_CALL",       "Owner Callsign",     "对方所有者呼号", .contactedOp),
        f("SILENT_KEY",    "Silent Key",         "静默电键(SK)", .contactedOp),
        f("FISTS",         "FISTS #",            "FISTS编号",    .contactedOp),
        f("FISTS_CC",      "FISTS CC #",         "FISTS CC编号", .contactedOp),
        f("SKCC",          "SKCC",               "SKCC",         .contactedOp),
        f("TEN_TEN",       "Ten-Ten #",          "Ten-Ten编号",  .contactedOp),
        f("UKSMG",         "UKSMG #",            "UKSMG编号",    .contactedOp),
        f("DARC_DOK",      "DARC DOK",           "DARC DOK",     .contactedOp),
        f("MORSE_KEY_INFO","Morse Key Info",      "电键信息",     .contactedOp),
        f("MORSE_KEY_TYPE","Morse Key Type",      "电键类型",     .contactedOp),
        
        // ═══════════════ Satellite ═══════════════
        f("SAT_NAME",     "Satellite Name",      "卫星名称",     .satellite, core: "satellite", vis: true),
        f("SAT_MODE",     "Satellite Mode",      "卫星模式",     .satellite),
        
        // ═══════════════ Contest ═══════════════
        f("CONTEST_ID",   "Contest ID",          "竞赛ID",       .contest),
        f("CHECK",        "Check",               "检查号",       .contest),
        f("CLASS",        "Class",               "组别",         .contest),
        f("PRECEDENCE",   "Precedence",          "优先级",       .contest),
        f("SRX",          "Serial # Received",   "接收序号",     .contest),
        f("SRX_STRING",   "Serial String Rcvd",  "接收序号字符串", .contest),
        f("STX",          "Serial # Sent",       "发送序号",     .contest),
        f("STX_STRING",   "Serial String Sent",  "发送序号字符串", .contest),
        f("QSO_COMPLETE", "QSO Complete",        "通联完整性",   .contest),
        f("QSO_RANDOM",   "QSO Random",          "随机通联",     .contest),
        f("SWL",          "SWL",                 "短波收听",     .contest),
        f("ARRL_SECT",    "ARRL Section",        "ARRL分区",     .contest),
        
        // ═══════════════ QSL ═══════════════
        f("QSL_SENT",       "QSL Sent",           "QSL已发送",      .qsl),
        f("QSL_RCVD",       "QSL Received",       "QSL已接收",      .qsl),
        f("QSLSDATE",       "QSL Sent Date",      "QSL发送日期",    .qsl),
        f("QSLRDATE",       "QSL Received Date",  "QSL接收日期",    .qsl),
        f("QSL_SENT_VIA",   "QSL Sent Via",       "QSL发送方式",    .qsl),
        f("QSL_RCVD_VIA",   "QSL Received Via",   "QSL接收方式",    .qsl),
        f("QSL_VIA",        "QSL Via",            "QSL路由",        .qsl),
        f("QSLMSG",         "QSL Message",        "QSL消息",        .qsl),
        f("QSLMSG_RCVD",    "QSL Message Rcvd",   "QSL收到的消息",  .qsl),
        f("EQSL_QSL_SENT",  "eQSL Sent",          "eQSL已发送",     .qsl),
        f("EQSL_QSL_RCVD",  "eQSL Received",      "eQSL已接收",     .qsl),
        f("EQSL_QSLSDATE",  "eQSL Sent Date",     "eQSL发送日期",   .qsl),
        f("EQSL_QSLRDATE",  "eQSL Rcvd Date",     "eQSL接收日期",   .qsl),
        f("EQSL_AG",        "eQSL AG",            "eQSL认证",       .qsl),
        f("LOTW_QSL_SENT",  "LoTW Sent",          "LoTW已发送",     .qsl),
        f("LOTW_QSL_RCVD",  "LoTW Received",      "LoTW已接收",     .qsl),
        f("LOTW_QSLSDATE",  "LoTW Sent Date",     "LoTW发送日期",   .qsl),
        f("LOTW_QSLRDATE",  "LoTW Rcvd Date",     "LoTW接收日期",   .qsl),
        f("DCL_QSL_SENT",   "DCL Sent",           "DCL已发送",      .qsl),
        f("DCL_QSL_RCVD",   "DCL Received",       "DCL已接收",      .qsl),
        f("DCL_QSLSDATE",   "DCL Sent Date",      "DCL发送日期",    .qsl),
        f("DCL_QSLRDATE",   "DCL Rcvd Date",      "DCL接收日期",    .qsl),
        
        // ═══════════════ Online Services ═══════════════
        f("CLUBLOG_QSO_UPLOAD_DATE",   "Club Log Upload Date",   "Club Log上传日期",   .onlineServices),
        f("CLUBLOG_QSO_UPLOAD_STATUS", "Club Log Upload Status", "Club Log上传状态",   .onlineServices),
        f("HAMLOGEU_QSO_UPLOAD_DATE",  "HAMLOG.EU Upload Date",  "HAMLOG.EU上传日期",  .onlineServices),
        f("HAMLOGEU_QSO_UPLOAD_STATUS","HAMLOG.EU Upload Status", "HAMLOG.EU上传状态", .onlineServices),
        f("HAMQTH_QSO_UPLOAD_DATE",    "HamQTH Upload Date",     "HamQTH上传日期",    .onlineServices),
        f("HAMQTH_QSO_UPLOAD_STATUS",  "HamQTH Upload Status",   "HamQTH上传状态",    .onlineServices),
        f("HRDLOG_QSO_UPLOAD_DATE",    "HRDLog Upload Date",     "HRDLog上传日期",    .onlineServices),
        f("HRDLOG_QSO_UPLOAD_STATUS",  "HRDLog Upload Status",   "HRDLog上传状态",    .onlineServices),
        f("QRZCOM_QSO_UPLOAD_DATE",    "QRZ.COM Upload Date",    "QRZ.COM上传日期",   .onlineServices),
        f("QRZCOM_QSO_UPLOAD_STATUS",  "QRZ.COM Upload Status",  "QRZ.COM上传状态",   .onlineServices),
        f("QRZCOM_QSO_DOWNLOAD_DATE",  "QRZ.COM Download Date",  "QRZ.COM下载日期",   .onlineServices),
        f("QRZCOM_QSO_DOWNLOAD_STATUS","QRZ.COM Download Status", "QRZ.COM下载状态",  .onlineServices),
        
        // ═══════════════ Awards & Memberships ═══════════════
        f("IOTA",           "IOTA",              "IOTA",           .awards),
        f("IOTA_ISLAND_ID", "IOTA Island ID",    "IOTA岛屿ID",    .awards),
        f("SOTA_REF",       "SOTA Reference",    "SOTA参考",       .awards),
        f("POTA_REF",       "POTA Reference",    "POTA参考",       .awards),
        f("WWFF_REF",       "WWFF Reference",    "WWFF参考",       .awards),
        f("SIG",            "Special Interest",   "特殊兴趣活动",  .awards),
        f("SIG_INFO",       "SIG Info",           "活动信息",      .awards),
        f("AWARD_SUBMITTED","Awards Submitted",   "已提交奖项",    .awards),
        f("AWARD_GRANTED",  "Awards Granted",     "已获得奖项",    .awards),
        f("CREDIT_SUBMITTED","Credits Submitted", "已提交积分",    .awards),
        f("CREDIT_GRANTED", "Credits Granted",    "已获得积分",    .awards),
        
        // ═══════════════ Propagation & Conditions ═══════════════
        f("A_INDEX",       "A Index",            "A指数",         .propagation),
        f("K_INDEX",       "K Index",            "K指数",         .propagation),
        f("SFI",           "Solar Flux Index",   "太阳通量指数",  .propagation),
        f("MAX_BURSTS",    "Max Bursts (s)",     "最大突发(秒)",  .propagation),
        f("NR_BURSTS",     "Number of Bursts",   "突发数量",      .propagation),
        f("NR_PINGS",      "Number of Pings",    "Ping数量",      .propagation),
        f("MS_SHOWER",     "Meteor Shower",      "流星雨",        .propagation),
        f("FORCE_INIT",    "Force Init (EME)",   "强制初始(EME)", .propagation),
        
        // ═══════════════ Notes & Comments ═══════════════
        f("COMMENT",       "Comment",            "备注",          .notes, core: "remarks", vis: true),
        f("NOTES",         "Notes",              "笔记",          .notes),
        f("PUBLIC_KEY",    "Public Key",         "公钥",          .notes),
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
            nameEN: "Date & Time", nameZH: "日期时间",
            memberFieldIds: ["QSO_DATE", "TIME_ON"],
            category: .basic, supportsCollapsed: true
        ),
        ADIFFieldGroup(
            id: "group_end_datetime",
            nameEN: "End Date & Time", nameZH: "结束日期时间",
            memberFieldIds: ["TIME_OFF", "QSO_DATE_OFF"],
            category: .basic, supportsCollapsed: true
        ),
        ADIFFieldGroup(
            id: "group_contacted_qth",
            nameEN: "Contacted QTH (with Map)", nameZH: "对方QTH (含地图)",
            memberFieldIds: ["QTH", "GRIDSQUARE", "CQZ", "ITUZ", "LAT", "LON"],
            category: .contactedStation, supportsCollapsed: true
        ),
        ADIFFieldGroup(
            id: "group_own_qth",
            nameEN: "Own QTH (with Map)", nameZH: "己方QTH (含地图)",
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
