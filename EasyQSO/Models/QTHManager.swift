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

// 己方QTH信息结构
struct OwnQTHInfo {
    var location: String
    var gridSquare: String
    var cqZone: String
    var ituZone: String
    var coordinate: CLLocationCoordinate2D?
    
    init() {
        self.location = ""
        self.gridSquare = ""
        self.cqZone = ""
        self.ituZone = ""
        self.coordinate = nil
    }
}

class QTHManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var ownQTH = OwnQTHInfo()
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    
    private let defaults = UserDefaults.standard
    private let ownQTHLocationKey = "ownQTHLocation"
    private let ownQTHGridSquareKey = "ownQTHGridSquare"
    private let ownQTHCQZoneKey = "ownQTHCQZone"
    private let ownQTHITUZoneKey = "ownQTHITUZone"
    private let ownQTHLatitudeKey = "ownQTHLatitude"
    private let ownQTHLongitudeKey = "ownQTHLongitude"
    
    private var locationManager: CLLocationManager?
    private var locationCompletion: ((CLLocationCoordinate2D?) -> Void)?
    
    override init() {
        super.init()
        setupLocationManager()
        loadOwnQTH()
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
    
    // MARK: - 己方QTH信息管理
    
    // 加载己方QTH信息
    func loadOwnQTH() {
        ownQTH.location = defaults.string(forKey: ownQTHLocationKey) ?? ""
        ownQTH.gridSquare = defaults.string(forKey: ownQTHGridSquareKey) ?? ""
        ownQTH.cqZone = defaults.string(forKey: ownQTHCQZoneKey) ?? ""
        ownQTH.ituZone = defaults.string(forKey: ownQTHITUZoneKey) ?? ""
        
        let latitude = defaults.double(forKey: ownQTHLatitudeKey)
        let longitude = defaults.double(forKey: ownQTHLongitudeKey)
        if latitude != 0 || longitude != 0 {
            ownQTH.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }
    
    // 保存己方QTH信息
    func saveOwnQTH() {
        defaults.set(ownQTH.location, forKey: ownQTHLocationKey)
        defaults.set(ownQTH.gridSquare, forKey: ownQTHGridSquareKey)
        defaults.set(ownQTH.cqZone, forKey: ownQTHCQZoneKey)
        defaults.set(ownQTH.ituZone, forKey: ownQTHITUZoneKey)
        
        if let coordinate = ownQTH.coordinate {
            defaults.set(coordinate.latitude, forKey: ownQTHLatitudeKey)
            defaults.set(coordinate.longitude, forKey: ownQTHLongitudeKey)
        }
        
        defaults.synchronize()
    }
    
    // 更新己方QTH信息
    func updateOwnQTH(location: String, gridSquare: String, cqZone: String, ituZone: String, coordinate: CLLocationCoordinate2D? = nil) {
        ownQTH.location = location
        ownQTH.gridSquare = gridSquare
        ownQTH.cqZone = cqZone
        ownQTH.ituZone = ituZone
        ownQTH.coordinate = coordinate
        saveOwnQTH()
    }
    
    // 从坐标计算网格坐标
    static func calculateGridSquare(from coordinate: CLLocationCoordinate2D) -> String {
        let longitude = coordinate.longitude + 180
        let latitude = coordinate.latitude + 90
        
        let field1 = Int(longitude / 20)
        let field2 = Int(latitude / 10)
        let square1 = Int((longitude.truncatingRemainder(dividingBy: 20)) / 2)
        let square2 = Int((latitude.truncatingRemainder(dividingBy: 10)) / 1)
        
        let subsquare1 = Int(((longitude.truncatingRemainder(dividingBy: 20)).truncatingRemainder(dividingBy: 2)) / (2.0/24.0))
        let subsquare2 = Int(((latitude.truncatingRemainder(dividingBy: 10)).truncatingRemainder(dividingBy: 1)) / (1.0/24.0))
        
        let fieldChar1 = String(UnicodeScalar(65 + field1)!)
        let fieldChar2 = String(UnicodeScalar(65 + field2)!)
        let subsquareChar1 = String(UnicodeScalar(97 + subsquare1)!)
        let subsquareChar2 = String(UnicodeScalar(97 + subsquare2)!)
        
        return "\(fieldChar1)\(fieldChar2)\(square1)\(square2)\(subsquareChar1)\(subsquareChar2)"
    }
    
    // 验证网格坐标格式
    static func isValidGridSquare(_ gridSquare: String) -> Bool {
        let pattern = "^[A-R]{2}[0-9]{2}([a-x]{2})?$"
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
    
    // 从网格坐标计算大致坐标
    static func coordinateFromGridSquare(_ gridSquare: String) -> CLLocationCoordinate2D? {
        guard isValidGridSquare(gridSquare) && gridSquare.count >= 4 else { return nil }
        
        let upperGrid = gridSquare.uppercased()
        
        // 安全地处理field字符 (A-R)
        guard let fieldChar1 = upperGrid.first,
              let fieldChar2 = upperGrid.dropFirst().first,
              let fieldAscii1 = fieldChar1.asciiValue,
              let fieldAscii2 = fieldChar2.asciiValue,
              fieldAscii1 >= 65 && fieldAscii1 <= 82,  // A-R
              fieldAscii2 >= 65 && fieldAscii2 <= 82   // A-R
        else {
            return nil // 如果field字符无效，返回nil
        }
        
        let field1 = Int(fieldAscii1 - 65)
        let field2 = Int(fieldAscii2 - 65)
        
        // 安全地处理square数字 (0-9)
        guard let squareChar1 = upperGrid.dropFirst(2).first,
              let squareChar2 = upperGrid.dropFirst(3).first,
              let square1 = Int(String(squareChar1)),
              let square2 = Int(String(squareChar2))
        else {
            return nil // 如果square字符无效，返回nil
        }
        
        var longitude = Double(field1 * 20) + Double(square1 * 2) - 180
        var latitude = Double(field2 * 10) + Double(square2 * 1) - 90
        
        // 如果有子网格，添加精度
        if gridSquare.count >= 6 {
            let char5 = gridSquare.dropFirst(4).first!
            let char6 = gridSquare.dropFirst(5).first!
            
            // 安全地检查字符是否在有效范围内 (a-x)
            guard let ascii5 = char5.asciiValue, 
                  let ascii6 = char6.asciiValue,
                  ascii5 >= 97 && ascii5 <= 120,  // a-x
                  ascii6 >= 97 && ascii6 <= 120   // a-x
            else {
                return nil // 如果subsquare字符无效，返回nil
            }
            
            let subsquare1 = Int(ascii5 - 97)
            let subsquare2 = Int(ascii6 - 97)
            longitude += Double(subsquare1) * (2.0/24.0)
            latitude += Double(subsquare2) * (1.0/24.0)
        }
        
        // 移动到网格中心
        longitude += 1.0
        latitude += 0.5
        
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
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