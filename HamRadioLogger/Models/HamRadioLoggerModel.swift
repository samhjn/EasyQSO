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

// 这个类负责设置Core Data模型
class HamRadioLoggerModel {
    static func createModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // 创建QSORecord实体
        let qsoRecordEntity = NSEntityDescription()
        qsoRecordEntity.name = "QSORecord"
        qsoRecordEntity.managedObjectClassName = "QSORecord"
        
        // 创建属性
        var properties: [NSAttributeDescription] = []
        
        // 呼号属性
        let callsignAttribute = NSAttributeDescription()
        callsignAttribute.name = "callsign"
        callsignAttribute.attributeType = .stringAttributeType
        callsignAttribute.isOptional = false
        properties.append(callsignAttribute)
        
        // 日期属性
        let dateAttribute = NSAttributeDescription()
        dateAttribute.name = "date"
        dateAttribute.attributeType = .dateAttributeType
        dateAttribute.isOptional = false
        properties.append(dateAttribute)
        
        // 波段属性
        let bandAttribute = NSAttributeDescription()
        bandAttribute.name = "band"
        bandAttribute.attributeType = .stringAttributeType
        bandAttribute.isOptional = false
        properties.append(bandAttribute)
        
        // 模式属性
        let modeAttribute = NSAttributeDescription()
        modeAttribute.name = "mode"
        modeAttribute.attributeType = .stringAttributeType
        modeAttribute.isOptional = false
        properties.append(modeAttribute)
        
        // 频率属性
        let frequencyAttribute = NSAttributeDescription()
        frequencyAttribute.name = "frequency"
        frequencyAttribute.attributeType = .doubleAttributeType
        frequencyAttribute.isOptional = false
        properties.append(frequencyAttribute)
        
        // 接收频率属性
        let rxFrequencyAttribute = NSAttributeDescription()
        rxFrequencyAttribute.name = "rxFrequency"
        rxFrequencyAttribute.attributeType = .doubleAttributeType
        rxFrequencyAttribute.isOptional = false
        rxFrequencyAttribute.defaultValue = 0.0
        properties.append(rxFrequencyAttribute)
        
        // 发射功率属性
        let txPowerAttribute = NSAttributeDescription()
        txPowerAttribute.name = "txPower"
        txPowerAttribute.attributeType = .stringAttributeType
        txPowerAttribute.isOptional = true
        properties.append(txPowerAttribute)
        
        // 发出的RST属性
        let rstSentAttribute = NSAttributeDescription()
        rstSentAttribute.name = "rstSent"
        rstSentAttribute.attributeType = .stringAttributeType
        rstSentAttribute.isOptional = false
        properties.append(rstSentAttribute)
        
        // 接收的RST属性
        let rstReceivedAttribute = NSAttributeDescription()
        rstReceivedAttribute.name = "rstReceived"
        rstReceivedAttribute.attributeType = .stringAttributeType
        rstReceivedAttribute.isOptional = false
        properties.append(rstReceivedAttribute)
        
        // 姓名属性
        let nameAttribute = NSAttributeDescription()
        nameAttribute.name = "name"
        nameAttribute.attributeType = .stringAttributeType
        nameAttribute.isOptional = true
        properties.append(nameAttribute)
        
        // QTH位置属性
        let qthAttribute = NSAttributeDescription()
        qthAttribute.name = "qth"
        qthAttribute.attributeType = .stringAttributeType
        qthAttribute.isOptional = true
        properties.append(qthAttribute)
        
        // 网格信息属性
        let gridSquareAttribute = NSAttributeDescription()
        gridSquareAttribute.name = "gridSquare"
        gridSquareAttribute.attributeType = .stringAttributeType
        gridSquareAttribute.isOptional = true
        properties.append(gridSquareAttribute)
        
        // CQ Zone属性
        let cqZoneAttribute = NSAttributeDescription()
        cqZoneAttribute.name = "cqZone"
        cqZoneAttribute.attributeType = .stringAttributeType
        cqZoneAttribute.isOptional = true
        properties.append(cqZoneAttribute)
        
        // ITU Zone属性
        let ituZoneAttribute = NSAttributeDescription()
        ituZoneAttribute.name = "ituZone"
        ituZoneAttribute.attributeType = .stringAttributeType
        ituZoneAttribute.isOptional = true
        properties.append(ituZoneAttribute)
        
        // 卫星信息属性
        let satelliteAttribute = NSAttributeDescription()
        satelliteAttribute.name = "satellite"
        satelliteAttribute.attributeType = .stringAttributeType
        satelliteAttribute.isOptional = true
        properties.append(satelliteAttribute)
        
        // 备注属性
        let remarksAttribute = NSAttributeDescription()
        remarksAttribute.name = "remarks"
        remarksAttribute.attributeType = .stringAttributeType
        remarksAttribute.isOptional = true
        properties.append(remarksAttribute)
        
        // 纬度属性
        let latitudeAttribute = NSAttributeDescription()
        latitudeAttribute.name = "latitude"
        latitudeAttribute.attributeType = .doubleAttributeType
        latitudeAttribute.isOptional = false
        latitudeAttribute.defaultValue = 0.0
        properties.append(latitudeAttribute)
        
        // 经度属性
        let longitudeAttribute = NSAttributeDescription()
        longitudeAttribute.name = "longitude"
        longitudeAttribute.attributeType = .doubleAttributeType
        longitudeAttribute.isOptional = false
        longitudeAttribute.defaultValue = 0.0
        properties.append(longitudeAttribute)
        
        // 将属性添加到实体
        qsoRecordEntity.properties = properties
        
        // 将实体添加到模型
        model.entities = [qsoRecordEntity]
        
        return model
    }
}

// 扩展PersistenceController以使用我们的模型
extension PersistenceController {
    static func createContainer() -> NSPersistentContainer {
        let model = HamRadioLoggerModel.createModel()
        let container = NSPersistentContainer(name: "HamRadioLogger", managedObjectModel: model)
        return container
    }
}
