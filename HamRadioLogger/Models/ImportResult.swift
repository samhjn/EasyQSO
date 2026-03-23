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

/// 导入结果记录
struct ImportResult {
    /// 成功导入的记录
    var successRecords: [ImportRecord] = []
    
    /// 重复的记录（被跳过）
    var duplicateRecords: [ImportRecord] = []
    
    /// 非法的记录（无效数据）
    var invalidRecords: [ImportRecord] = []
    
    /// 总处理的记录数
    var totalProcessed: Int {
        return successRecords.count + duplicateRecords.count + invalidRecords.count
    }
    
    /// 是否有任何问题
    var hasIssues: Bool {
        return !duplicateRecords.isEmpty || !invalidRecords.isEmpty
    }
}

/// 单条导入记录的信息
struct ImportRecord: Identifiable {
    let id = UUID()
    
    /// 呼号
    var callsign: String
    
    /// QSO日期时间
    var dateTime: String
    
    /// 波段
    var band: String
    
    /// 模式
    var mode: String
    
    /// 频率（MHz）
    var frequency: String
    
    /// 失败/跳过原因
    var reason: String?
    
    /// 原始ADIF记录（用于调试）
    var rawData: String?
    
    /// 创建一个显示用的简短描述
    var description: String {
        var desc = "\(callsign) - \(dateTime)"
        if !band.isEmpty {
            desc += " - \(band)"
        }
        if !mode.isEmpty {
            desc += "/\(mode)"
        }
        if !frequency.isEmpty && frequency != "0" {
            desc += " - \(frequency)MHz"
        }
        return desc
    }
}
