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
import Combine

/// 网格坐标精度管理器
///
/// 管理用户选择的 Maidenhead 网格坐标精度（4/6/8/10/12 字符）。
/// 该偏好仅影响应用 *生成* 网格坐标时的字符数（如地图选点、当前定位自动填充）；
/// 用户手动输入或已存储的值不会被截断或重新格式化。
final class GridPrecisionManager: ObservableObject {
    static let shared = GridPrecisionManager()

    /// 支持的 Maidenhead 网格精度（字符数，必须为偶数）
    static let supportedPrecisions: [Int] = [4, 6, 8, 10, 12]

    /// 默认精度，与历史版本行为保持一致，避免升级用户产生意外
    static let defaultPrecision: Int = 6

    private static let storageKey = "gridDisplayPrecision"

    @Published var displayPrecision: Int {
        didSet {
            if !Self.supportedPrecisions.contains(displayPrecision) {
                displayPrecision = Self.defaultPrecision
                return
            }
            UserDefaults.standard.set(displayPrecision, forKey: Self.storageKey)
        }
    }

    private init() {
        let stored = UserDefaults.standard.object(forKey: Self.storageKey) as? Int
        if let stored = stored, Self.supportedPrecisions.contains(stored) {
            self.displayPrecision = stored
        } else {
            self.displayPrecision = Self.defaultPrecision
        }
    }

    /// 返回精度对应的近似分辨率本地化键，例如 6 -> "grid_precision_resolution_6"
    static func resolutionLabelKey(for precision: Int) -> String {
        return "grid_precision_resolution_\(precision)"
    }
}
