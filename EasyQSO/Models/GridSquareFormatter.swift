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

/// Maidenhead 网格坐标输入格式化器
///
/// 按位置规范化字符大小写、过滤非法字符、截断到 12 字符。
/// 各位置规则：
/// - 1-2: A-R 大写（field）
/// - 3-4: 0-9 数字（square）
/// - 5-6: a-x 小写（subsquare）
/// - 7-8: 0-9 数字（extended square）
/// - 9-10: a-x 小写（extended subsquare）
/// - 11-12: 0-9 数字（ultra-fine）
enum GridSquareFormatter {
    /// 网格坐标最大长度
    static let maxLength: Int = 12

    /// 清理用户输入：丢弃不符合当前位置规则的字符（不抛错），按位置规范化大小写。
    /// 设计目的：作为 TextField onChange 的处理器，使粘贴/输入立即看到规范化结果。
    static func format(_ raw: String) -> String {
        var result = ""
        result.reserveCapacity(maxLength)

        for scalar in raw.unicodeScalars {
            // 跳过空白字符
            if scalar == " " || scalar == "\t" || scalar == "\n" { continue }

            let position = result.count // 0-indexed 即将写入的位置
            if position >= maxLength { break }

            switch position {
            case 0, 1:
                // A-R, 大写
                if let upper = uppercaseLetterInRange(scalar, lowerBound: 65, upperBound: 82) {
                    result.append(Character(upper))
                }
            case 2, 3, 6, 7, 10, 11:
                // 0-9
                if scalar.value >= 48 && scalar.value <= 57 {
                    result.append(Character(scalar))
                }
            case 4, 5, 8, 9:
                // a-x, 小写
                if let lower = lowercaseLetterInRange(scalar, lowerBound: 97, upperBound: 120) {
                    result.append(Character(lower))
                }
            default:
                break
            }
        }

        return result
    }

    /// 将字母字符规范化为大写并验证范围（A-R 等）。
    private static func uppercaseLetterInRange(_ scalar: Unicode.Scalar,
                                               lowerBound: UInt32,
                                               upperBound: UInt32) -> Unicode.Scalar? {
        var value = scalar.value
        // 小写 a-z 转大写
        if value >= 97 && value <= 122 { value -= 32 }
        guard value >= lowerBound && value <= upperBound else { return nil }
        return Unicode.Scalar(value)
    }

    /// 将字母字符规范化为小写并验证范围（a-x 等）。
    private static func lowercaseLetterInRange(_ scalar: Unicode.Scalar,
                                               lowerBound: UInt32,
                                               upperBound: UInt32) -> Unicode.Scalar? {
        var value = scalar.value
        // 大写 A-Z 转小写
        if value >= 65 && value <= 90 { value += 32 }
        guard value >= lowerBound && value <= upperBound else { return nil }
        return Unicode.Scalar(value)
    }
}
