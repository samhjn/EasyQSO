/*
 * EasyQSO - 业余无线电通联日志
 * Copyright (C) 2025 ShadowMov
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import Foundation

/// 本地化管理器
class LocalizationManager {
    static let shared = LocalizationManager()
    
    private init() {}
    
    /// 获取本地化字符串
    /// - Parameters:
    ///   - key: 本地化键
    ///   - comment: 注释，用于帮助翻译者理解上下文
    /// - Returns: 本地化后的字符串
    func localizedString(for key: String, comment: String = "") -> String {
        return NSLocalizedString(key, comment: comment)
    }
}

/// 便捷的本地化字符串扩展
extension String {
    /// 获取本地化字符串
    /// - Returns: 本地化字符串
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    /// 获取本地化字符串，带注释
    /// - Parameter comment: 注释
    /// - Returns: 本地化字符串
    func localized(comment: String) -> String {
        return NSLocalizedString(self, comment: comment)
    }
}

/// 本地化字符串常量
struct LocalizedStrings {
    // MARK: - 主要标签页
    static let recordQSO = "record_qso"
    static let queryLog = "query_log"
    static let importExport = "import_export"
    
    // MARK: - 表单段落标题
    static let basicInfo = "basic_info"
    static let signalReport = "signal_report"
    static let technicalInfo = "technical_info"
    static let ownQthInfo = "own_qth_info"
    static let qthInfo = "qth_info"
    static let additionalInfo = "additional_info"
    static let dataManagement = "data_management"
    static let exportLog = "export_log"
    static let importLog = "import_log"
    
    // MARK: - 字段标签
    static let callsign = "callsign"
    static let dateTime = "date_time"
    static let band = "band"
    static let mode = "mode"
    static let frequency = "frequency"
    static let rxFrequency = "rx_frequency"
    static let txPower = "tx_power"
    static let rstSent = "rst_sent"
    static let rstReceived = "rst_received"
    static let name = "name"
    static let qth = "qth"
    static let ownQth = "own_qth"
    static let gridSquare = "grid_square"
    static let cqZone = "cq_zone"
    static let ituZone = "itu_zone"
    static let satellite = "satellite"
    static let remarks = "remarks"
    
    // MARK: - 地图和位置选择
    static let selectLocation = "select_location"
    static let selectOnMap = "select_on_map"
    static let locationName = "location_name"
    static let coordinates = "coordinates"
    static let latitude = "latitude"
    static let longitude = "longitude"
    static let gridCoordinate = "grid_coordinate"
    static let clickMapToSelect = "click_map_to_select"
    static let selectedLocationInfo = "selected_location_info"
    
    // MARK: - 按钮
    static let saveQSO = "save_qso"
    static let saveChanges = "save_changes"
    static let exportAll = "export_all"
    static let importFromADIF = "import_from_adif"
    static let importFromCSV = "import_from_csv"
    static let delete = "delete"
    static let cancel = "cancel"
    static let confirm = "confirm"
    
    // MARK: - 键盘工具栏
    static let previous = "previous"
    static let next = "next"
    static let done = "done"
    
    // MARK: - 搜索和显示
    static let searchPlaceholder = "search_placeholder"
    static let recordCount = "record_count"
    static let operatorLabel = "operator"
    static let exportFormat = "export_format"
    static let currentRecordCount = "current_record_count"
    
    // MARK: - 导航标题
    static let editQSO = "edit_qso"
    
    // MARK: - 验证和错误消息
    static let validationError = "validation_error"
    static let callsignEmpty = "callsign_empty"
    static let callsignInvalid = "callsign_invalid"
    static let frequencyInvalid = "frequency_invalid"
    static let gridSquareInvalid = "grid_square_invalid"
    static let cqZoneInvalid = "cq_zone_invalid"
    static let ituZoneInvalid = "itu_zone_invalid"
    
    // MARK: - 成功消息
    static let qsoSaved = "qso_saved"
    static let qsoSavedMessage = "qso_saved_message"
    static let saveSuccess = "save_success"
    static let qsoUpdated = "qso_updated"
    static let saveFailed = "save_failed"
    static let saveFailedMessage = "save_failed_message"
    static let deleteSuccess = "delete_success"
    static let deleteSuccessMessage = "delete_success_message"
    static let exportSuccess = "export_success"
    static let exportSuccessMessage = "export_success_message"
    static let importSuccess = "import_success"
    static let importSuccessMessage = "import_success_message"
    
    // MARK: - 失败消息
    static let deleteFailed = "delete_failed"
    static let deleteFailedMessage = "delete_failed_message"
    static let exportFailed = "export_failed"
    static let importFailed = "import_failed"
    static let cannotAccessDocuments = "cannot_access_documents"
    static let cannotReadFile = "cannot_read_file"
    static let csvFormatIncorrect = "csv_format_incorrect"
    static let cannotGetExistingRecords = "cannot_get_existing_records"
    
    // MARK: - 删除确认
    static let deleteRecord = "delete_record"
    static let deleteConfirmMessage = "delete_confirm_message"
    
    // MARK: - 应用信息
    static let appDisplayName = "app_display_name"
    static let documentsFolderUsage = "documents_folder_usage"
    
    // MARK: - 进阶功能字符串
    static let importSuccessWithDuplicates = "import_success_with_duplicates"
    
    // MARK: - 时区设置
    static let exportTimezone = "export_timezone"
    static let importTimezone = "import_timezone"
    static let timezoneSettings = "timezone_settings"
    static let exportTab = "export_tab"
    static let importTab = "import_tab"
    static let notes = "notes"
    static let timezoneNoteLocal = "timezone_note_local"
    static let timezoneNoteAdif = "timezone_note_adif"
    static let timezoneNoteCsv = "timezone_note_csv"
    static let timezoneNoteConversion = "timezone_note_conversion"
    static let timezoneNoteAdifIgnore = "timezone_note_adif_ignore"
    static let exportTimezoneDesc = "export_timezone_desc"
    static let importTimezoneDesc = "import_timezone_desc"
    static let localTime = "local_time"
    static let adifUsesUtc = "adif_uses_utc"
    static let csvTimezoneOnly = "csv_timezone_only"
    
    // MARK: - About and License
    static let about = "about"
    static let license = "license"
    static let licenseType = "license_type"
    static let gplV3 = "gpl_v3"
    static let licenseDescription = "license_description"
    static let licenseFreedomUse = "license_freedom_use"
    static let licenseFreedomModify = "license_freedom_modify"
    static let licenseFreedomDistribute = "license_freedom_distribute"
    static let licenseTermsApply = "license_terms_apply"
    static let copyright = "copyright"
    static let copyrightNotice = "copyright_notice"
    static let viewFullLicense = "view_full_license"
    static let viewSourceCode = "view_source_code"
    static let reportIssue = "report_issue"
    static let softwareIntroduction = "software_introduction"
    static let softwareDescription = "software_description"
    static let openSourceLicense = "open_source_license"
    static let version = "version"
    static let welcomeTitle = "welcome_title"
    static let welcomeGplNotice = "welcome_gpl_notice"
    static let learnGplLicense = "learn_gpl_license"
    static let viewLater = "view_later"
} 
