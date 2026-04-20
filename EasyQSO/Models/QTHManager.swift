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
import CoreLocation

class QTHManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    
    private var locationManager: CLLocationManager?
    private var locationCompletion: ((CLLocationCoordinate2D?) -> Void)?
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    // MARK: - 定位管理
    
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationAuthorizationStatus = locationManager?.authorizationStatus ?? .notDetermined
    }
    
    func requestLocationPermission() {
        guard let locationManager = locationManager else { return }
        
        switch locationAuthorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            // 用户已拒绝，可以显示提示让用户去设置中开启
            break
        case .authorizedWhenInUse, .authorizedAlways:
            // 已有权限，可以获取位置
            break
        @unknown default:
            break
        }
    }
    
    func getCurrentLocation(completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        guard let locationManager = locationManager else {
            completion(nil)
            return
        }
        
        switch locationAuthorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationCompletion = completion
            locationManager.requestLocation()
        case .notDetermined:
            locationCompletion = completion
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            completion(nil)
        @unknown default:
            completion(nil)
        }
    }
    
    var hasLocationPermission: Bool {
        return locationAuthorizationStatus == .authorizedWhenInUse || 
               locationAuthorizationStatus == .authorizedAlways
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            locationCompletion?(nil)
            locationCompletion = nil
            return
        }
        
        let coordinate = location.coordinate
        currentLocation = coordinate
        locationCompletion?(coordinate)
        locationCompletion = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("定位失败: \(error.localizedDescription)")
        locationCompletion?(nil)
        locationCompletion = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        locationAuthorizationStatus = status
        
        // 如果权限状态改变后有等待的定位请求，尝试获取位置
        if let completion = locationCompletion {
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                completion(nil)
                locationCompletion = nil
            default:
                break
            }
        }
    }
    
    // MARK: - 网格坐标计算

    /// 每对 Maidenhead 字符对应的经纬度跨度（经度, 纬度）。
    /// 共 6 对 = 12 字符，覆盖 4/6/8/10/12 字符精度。
    private static let pairSpans: [(lon: Double, lat: Double)] = [
        (20.0,                10.0),                  // 1-2: A-R
        (2.0,                 1.0),                   // 3-4: 0-9
        (2.0/24.0,            1.0/24.0),              // 5-6: a-x
        (2.0/24.0/10.0,       1.0/24.0/10.0),         // 7-8: 0-9
        (2.0/24.0/10.0/24.0,  1.0/24.0/10.0/24.0),    // 9-10: a-x
        (2.0/24.0/10.0/24.0/10.0, 1.0/24.0/10.0/24.0/10.0)  // 11-12: 0-9
    ]

    /// 从坐标计算指定精度的网格坐标。
    ///
    /// - Parameters:
    ///   - coordinate: 经纬度
    ///   - precision: 字符数，必须为 4、6、8、10、12 之一；其它值会被钳制
    /// - Returns: 规范化的网格字符串（1-2 大写、3-4 数字、5-6 小写、依此类推）
    ///
    /// 注：精度偏好仅影响应用 *生成* 的网格坐标；已存储或用户输入的值不会被修改。
    static func calculateGridSquare(from coordinate: CLLocationCoordinate2D,
                                    precision: Int) -> String {
        let clamped = max(4, min(12, precision - (precision % 2)))
        let pairCount = clamped / 2

        var lon = coordinate.longitude + 180.0
        var lat = coordinate.latitude + 90.0
        var out = ""
        out.reserveCapacity(clamped)

        for pair in 0..<pairCount {
            let span = pairSpans[pair]
            // 钳制至各对的合法上限，避免接近 180°/90° 边界时浮点累积误差越界
            let upper: Int = (pair == 0) ? 17 : (pair % 2 == 0 ? 23 : 9)
            var i = Int(lon / span.lon)
            var j = Int(lat / span.lat)
            if i < 0 { i = 0 } else if i > upper { i = upper }
            if j < 0 { j = 0 } else if j > upper { j = upper }
            switch pair {
            case 0:
                out.append(Character(UnicodeScalar(65 + i)!))
                out.append(Character(UnicodeScalar(65 + j)!))
            case 2, 4:
                out.append(Character(UnicodeScalar(97 + i)!))
                out.append(Character(UnicodeScalar(97 + j)!))
            default: // 1, 3, 5
                out.append(Character("\(i)"))
                out.append(Character("\(j)"))
            }
            lon -= Double(i) * span.lon
            lat -= Double(j) * span.lat
        }

        return out
    }

    /// 兼容性入口：调用方未指定精度时，使用用户偏好。
    static func calculateGridSquare(from coordinate: CLLocationCoordinate2D) -> String {
        return calculateGridSquare(from: coordinate,
                                   precision: GridPrecisionManager.shared.displayPrecision)
    }

    // 验证网格坐标格式（接受 4/6/8/10/12 字符，大小写不敏感）
    static func isValidGridSquare(_ gridSquare: String) -> Bool {
        let pattern = "^[A-R]{2}[0-9]{2}([A-X]{2}([0-9]{2}([A-X]{2}([0-9]{2})?)?)?)?$"
        let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: gridSquare.count)
        return regex.firstMatch(in: gridSquare, options: [], range: range) != nil
    }

    // 验证CQ Zone
    static func isValidCQZone(_ zone: String) -> Bool {
        guard let zoneNumber = Int(zone) else { return false }
        return zoneNumber >= 1 && zoneNumber <= 40
    }

    // 验证ITU Zone
    static func isValidITUZone(_ zone: String) -> Bool {
        guard let zoneNumber = Int(zone) else { return false }
        return zoneNumber >= 1 && zoneNumber <= 90
    }

    /// 从网格坐标解码出大致坐标（返回最末单元的中心）。
    /// 支持 4/6/8/10/12 字符；其它长度返回 nil。
    static func coordinateFromGridSquare(_ gridSquare: String) -> CLLocationCoordinate2D? {
        guard isValidGridSquare(gridSquare) else { return nil }
        let length = gridSquare.count
        guard [4, 6, 8, 10, 12].contains(length) else { return nil }

        // 规范化大小写：第 1-2、3-4 字符当作大写处理，其余对齐预期
        let chars = Array(gridSquare)
        let pairCount = length / 2

        var longitude = -180.0
        var latitude = -90.0

        for pair in 0..<pairCount {
            let c1 = chars[pair * 2]
            let c2 = chars[pair * 2 + 1]
            let span = pairSpans[pair]

            switch pair {
            case 0:
                guard let i = letterIndex(c1, base: 65, max: 17),
                      let j = letterIndex(c2, base: 65, max: 17) else { return nil }
                longitude += Double(i) * span.lon
                latitude += Double(j) * span.lat
            case 2, 4:
                guard let i = letterIndex(c1, base: 97, max: 23),
                      let j = letterIndex(c2, base: 97, max: 23) else { return nil }
                longitude += Double(i) * span.lon
                latitude += Double(j) * span.lat
            default: // 1, 3, 5: 数字
                guard let i = c1.wholeNumberValue,
                      let j = c2.wholeNumberValue,
                      i >= 0 && i <= 9, j >= 0 && j <= 9 else { return nil }
                longitude += Double(i) * span.lon
                latitude += Double(j) * span.lat
            }
        }

        // 移动到最末单元中心
        let finestSpan = pairSpans[pairCount - 1]
        longitude += finestSpan.lon / 2.0
        latitude += finestSpan.lat / 2.0

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// 将字母字符转换为 0-based 索引，自动处理大小写；超出范围返回 nil。
    /// - Parameters:
    ///   - char: 字符
    ///   - base: 'A' (65) 或 'a' (97)
    ///   - max: 索引上限（含），如 A-R 为 17，a-x 为 23
    private static func letterIndex(_ char: Character, base: UInt8, max: UInt8) -> Int? {
        guard let ascii = char.asciiValue else { return nil }
        // 统一大小写：base==65 时把小写转大写；base==97 时把大写转小写
        var normalized = ascii
        if base == 65, ascii >= 97 && ascii <= 122 { normalized = ascii - 32 }
        if base == 97, ascii >= 65 && ascii <= 90 { normalized = ascii + 32 }
        guard normalized >= base && normalized <= base + max else { return nil }
        return Int(normalized - base)
    }
}

// CLLocationCoordinate2D 扩展
extension CLLocationCoordinate2D {
    // 计算两个坐标点之间的距离（米）
    func distance(to coordinate: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let location2 = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return location1.distance(from: location2)
    }
} 