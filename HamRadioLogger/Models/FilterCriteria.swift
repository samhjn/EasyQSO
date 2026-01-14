/*
 * EasyQSO - 业余无线电通联日志
 * Copyright (C) 2026 ShadowMov
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
import CoreData

// 搜索模式枚举
enum SearchMode {
    case fuzzy      // 模糊搜索
    case exact      // 精确搜索
}

// 高级筛选条件
struct FilterCriteria {
    // 搜索模式
    var searchMode: SearchMode = .fuzzy

    // 文本搜索
    var searchText: String = ""

    // 呼号筛选
    var callsignFilter: String = ""

    // 波段筛选
    var bandFilter: String = ""
    var selectedBands: Set<String> = []

    // 模式筛选
    var modeFilter: String = ""
    var selectedModes: Set<String> = []

    // 时间范围筛选
    var startDate: Date?
    var endDate: Date?

    // 姓名筛选
    var nameFilter: String = ""

    // QTH筛选
    var qthFilter: String = ""

    // 网格筛选
    var gridSquareFilter: String = ""

    // 频率范围筛选
    var minFrequency: Double?
    var maxFrequency: Double?

    // 卫星筛选
    var satelliteFilter: String = ""

    // 重置所有筛选条件
    mutating func reset() {
        searchMode = .fuzzy
        searchText = ""
        callsignFilter = ""
        bandFilter = ""
        selectedBands = []
        modeFilter = ""
        selectedModes = []
        startDate = nil
        endDate = nil
        nameFilter = ""
        qthFilter = ""
        gridSquareFilter = ""
        minFrequency = nil
        maxFrequency = nil
        satelliteFilter = ""
    }

    // 判断是否有活动的筛选条件
    var hasActiveFilters: Bool {
        return !searchText.isEmpty ||
               !callsignFilter.isEmpty ||
               !bandFilter.isEmpty ||
               !selectedBands.isEmpty ||
               !modeFilter.isEmpty ||
               !selectedModes.isEmpty ||
               startDate != nil ||
               endDate != nil ||
               !nameFilter.isEmpty ||
               !qthFilter.isEmpty ||
               !gridSquareFilter.isEmpty ||
               minFrequency != nil ||
               maxFrequency != nil ||
               !satelliteFilter.isEmpty
    }

    // 应用筛选条件到记录数组
    func apply(to records: [QSORecord]) -> [QSORecord] {
        var filtered = records

        // 应用通用搜索
        if !searchText.isEmpty {
            filtered = filtered.filter { record in
                let searchLower = searchText.lowercased()
                if searchMode == .fuzzy {
                    return record.callsign.lowercased().contains(searchLower) ||
                           record.band.lowercased().contains(searchLower) ||
                           record.mode.lowercased().contains(searchLower) ||
                           (record.name ?? "").lowercased().contains(searchLower) ||
                           (record.qth ?? "").lowercased().contains(searchLower)
                } else {
                    return record.callsign.lowercased() == searchLower ||
                           record.band.lowercased() == searchLower ||
                           record.mode.lowercased() == searchLower ||
                           (record.name ?? "").lowercased() == searchLower ||
                           (record.qth ?? "").lowercased() == searchLower
                }
            }
        }

        // 应用呼号筛选
        if !callsignFilter.isEmpty {
            filtered = filtered.filter { record in
                if searchMode == .fuzzy {
                    return record.callsign.localizedCaseInsensitiveContains(callsignFilter)
                } else {
                    return record.callsign.uppercased() == callsignFilter.uppercased()
                }
            }
        }

        // 应用波段筛选
        if !bandFilter.isEmpty {
            filtered = filtered.filter { record in
                if searchMode == .fuzzy {
                    return record.band.localizedCaseInsensitiveContains(bandFilter)
                } else {
                    return record.band == bandFilter
                }
            }
        }

        if !selectedBands.isEmpty {
            filtered = filtered.filter { record in
                selectedBands.contains(record.band)
            }
        }

        // 应用模式筛选
        if !modeFilter.isEmpty {
            filtered = filtered.filter { record in
                if searchMode == .fuzzy {
                    return record.mode.localizedCaseInsensitiveContains(modeFilter)
                } else {
                    return record.mode == modeFilter
                }
            }
        }

        if !selectedModes.isEmpty {
            filtered = filtered.filter { record in
                selectedModes.contains(record.mode)
            }
        }

        // 应用时间范围筛选
        if let start = startDate {
            filtered = filtered.filter { record in
                record.date >= start
            }
        }

        if let end = endDate {
            // 将结束日期设置为当天的23:59:59
            let calendar = Calendar.current
            let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
            filtered = filtered.filter { record in
                record.date <= endOfDay
            }
        }

        // 应用姓名筛选
        if !nameFilter.isEmpty {
            filtered = filtered.filter { record in
                guard let name = record.name else { return false }
                if searchMode == .fuzzy {
                    return name.localizedCaseInsensitiveContains(nameFilter)
                } else {
                    return name.caseInsensitiveCompare(nameFilter) == .orderedSame
                }
            }
        }

        // 应用QTH筛选
        if !qthFilter.isEmpty {
            filtered = filtered.filter { record in
                guard let qth = record.qth else { return false }
                if searchMode == .fuzzy {
                    return qth.localizedCaseInsensitiveContains(qthFilter)
                } else {
                    return qth.caseInsensitiveCompare(qthFilter) == .orderedSame
                }
            }
        }

        // 应用网格筛选
        if !gridSquareFilter.isEmpty {
            filtered = filtered.filter { record in
                guard let gridSquare = record.gridSquare else { return false }
                if searchMode == .fuzzy {
                    return gridSquare.localizedCaseInsensitiveContains(gridSquareFilter)
                } else {
                    return gridSquare.uppercased() == gridSquareFilter.uppercased()
                }
            }
        }

        // 应用频率范围筛选
        if let minFreq = minFrequency {
            filtered = filtered.filter { record in
                record.frequency >= minFreq
            }
        }

        if let maxFreq = maxFrequency {
            filtered = filtered.filter { record in
                record.frequency <= maxFreq
            }
        }

        // 应用卫星筛选
        if !satelliteFilter.isEmpty {
            filtered = filtered.filter { record in
                guard let satellite = record.satellite else { return false }
                if searchMode == .fuzzy {
                    return satellite.localizedCaseInsensitiveContains(satelliteFilter)
                } else {
                    return satellite.caseInsensitiveCompare(satelliteFilter) == .orderedSame
                }
            }
        }

        return filtered
    }

    // 获取筛选条件的描述文本
    func getDescription() -> String {
        var descriptions: [String] = []

        if !searchText.isEmpty {
            let modeText = searchMode == .fuzzy ? LocalizedStrings.filterFuzzy.localized : LocalizedStrings.filterExact.localized
            descriptions.append("\(LocalizedStrings.filterSearch.localized)(\(modeText)): \(searchText)")
        }

        if !callsignFilter.isEmpty {
            descriptions.append("\(LocalizedStrings.filterCallsign.localized): \(callsignFilter)")
        }

        if !bandFilter.isEmpty {
            descriptions.append("\(LocalizedStrings.filterBand.localized): \(bandFilter)")
        }

        if !selectedBands.isEmpty {
            descriptions.append("\(LocalizedStrings.filterBand.localized): \(selectedBands.joined(separator: ", "))")
        }

        if !modeFilter.isEmpty {
            descriptions.append("\(LocalizedStrings.filterMode.localized): \(modeFilter)")
        }

        if !selectedModes.isEmpty {
            descriptions.append("\(LocalizedStrings.filterMode.localized): \(selectedModes.joined(separator: ", "))")
        }

        if let start = startDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            descriptions.append("\(LocalizedStrings.filterStartDate.localized): \(formatter.string(from: start))")
        }

        if let end = endDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            descriptions.append("\(LocalizedStrings.filterEndDate.localized): \(formatter.string(from: end))")
        }

        if !nameFilter.isEmpty {
            descriptions.append("\(LocalizedStrings.filterName.localized): \(nameFilter)")
        }

        if !qthFilter.isEmpty {
            descriptions.append("\(LocalizedStrings.filterQth.localized): \(qthFilter)")
        }

        if !gridSquareFilter.isEmpty {
            descriptions.append("\(LocalizedStrings.filterGrid.localized): \(gridSquareFilter)")
        }

        if let minFreq = minFrequency {
            descriptions.append("\(LocalizedStrings.filterMinFreq.localized): \(String(format: "%.3f", minFreq)) MHz")
        }

        if let maxFreq = maxFrequency {
            descriptions.append("\(LocalizedStrings.filterMaxFreq.localized): \(String(format: "%.3f", maxFreq)) MHz")
        }

        if !satelliteFilter.isEmpty {
            descriptions.append("\(LocalizedStrings.filterSatellite.localized): \(satelliteFilter)")
        }

        return descriptions.isEmpty ? LocalizedStrings.filterNoFilters.localized : descriptions.joined(separator: " • ")
    }
}

// 扩展：获取所有不同的波段和模式
extension Array where Element == QSORecord {
    func uniqueBands() -> [String] {
        let bands = Set(self.map { $0.band })
        return bands.sorted()
    }

    func uniqueModes() -> [String] {
        let modes = Set(self.map { $0.mode })
        return modes.sorted()
    }
}
