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
import CoreData

// MARK: - Store Load State

/// 数据库加载状态，用于在模型不兼容时提供受控的错误处理而非崩溃
enum StoreLoadState {
    /// 数据库加载成功，可正常使用
    case ready
    /// 数据库模型不兼容，无法通过轻量级迁移解决
    case incompatibleSchema(storeURL: URL)
    /// 数据库文件损坏或无法读取
    case storeFileError(String)
    /// 数据库加载失败（其他原因）
    case loadFailed(String)

    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }

    /// 用户可见的错误描述
    var localizedDescription: String {
        switch self {
        case .ready:
            return ""
        case .incompatibleSchema(let url):
            return "当前应用的数据模型与已有数据库不兼容，无法安全加载现有数据。\n\n"
                + "数据库文件路径:\n\(url.path)\n\n"
                + "请备份上述文件后，更新至最新版本应用。如仍无法解决，请联系开发者。"
        case .storeFileError(let detail):
            return "无法读取数据库文件: \(detail)"
        case .loadFailed(let detail):
            return "数据库加载失败: \(detail)"
        }
    }

    /// 错误标题
    var title: String {
        switch self {
        case .ready:
            return ""
        case .incompatibleSchema:
            return "数据库版本不兼容"
        case .storeFileError:
            return "数据库文件异常"
        case .loadFailed:
            return "数据库加载失败"
        }
    }
}

// MARK: - Store Compatibility Check

/// 数据库兼容性检查工具，用于在加载前检测模型不兼容问题
enum StoreCompatibilityCheck {

    /// 返回应用默认的 SQLite 数据库文件路径
    static func defaultStoreURL() -> URL {
        NSPersistentContainer.defaultDirectoryURL()
            .appendingPathComponent("EasyQSO.sqlite")
    }

    /// 诊断数据库加载失败的原因
    ///
    /// 当 `loadPersistentStores` 失败时调用，判断是否为模型不兼容问题。
    /// - Parameters:
    ///   - loadError: `loadPersistentStores` 返回的错误
    ///   - model: 当前应用的 `NSManagedObjectModel`
    ///   - storeURL: 数据库文件路径，默认使用 `defaultStoreURL()`
    /// - Returns: 诊断后的 `StoreLoadState`
    static func diagnoseLoadFailure(
        loadError: Error,
        model: NSManagedObjectModel,
        storeURL: URL? = nil
    ) -> StoreLoadState {
        let url = storeURL ?? defaultStoreURL()

        guard FileManager.default.fileExists(atPath: url.path) else {
            return .loadFailed(loadError.localizedDescription)
        }

        // 尝试读取现有数据库的元数据，与当前模型比对
        if let metadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType, at: url
        ) {
            if !model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) {
                return .incompatibleSchema(storeURL: url)
            }
        }

        return .loadFailed(loadError.localizedDescription)
    }

    /// 检查数据库文件是否可读
    ///
    /// 在加载前先验证数据库文件是否存在且元数据可读。
    /// - Parameters:
    ///   - storeURL: 数据库文件路径
    /// - Returns: 如果文件不存在或可读返回 nil；如果文件存在但无法读取返回错误状态
    static func checkStoreFileReadable(storeURL: URL? = nil) -> StoreLoadState? {
        let url = storeURL ?? defaultStoreURL()

        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil // 文件不存在 = 全新安装，无兼容性问题
        }

        do {
            _ = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType, at: url
            )
            return nil // 文件可读
        } catch {
            return .storeFileError(error.localizedDescription)
        }
    }
}
