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
import CoreLocation

@objc(QSORecord)
public class QSORecord: NSManagedObject {
    @NSManaged public var callsign: String
    @NSManaged public var date: Date
    @NSManaged public var band: String
    @NSManaged public var mode: String
    @NSManaged public var frequency: Double
    @NSManaged public var rxFrequency: Double
    @NSManaged public var txPower: String?
    @NSManaged public var rstSent: String
    @NSManaged public var rstReceived: String
    @NSManaged public var name: String?
    @NSManaged public var qth: String?
    @NSManaged public var gridSquare: String?
    @NSManaged public var cqZone: String?
    @NSManaged public var ituZone: String?
    @NSManaged public var satellite: String?
    @NSManaged public var remarks: String?
    // 新增坐标字段
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    
    // 计算属性：获取坐标（如果有效）
    var coordinate: CLLocationCoordinate2D? {
        // 检查坐标是否有效（非零值表示有坐标数据）
        if latitude != 0 || longitude != 0 {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        return nil
    }
    
    // 设置坐标的便利方法
    func setCoordinate(_ coordinate: CLLocationCoordinate2D?) {
        if let coord = coordinate {
            self.latitude = coord.latitude
            self.longitude = coord.longitude
        } else {
            self.latitude = 0
            self.longitude = 0
        }
    }
    
    // 添加一个用于显示的时间属性
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    // 添加一个用于显示的日期属性
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    // 根据频率自动确定波段
    static func bandForFrequency(_ frequency: Double) -> String? {
        switch frequency {
        case 1.8...2.0:
            return "160m"
        case 3.5...4.0:
            return "80m"
        case 7.0...7.3:
            return "40m"
        case 10.1...10.15:
            return "30m"
        case 14.0...14.35:
            return "20m"
        case 18.068...18.168:
            return "17m"
        case 21.0...21.45:
            return "15m"
        case 24.89...24.99:
            return "12m"
        case 28.0...29.7:
            return "10m"
        case 50.0...54.0:
            return "6m"
        case 144.0...148.0:
            return "2m"
        case 420.0...450.0:
            return "70cm"
        default:
            return nil
        }
    }
    
    // 获取指定波段的最后使用频率
    static func lastFrequencyForBand(_ band: String, context: NSManagedObjectContext) -> Double? {
        let request = NSFetchRequest<QSORecord>(entityName: "QSORecord")
        request.predicate = NSPredicate(format: "band == %@ AND frequency > 0", band)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \QSORecord.date, ascending: false)]
        request.fetchLimit = 1
        
        do {
            let results = try context.fetch(request)
            return results.first?.frequency
        } catch {
            print("获取波段最后使用频率时出错: \(error)")
            return nil
        }
    }
}

extension QSORecord: Identifiable {
    public var id: NSManagedObjectID {
        return self.objectID
    }
}

extension QSORecord {
    // 创建一个用于获取所有QSO记录的请求
    @nonobjc public class func fetchRequest() -> NSFetchRequest<QSORecord> {
        return NSFetchRequest<QSORecord>(entityName: "QSORecord")
    }
    
    // 获取最近的QSO记录
    @nonobjc public class func getLatestQSO(context: NSManagedObjectContext) -> QSORecord? {
        let request = NSFetchRequest<QSORecord>(entityName: "QSORecord")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \QSORecord.date, ascending: false)]
        request.fetchLimit = 1
        
        do {
            let results = try context.fetch(request)
            return results.first
        } catch {
            print("获取最近QSO记录时出错: \(error)")
            return nil
        }
    }
    
    // 创建一个用于按呼号搜索的请求
    @nonobjc public class func fetchRequestByCallsign(callsign: String) -> NSFetchRequest<QSORecord> {
        let request = NSFetchRequest<QSORecord>(entityName: "QSORecord")
        request.predicate = NSPredicate(format: "callsign CONTAINS[cd] %@", callsign)
        return request
    }
    
    // 创建一个用于按波段搜索的请求
    @nonobjc public class func fetchRequestByBand(band: String) -> NSFetchRequest<QSORecord> {
        let request = NSFetchRequest<QSORecord>(entityName: "QSORecord")
        request.predicate = NSPredicate(format: "band == %@", band)
        return request
    }
    
    // 创建一个用于按模式搜索的请求
    @nonobjc public class func fetchRequestByMode(mode: String) -> NSFetchRequest<QSORecord> {
        let request = NSFetchRequest<QSORecord>(entityName: "QSORecord")
        request.predicate = NSPredicate(format: "mode == %@", mode)
        return request
    }
    
    // 创建一个用于按日期范围搜索的请求
    @nonobjc public class func fetchRequestByDateRange(startDate: Date, endDate: Date) -> NSFetchRequest<QSORecord> {
        let request = NSFetchRequest<QSORecord>(entityName: "QSORecord")
        request.predicate = NSPredicate(format: "date >= %@ AND date <= %@", startDate as NSDate, endDate as NSDate)
        return request
    }
}
