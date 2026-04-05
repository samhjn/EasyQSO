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
    
    // 新版本：以Hz为单位的整数频率
    @NSManaged public var frequencyHz: Int64
    @NSManaged public var rxFrequencyHz: Int64
    
    // 旧版本数据迁移字段（以MHz为单位的浮点数，仅用于读取旧数据）
    // 使用带下划线的内部字段名来避免与计算属性冲突
    @NSManaged private var frequency: NSNumber?
    @NSManaged private var rxFrequency: NSNumber?
    
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
    // ADIF扩展字段（JSON存储）
    @NSManaged public var adifFieldsData: Data?
    
    // MARK: - 频率访问接口（兼容旧版本）
    
    /// 获取发射频率（MHz）- 用于显示和编辑
    public var frequencyMHz: Double {
        get {
            // 如果有新格式数据，使用新格式
            if frequencyHz > 0 {
                return Double(frequencyHz) / 1_000_000.0
            }
            // 否则尝试从旧格式读取
            return frequency?.doubleValue ?? 0.0
        }
        set {
            // 将MHz转换为Hz存储
            if newValue > 0 {
                frequencyHz = Int64(newValue * 1_000_000.0)
            } else {
                frequencyHz = 0
            }
            // 清除旧数据
            frequency = nil
        }
    }
    
    /// 获取接收频率（MHz）- 用于显示和编辑
    public var rxFrequencyMHz: Double {
        get {
            // 如果有新格式数据，使用新格式
            if rxFrequencyHz > 0 {
                return Double(rxFrequencyHz) / 1_000_000.0
            }
            // 否则尝试从旧格式读取
            return rxFrequency?.doubleValue ?? 0.0
        }
        set {
            // 将MHz转换为Hz存储
            if newValue > 0 {
                rxFrequencyHz = Int64(newValue * 1_000_000.0)
            } else {
                rxFrequencyHz = 0
            }
            // 清除旧数据
            rxFrequency = nil
        }
    }
    
    /// 获取发射频率的精确Hz值
    public var frequencyInHz: Int64 {
        get {
            if frequencyHz > 0 {
                return frequencyHz
            }
            // 从旧格式迁移
            if let legacy = frequency?.doubleValue, legacy > 0 {
                return Int64(legacy * 1_000_000.0)
            }
            return 0
        }
        set {
            frequencyHz = newValue
            frequency = nil
        }
    }
    
    /// 获取接收频率的精确Hz值
    public var rxFrequencyInHz: Int64 {
        get {
            if rxFrequencyHz > 0 {
                return rxFrequencyHz
            }
            // 从旧格式迁移
            if let legacy = rxFrequency?.doubleValue, legacy > 0 {
                return Int64(legacy * 1_000_000.0)
            }
            return 0
        }
        set {
            rxFrequencyHz = newValue
            rxFrequency = nil
        }
    }
    
    // MARK: - 数据迁移支持
    
    /// 检测并执行数据迁移（从旧的MHz格式迁移到新的Hz格式）
    public func migrateFrequencyDataIfNeeded() {
        var needsSave = false
        
        // 迁移发射频率
        if frequencyHz == 0, let legacyFreq = frequency?.doubleValue, legacyFreq > 0 {
            frequencyHz = Int64(legacyFreq * 1_000_000.0)
            frequency = nil
            needsSave = true
        }
        
        // 迁移接收频率
        if rxFrequencyHz == 0, let legacyRxFreq = rxFrequency?.doubleValue, legacyRxFreq > 0 {
            rxFrequencyHz = Int64(legacyRxFreq * 1_000_000.0)
            rxFrequency = nil
            needsSave = true
        }
        
        // 如果有数据迁移，保存上下文
        if needsSave, let context = managedObjectContext {
            do {
                try context.save()
                print("✓ 频率数据迁移成功: \(callsign)")
            } catch {
                print("✗ 频率数据迁移失败: \(error)")
            }
        }
    }
    
    /// 格式化频率显示（自动选择合适的单位）
    public func formattedFrequency(useMHz: Bool = true) -> String {
        let hz = frequencyInHz
        if hz == 0 { return "" }
        
        if useMHz {
            let mhz = Double(hz) / 1_000_000.0
            return String(format: "%.6f", mhz).trimmingCharacters(in: CharacterSet(charactersIn: "0")).trimmingCharacters(in: CharacterSet(charactersIn: "."))
        } else {
            return String(hz)
        }
    }
    
    /// 格式化接收频率显示（自动选择合适的单位）
    public func formattedRxFrequency(useMHz: Bool = true) -> String {
        let hz = rxFrequencyInHz
        if hz == 0 { return "" }
        
        if useMHz {
            let mhz = Double(hz) / 1_000_000.0
            return String(format: "%.6f", mhz).trimmingCharacters(in: CharacterSet(charactersIn: "0")).trimmingCharacters(in: CharacterSet(charactersIn: "."))
        } else {
            return String(hz)
        }
    }
    
    // MARK: - ADIF扩展字段存取
    
    var adifFields: [String: String] {
        get {
            guard let data = adifFieldsData,
                  let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
                return [:]
            }
            return dict
        }
        set {
            let filtered = newValue.filter { !$0.value.isEmpty }
            if filtered.isEmpty {
                adifFieldsData = nil
            } else {
                adifFieldsData = try? JSONEncoder().encode(filtered)
            }
        }
    }
    
    func adifValue(for tag: String) -> String? {
        guard let fieldDef = ADIFFields.field(for: tag) else { return nil }
        if let coreProp = fieldDef.coreProperty {
            return corePropertyValue(coreProp)
        }
        return adifFields[tag]
    }
    
    func setAdifValue(_ value: String?, for tag: String) {
        guard let fieldDef = ADIFFields.field(for: tag) else {
            if let v = value, !v.isEmpty {
                var fields = adifFields
                fields[tag] = v
                adifFields = fields
            }
            return
        }
        if let coreProp = fieldDef.coreProperty {
            setCorePropertyValue(coreProp, value: value)
        } else {
            var fields = adifFields
            fields[tag] = value
            adifFields = fields
        }
    }
    
    private func corePropertyValue(_ prop: String) -> String? {
        switch prop {
        case "callsign": return callsign.isEmpty ? nil : callsign
        case "band": return band.isEmpty ? nil : band
        case "mode": return mode.isEmpty ? nil : mode
        case "rstSent": return rstSent.isEmpty ? nil : rstSent
        case "rstReceived": return rstReceived.isEmpty ? nil : rstReceived
        case "txPower": return txPower
        case "name": return name
        case "qth": return qth
        case "gridSquare": return gridSquare
        case "cqZone": return cqZone
        case "ituZone": return ituZone
        case "satellite": return satellite
        case "remarks": return remarks
        case "frequencyHz":
            return frequencyMHz > 0 ? String(frequencyMHz) : nil
        case "rxFrequencyHz":
            return rxFrequencyMHz > 0 ? String(rxFrequencyMHz) : nil
        case "latitude":
            return latitude != 0 ? String(latitude) : nil
        case "longitude":
            return longitude != 0 ? String(longitude) : nil
        default: return nil
        }
    }
    
    private func setCorePropertyValue(_ prop: String, value: String?) {
        let v = value ?? ""
        switch prop {
        case "callsign": callsign = v
        case "band": band = v
        case "mode": mode = v
        case "rstSent": rstSent = v
        case "rstReceived": rstReceived = v
        case "txPower": txPower = v.isEmpty ? nil : v
        case "name": name = v.isEmpty ? nil : v
        case "qth": qth = v.isEmpty ? nil : v
        case "gridSquare": gridSquare = v.isEmpty ? nil : v
        case "cqZone": cqZone = v.isEmpty ? nil : v
        case "ituZone": ituZone = v.isEmpty ? nil : v
        case "satellite": satellite = v.isEmpty ? nil : v
        case "remarks": remarks = v.isEmpty ? nil : v
        case "frequencyHz": frequencyMHz = Double(v) ?? 0.0
        case "rxFrequencyHz": rxFrequencyMHz = Double(v) ?? 0.0
        case "latitude": latitude = Double(v) ?? 0.0
        case "longitude": longitude = Double(v) ?? 0.0
        default: break
        }
    }
    
    /// 获取所有非空ADIF字段（核心+扩展），用于导出
    func allAdifValues() -> [String: String] {
        var result = [String: String]()
        for field in ADIFFields.coreFields {
            if let val = corePropertyValue(field.coreProperty!) {
                result[field.id] = val
            }
        }
        for (key, val) in adifFields {
            if !val.isEmpty {
                result[key] = val
            }
        }
        return result
    }
    
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
    static func bandForFrequency(_ frequencyMHz: Double) -> String? {
        switch frequencyMHz {
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
    
    static var builtInModes: [String] { ModeManager.presetModes }
    static var allModes: [String] { ModeManager.shared.availableModes }
    
    static func lastRxFrequencyForRxBand(_ rxBand: String, context: NSManagedObjectContext) -> Double? {
        let request = NSFetchRequest<QSORecord>(entityName: "QSORecord")
        request.predicate = NSPredicate(format: "rxFrequencyHz > 0")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \QSORecord.date, ascending: false)]
        request.fetchLimit = 50
        
        do {
            let results = try context.fetch(request)
            for record in results {
                if let bandRx = record.adifFields["BAND_RX"], bandRx == rxBand {
                    return record.rxFrequencyMHz
                }
                if record.rxFrequencyMHz > 0,
                   QSORecord.bandForFrequency(record.rxFrequencyMHz) == rxBand {
                    return record.rxFrequencyMHz
                }
            }
        } catch {}
        return nil
    }
    
    // MARK: - Own QTH history lookup
    
    struct OwnQTHRecord {
        var myCity: String
        var myGridSquare: String
        var myCQZone: String
        var myITUZone: String
        var myLat: String?
        var myLon: String?
    }
    
    /// Priority-based lookup for own QTH from history:
    /// 1. Band + Mode match
    /// 2. Band-only match
    /// 3. Any record with MY_CITY
    /// 4. nil (leave empty)
    static func lastOwnQTHInfo(band: String, mode: String, context: NSManagedObjectContext) -> OwnQTHRecord? {
        if let result = fetchOwnQTH(band: band, mode: mode, context: context) {
            return result
        }
        if let result = fetchOwnQTH(band: band, mode: nil, context: context) {
            return result
        }
        if let result = fetchOwnQTH(band: nil, mode: nil, context: context) {
            return result
        }
        return nil
    }
    
    private static func fetchOwnQTH(band: String?, mode: String?, context: NSManagedObjectContext) -> OwnQTHRecord? {
        let request = NSFetchRequest<QSORecord>(entityName: "QSORecord")
        var predicates: [NSPredicate] = []
        if let band = band {
            predicates.append(NSPredicate(format: "band == %@", band))
        }
        if let mode = mode {
            predicates.append(NSPredicate(format: "mode == %@", mode))
        }
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        request.sortDescriptors = [NSSortDescriptor(keyPath: \QSORecord.date, ascending: false)]
        request.fetchLimit = 50
        
        do {
            let results = try context.fetch(request)
            for record in results {
                let fields = record.adifFields
                if let myCity = fields["MY_CITY"], !myCity.isEmpty {
                    return OwnQTHRecord(
                        myCity: myCity,
                        myGridSquare: fields["MY_GRIDSQUARE"] ?? "",
                        myCQZone: fields["MY_CQ_ZONE"] ?? "",
                        myITUZone: fields["MY_ITU_ZONE"] ?? "",
                        myLat: fields["MY_LAT"],
                        myLon: fields["MY_LON"]
                    )
                }
            }
        } catch {}
        return nil
    }
    
    // 获取指定波段的最后使用频率
    static func lastFrequencyForBand(_ band: String, context: NSManagedObjectContext) -> Double? {
        let request = NSFetchRequest<QSORecord>(entityName: "QSORecord")
        request.predicate = NSPredicate(format: "band == %@ AND frequencyHz > 0", band)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \QSORecord.date, ascending: false)]
        request.fetchLimit = 1
        
        do {
            let results = try context.fetch(request)
            return results.first?.frequencyMHz
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
