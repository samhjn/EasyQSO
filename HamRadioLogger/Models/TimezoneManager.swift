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
 * along with this program.  If not, see <https://www.gnu.org/libsenses/>.
 */

import Foundation

/// 时区管理器 - 处理QSO记录的时区转换
class TimezoneManager {
    
    // MARK: - 时区常量
    static let utcTimezone = TimeZone(identifier: "UTC")!
    static let localTimezone = TimeZone.current
    
    // MARK: - 支持的时区列表（向后兼容）
    static let supportedTimezones: [(name: String, timezone: TimeZone)] = utcOffsetTimezones
    
    // MARK: - UTC偏移量时区列表
    static let utcOffsetTimezones: [(name: String, timezone: TimeZone)] = [
        (LocalizedStrings.localTime.localized, TimeZone.current),
        ("UTC", utcTimezone),
        ("UTC-12", TimeZone(secondsFromGMT: -12 * 3600)!),
        ("UTC-11", TimeZone(secondsFromGMT: -11 * 3600)!),
        ("UTC-10", TimeZone(secondsFromGMT: -10 * 3600)!),
        ("UTC-9", TimeZone(secondsFromGMT: -9 * 3600)!),
        ("UTC-8", TimeZone(secondsFromGMT: -8 * 3600)!),
        ("UTC-7", TimeZone(secondsFromGMT: -7 * 3600)!),
        ("UTC-6", TimeZone(secondsFromGMT: -6 * 3600)!),
        ("UTC-5", TimeZone(secondsFromGMT: -5 * 3600)!),
        ("UTC-4", TimeZone(secondsFromGMT: -4 * 3600)!),
        ("UTC-3", TimeZone(secondsFromGMT: -3 * 3600)!),
        ("UTC-2", TimeZone(secondsFromGMT: -2 * 3600)!),
        ("UTC-1", TimeZone(secondsFromGMT: -1 * 3600)!),
        ("UTC+1", TimeZone(secondsFromGMT: 1 * 3600)!),
        ("UTC+2", TimeZone(secondsFromGMT: 2 * 3600)!),
        ("UTC+3", TimeZone(secondsFromGMT: 3 * 3600)!),
        ("UTC+4", TimeZone(secondsFromGMT: 4 * 3600)!),
        ("UTC+5", TimeZone(secondsFromGMT: 5 * 3600)!),
        ("UTC+6", TimeZone(secondsFromGMT: 6 * 3600)!),
        ("UTC+7", TimeZone(secondsFromGMT: 7 * 3600)!),
        ("UTC+8", TimeZone(secondsFromGMT: 8 * 3600)!),
        ("UTC+9", TimeZone(secondsFromGMT: 9 * 3600)!),
        ("UTC+10", TimeZone(secondsFromGMT: 10 * 3600)!),
        ("UTC+11", TimeZone(secondsFromGMT: 11 * 3600)!),
        ("UTC+12", TimeZone(secondsFromGMT: 12 * 3600)!),
        ("UTC+13", TimeZone(secondsFromGMT: 13 * 3600)!),
        ("UTC+14", TimeZone(secondsFromGMT: 14 * 3600)!)
    ]
    
    // MARK: - 日期格式化器
    
    /// 创建UTC时间的日期格式化器（用于ADIF导出）
    static func createUTCDateFormatter(format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = utcTimezone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }
    
    /// 创建本地时间的日期格式化器（用于显示）
    static func createLocalDateFormatter(format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = localTimezone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }
    
    /// 创建指定时区的日期格式化器
    static func createDateFormatter(format: String, timezone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = timezone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }
    
    // MARK: - 时区转换
    
    /// 将本地时间转换为UTC时间字符串（用于导出）
    static func formatDateAsUTC(_ date: Date, format: String) -> String {
        let formatter = createUTCDateFormatter(format: format)
        return formatter.string(from: date)
    }
    
    /// 将本地时间转换为指定时区的时间字符串
    static func formatDate(_ date: Date, format: String, timezone: TimeZone) -> String {
        let formatter = createDateFormatter(format: format, timezone: timezone)
        return formatter.string(from: date)
    }
    
    /// 从UTC时间字符串解析为本地时间（用于导入）
    static func parseDateFromUTC(_ dateString: String, format: String) -> Date? {
        let formatter = createUTCDateFormatter(format: format)
        return formatter.date(from: dateString)
    }
    
    /// 从指定时区的时间字符串解析为本地时间
    static func parseDate(_ dateString: String, format: String, timezone: TimeZone) -> Date? {
        let formatter = createDateFormatter(format: format, timezone: timezone)
        return formatter.date(from: dateString)
    }
    
    /// 合并日期和时间字符串（支持不同时区）
    static func combineDateTime(dateString: String, timeString: String, 
                               dateFormat: String, timeFormat: String, 
                               timezone: TimeZone) -> Date? {
        
        guard !dateString.isEmpty else { return nil }
        
        // 首先解析日期
        let dateFormatter = createDateFormatter(format: dateFormat, timezone: timezone)
        guard let baseDate = dateFormatter.date(from: dateString) else { return nil }
        
        // 如果没有时间字符串，就返回当天的开始时间
        guard !timeString.isEmpty && timeString.count >= 4 else {
            return baseDate
        }
        
        // 解析时间
        let hour = Int(timeString.prefix(2)) ?? 0
        let minute = Int(timeString.dropFirst(2).prefix(2)) ?? 0
        
        // 使用指定时区的日历
        var calendar = Calendar.current
        calendar.timeZone = timezone
        
        // 获取日期组件并设置时间
        var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
        components.hour = hour
        components.minute = minute
        components.second = 0
        
        return calendar.date(from: components)
    }
    
    // MARK: - ADIF标准时间处理
    
    /// 将本地时间转换为ADIF标准的UTC时间格式
    static func formatDateForADIF(_ date: Date) -> (date: String, time: String) {
        let dateString = formatDateAsUTC(date, format: "yyyyMMdd")
        let timeString = formatDateAsUTC(date, format: "HHmm")
        return (date: dateString, time: timeString)
    }
    
    /// 从ADIF格式解析时间（假设为UTC）
    static func parseDateFromADIF(dateString: String, timeString: String) -> Date {
        // 尝试从UTC解析
        if let date = combineDateTime(dateString: dateString, 
                                    timeString: timeString,
                                    dateFormat: "yyyyMMdd", 
                                    timeFormat: "HHmm",
                                    timezone: utcTimezone) {
            return date
        }
        
        // 如果UTC解析失败，尝试本地时间解析（兼容旧格式）
        if let date = combineDateTime(dateString: dateString, 
                                    timeString: timeString,
                                    dateFormat: "yyyyMMdd", 
                                    timeFormat: "HHmm",
                                    timezone: localTimezone) {
            return date
        }
        
        // 如果都失败，返回当前时间
        return Date()
    }
    
    // MARK: - CSV时间处理
    
    /// 将本地时间转换为CSV格式（可选择时区）
    static func formatDateForCSV(_ date: Date, timezone: TimeZone) -> (date: String, time: String) {
        let dateString = formatDate(date, format: "yyyy-MM-dd", timezone: timezone)
        let timeString = formatDate(date, format: "HH:mm", timezone: timezone)
        return (date: dateString, time: timeString)
    }
    
    /// 从CSV格式解析时间
    static func parseDateFromCSV(dateString: String, timeString: String, timezone: TimeZone) -> Date {
        // 尝试从指定时区解析
        if let date = combineDateTime(dateString: dateString,
                                    timeString: timeString,
                                    dateFormat: "yyyy-MM-dd",
                                    timeFormat: "HH:mm",
                                    timezone: timezone) {
            return date
        }
        
        // 如果解析失败，返回当前时间
        return Date()
    }
    
    // MARK: - 用户偏好设置
    
    private static let exportTimezoneKey = "ExportTimezone"
    private static let importTimezoneKey = "ImportTimezone"
    
    /// 获取导出时区偏好
    static func getExportTimezone() -> TimeZone {
        if let identifier = UserDefaults.standard.string(forKey: exportTimezoneKey),
           let timezone = TimeZone(identifier: identifier) {
            return timezone
        }
        return utcTimezone // 默认使用UTC
    }
    
    /// 设置导出时区偏好
    static func setExportTimezone(_ timezone: TimeZone) {
        UserDefaults.standard.set(timezone.identifier, forKey: exportTimezoneKey)
    }
    
    /// 获取导入时区偏好
    static func getImportTimezone() -> TimeZone {
        if let identifier = UserDefaults.standard.string(forKey: importTimezoneKey),
           let timezone = TimeZone(identifier: identifier) {
            return timezone
        }
        return utcTimezone // 默认假设导入文件使用UTC
    }
    
    /// 设置导入时区偏好
    static func setImportTimezone(_ timezone: TimeZone) {
        UserDefaults.standard.set(timezone.identifier, forKey: importTimezoneKey)
    }
}

// MARK: - 时区扩展

extension TimeZone {
    /// 获取用于显示的友好名称
    var displayName: String {
        if self == TimeZone.current {
            return "\(LocalizedStrings.localTime.localized) (\(abbreviation() ?? ""))"
        } else if identifier == "UTC" {
            return "UTC"
        } else {
            // 对于UTC偏移量时区，显示UTC+X格式
            let offsetSeconds = secondsFromGMT()
            let offsetHours = offsetSeconds / 3600
            
            if offsetHours == 0 {
                return "UTC"
            } else if offsetHours > 0 {
                return "UTC+\(offsetHours)"
            } else {
                return "UTC\(offsetHours)" // 负数会自动包含负号
            }
        }
    }
} 