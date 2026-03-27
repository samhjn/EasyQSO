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

class PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    init() {
        // 使用我们的自定义模型创建容器
        container = PersistenceController.createContainer()
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Error loading Core Data stores: \(error)")
            }
        }
        
        // 启用自动合并策略
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // 执行数据迁移（如果需要）
        migrateFrequencyDataIfNeeded()
    }
    
    // MARK: - 数据迁移
    
    /// 迁移旧版本的频率数据（从MHz的Double格式迁移到Hz的Int64格式）
    private func migrateFrequencyDataIfNeeded() {
        let context = container.viewContext
        let fetchRequest = NSFetchRequest<QSORecord>(entityName: "QSORecord")
        
        // 只获取需要迁移的记录（frequencyHz为0但可能有旧数据）
        fetchRequest.predicate = NSPredicate(format: "frequencyHz == 0 OR rxFrequencyHz == 0")
        
        do {
            let records = try context.fetch(fetchRequest)
            if records.isEmpty {
                print("✓ 无需迁移频率数据")
                return
            }
            
            print("开始迁移 \(records.count) 条记录的频率数据...")
            var migratedCount = 0
            
            for record in records {
                var needsSave = false
                
                // 检查是否需要迁移（通过检查旧字段是否有值）
                if record.frequencyHz == 0 {
                    // 尝试通过计算属性读取，会自动从旧字段读取
                    let freq = record.frequencyMHz
                    if freq > 0 {
                        record.frequencyMHz = freq // 这会触发setter，将数据转换为Hz格式
                        needsSave = true
                    }
                }
                
                if record.rxFrequencyHz == 0 {
                    let rxFreq = record.rxFrequencyMHz
                    if rxFreq > 0 {
                        record.rxFrequencyMHz = rxFreq
                        needsSave = true
                    }
                }
                
                if needsSave {
                    migratedCount += 1
                }
            }
            
            if migratedCount > 0 {
                try context.save()
                print("✓ 成功迁移 \(migratedCount) 条记录的频率数据")
            } else {
                print("✓ 所有记录已是新格式，无需迁移")
            }
        } catch {
            print("✗ 频率数据迁移失败: \(error.localizedDescription)")
        }
    }
    
    // 创建一个用于预览的内存中存储的控制器
    static var preview: PersistenceController = {
        let controller = PersistenceController()
        
        // 创建10个示例记录
        for i in 0..<10 {
            let record = QSORecord(context: controller.container.viewContext)
            record.callsign = "BG\(Int.random(in: 1...9))ABC"
            record.date = Date().addingTimeInterval(-Double(i * 86400))
            record.band = ["20m", "40m", "80m"].randomElement()!
            record.mode = ["SSB", "CW", "FT8"].randomElement()!
            
            // 使用新的频率格式（Hz为单位的整数）
            let freqMHz = Double.random(in: 7.0...14.3)
            record.frequencyMHz = freqMHz // 通过计算属性自动转换为Hz
            record.rxFrequencyMHz = freqMHz + Double.random(in: -0.01...0.01)
            
            record.txPower = i % 4 == 0 ? nil : ["100W", "50W", "20W", "10W"].randomElement()!
            record.rstSent = "5\(Int.random(in: 1...9))"
            record.rstReceived = "5\(Int.random(in: 1...9))"
            record.name = ["张三", "李四", "王五", nil].randomElement()!
            record.qth = ["北京", "上海", "广州", nil].randomElement()!
            record.gridSquare = i % 3 == 0 ? nil : ["OM99aa", "PM01bb", "PN11cc"].randomElement()!
            record.cqZone = i % 3 == 0 ? nil : ["24", "23", "25"].randomElement()!
            record.ituZone = i % 3 == 0 ? nil : ["44", "43", "45"].randomElement()!
            record.satellite = i % 5 == 0 ? ["SO-50", "AO-91", "FM"].randomElement()! : nil
            record.remarks = i % 3 == 0 ? "测试记录 \(i)" : nil
        }
        
        do {
            try controller.container.viewContext.save()
        } catch {
            fatalError("Error creating preview data: \(error)")
        }
        
        return controller
    }()
}
