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

import SwiftUI
import CoreLocation

struct EditQSOView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var qthManager = QTHManager()
    @FocusState private var focusedField: FormField?
    
    let record: QSORecord
    
    // 使用简单的@State属性，避免复杂的状态管理
    @State private var callsign: String
    @State private var date: Date
    @State private var band: String
    @State private var mode: String
    @State private var frequency: String
    @State private var rxFrequency: String
    @State private var txPower: String
    @State private var rstSent: String
    @State private var rstReceived: String
    @State private var name: String
    @State private var qth: String
    @State private var gridSquare: String
    @State private var cqZone: String
    @State private var ituZone: String
    @State private var satellite: String
    @State private var remarks: String
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isValidationError = false
    
    // 频率和波段交互控制
    @State private var isBandChangedByFrequency = false
    
    // 己方QTH相关状态
    @State private var ownQTH = ""
    @State private var ownGridSquare = ""
    @State private var ownCQZone = ""
    @State private var ownITUZone = ""
    
    // 地图相关状态
    @State private var showingMapPicker = false
    @State private var showingOwnMapPicker = false
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var selectedOwnLocation: CLLocationCoordinate2D?
    @State private var mapPickerID = UUID() // 添加唯一标识符
    @State private var ownMapPickerID = UUID() // 添加唯一标识符
    
    // 添加状态来防止页面意外关闭
    @State private var isMapPickerActive = false
    
    let bands = ["160m", "80m", "40m", "30m", "20m", "17m", "15m", "12m", "10m", "6m", "2m", "70cm"]
    let modes = ["SSB", "CW", "FM", "AM", "RTTY", "PSK", "FT8", "FT4", "JT65"]
    
    init(record: QSORecord) {
        self.record = record
        
        // 直接初始化状态变量
        _callsign = State(initialValue: record.callsign)
        _date = State(initialValue: record.date)
        _band = State(initialValue: record.band)
        _mode = State(initialValue: record.mode)
        _frequency = State(initialValue: record.frequency > 0 ? String(record.frequency) : "")
        _rxFrequency = State(initialValue: record.rxFrequency > 0 ? String(record.rxFrequency) : "")
        _txPower = State(initialValue: record.txPower ?? "")
        _rstSent = State(initialValue: record.rstSent)
        _rstReceived = State(initialValue: record.rstReceived)
        _name = State(initialValue: record.name ?? "")
        _qth = State(initialValue: record.qth ?? "")
        _gridSquare = State(initialValue: record.gridSquare ?? "")
        _cqZone = State(initialValue: record.cqZone ?? "")
        _ituZone = State(initialValue: record.ituZone ?? "")
        _satellite = State(initialValue: record.satellite ?? "")
        _remarks = State(initialValue: record.remarks ?? "")
        
        // 坐标初始化：优先使用已存储的坐标，如果没有则尝试从网格坐标转换
        if let existingCoordinate = record.coordinate {
            // 使用已存储的坐标
            _selectedLocation = State(initialValue: existingCoordinate)
        } else if let gridSquare = record.gridSquare, !gridSquare.isEmpty {
            // 如果没有坐标但有网格坐标，尝试转换
            _selectedLocation = State(initialValue: QTHManager.coordinateFromGridSquare(gridSquare))
        } else {
            _selectedLocation = State(initialValue: nil)
        }
    }
    
    var body: some View {
        Form {
            Section(header: Text(LocalizedStrings.basicInfo.localized)) {
                TextField(LocalizedStrings.callsign.localized, text: $callsign)
                    .autocapitalization(.allCharacters)
                    .focused($focusedField, equals: .callsign)
                    .onChange(of: callsign) { newValue in
                        callsign = newValue.uppercased()
                    }
                
                DatePicker(LocalizedStrings.dateTime.localized, selection: $date)
                
                TextField(LocalizedStrings.frequency.localized, text: $frequency)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .frequency)
                    .onChange(of: frequency) { newValue in
                        // 当频率改变时，自动选择对应的波段
                        if let freq = Double(newValue), let autoBand = QSORecord.bandForFrequency(freq) {
                            if band != autoBand {
                                // 标记这次波段改变是由频率引起的
                                isBandChangedByFrequency = true
                                band = autoBand
                            }
                        }
                    }
                
                Picker(LocalizedStrings.band.localized, selection: $band) {
                    ForEach(bands, id: \.self) {
                        Text($0)
                    }
                }
                .onChange(of: band) { newBand in
                    // 如果波段改变是由频率引起的，不更新频率
                    if isBandChangedByFrequency {
                        // 重置标志
                        isBandChangedByFrequency = false
                    } else {
                        // 用户直接选择波段，自动填入该波段的最后使用频率
                        if let lastFreq = QSORecord.lastFrequencyForBand(newBand, context: viewContext) {
                            frequency = String(lastFreq)
                        }
                    }
                }
                
                Picker(LocalizedStrings.mode.localized, selection: $mode) {
                    ForEach(modes, id: \.self) {
                        Text($0)
                    }
                }
            }
            
            Section(header: Text(LocalizedStrings.signalReport.localized)) {
                TextField(LocalizedStrings.rstSent.localized, text: $rstSent)
                    .focused($focusedField, equals: .rstSent)
                    .onChange(of: rstSent) { newValue in
                        rstSent = newValue.uppercased()
                    }
                TextField(LocalizedStrings.rstReceived.localized, text: $rstReceived)
                    .focused($focusedField, equals: .rstReceived)
                    .onChange(of: rstReceived) { newValue in
                        rstReceived = newValue.uppercased()
                    }
            }
            
            Section(header: Text(LocalizedStrings.technicalInfo.localized)) {
                TextField(LocalizedStrings.rxFrequency.localized, text: $rxFrequency)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .rxFrequency)
                
                TextField(LocalizedStrings.txPower.localized, text: $txPower)
                    .focused($focusedField, equals: .txPower)
                
                TextField(LocalizedStrings.satellite.localized, text: $satellite)
                    .focused($focusedField, equals: .satellite)
            }
            
            // 己方QTH信息段落
            Section(header: Text(LocalizedStrings.ownQthInfo.localized)) {
                HStack {
                    TextField(LocalizedStrings.ownQth.localized, text: $ownQTH)
                        .focused($focusedField, equals: .ownQTH)
                    
                    Button(LocalizedStrings.selectOnMap.localized) {
                        // 关闭键盘后再打开地图选择器
                        focusedField = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            ownMapPickerID = UUID()
                            isMapPickerActive = true
                            showingOwnMapPicker = true
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                TextField(LocalizedStrings.gridSquare.localized, text: $ownGridSquare)
                    .focused($focusedField, equals: .ownGridSquare)
                    .onChange(of: ownGridSquare) { newValue in
                        // 修复网格坐标格式：前4位大写，后2位小写
                        ownGridSquare = formatGridSquare(newValue)
                    }
                
                TextField(LocalizedStrings.cqZone.localized, text: $ownCQZone)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .ownCQZone)
                
                TextField(LocalizedStrings.ituZone.localized, text: $ownITUZone)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .ownITUZone)
            }
            
            // 对方QTH信息段落
            Section(header: Text(LocalizedStrings.qthInfo.localized)) {
                HStack {
                    TextField(LocalizedStrings.qth.localized, text: $qth)
                        .focused($focusedField, equals: .qth)
                    
                    Button(LocalizedStrings.selectOnMap.localized) {
                        // 关闭键盘后再打开地图选择器
                        focusedField = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            mapPickerID = UUID()
                            isMapPickerActive = true
                            showingMapPicker = true
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                TextField(LocalizedStrings.gridSquare.localized, text: $gridSquare)
                    .focused($focusedField, equals: .gridSquare)
                    .onChange(of: gridSquare) { newValue in
                        // 修复网格坐标格式：前4位大写，后2位小写
                        gridSquare = formatGridSquare(newValue)
                    }
                
                TextField(LocalizedStrings.cqZone.localized, text: $cqZone)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .cqZone)
                
                TextField(LocalizedStrings.ituZone.localized, text: $ituZone)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .ituZone)
            }
            
            Section(header: Text(LocalizedStrings.additionalInfo.localized)) {
                TextField(LocalizedStrings.name.localized, text: $name)
                    .focused($focusedField, equals: .name)
                TextField(LocalizedStrings.remarks.localized, text: $remarks)
                    .focused($focusedField, equals: .remarks)
            }
            
            Section {
                Button(action: {
                    // 先关闭键盘
                    focusedField = nil
                    // 延迟一小会儿再执行保存，确保键盘已关闭
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if validateInputs() {
                            updateQSO()
                        }
                    }
                }) {
                    Text(LocalizedStrings.saveChanges.localized)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle(LocalizedStrings.editQSO.localized)
        .toolbar {
            KeyboardToolbar(focusedField: $focusedField)
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage)
            )
        }
        .fullScreenCover(isPresented: $showingMapPicker) {
            EnhancedMapLocationPicker(
                selectedLocation: $selectedLocation,
                locationName: $qth,
                gridSquare: $gridSquare,
                editMode: .otherQTH
            )
            .id(mapPickerID)
            .onDisappear {
                isMapPickerActive = false
            }
        }
        .fullScreenCover(isPresented: $showingOwnMapPicker) {
            EnhancedMapLocationPicker(
                selectedLocation: $selectedOwnLocation,
                locationName: $ownQTH,
                gridSquare: $ownGridSquare,
                editMode: .ownQTH
            )
            .id(ownMapPickerID)
            .onDisappear {
                isMapPickerActive = false
            }
        }
        .onAppear {
            // 延迟加载己方QTH信息，避免在视图初始化时触发状态更新
            DispatchQueue.main.async {
                loadOwnQTHInfo()
            }
        }
    }
    
    private func loadOwnQTHInfo() {
        // 只在值不同时才更新，避免不必要的状态变化
        if ownQTH != qthManager.ownQTH.location {
            ownQTH = qthManager.ownQTH.location
        }
        if ownGridSquare != qthManager.ownQTH.gridSquare {
            ownGridSquare = qthManager.ownQTH.gridSquare
        }
        if ownCQZone != qthManager.ownQTH.cqZone {
            ownCQZone = qthManager.ownQTH.cqZone
        }
        if ownITUZone != qthManager.ownQTH.ituZone {
            ownITUZone = qthManager.ownQTH.ituZone
        }
        // 比较坐标，需要手动比较经纬度
        let currentCoordinate = selectedOwnLocation
        let savedCoordinate = qthManager.ownQTH.coordinate
        if currentCoordinate?.latitude != savedCoordinate?.latitude || 
           currentCoordinate?.longitude != savedCoordinate?.longitude {
            selectedOwnLocation = qthManager.ownQTH.coordinate
        }
    }
    
    // 格式化网格坐标：前4位大写，后2位小写
    private func formatGridSquare(_ input: String) -> String {
        let cleaned = input.uppercased().replacingOccurrences(of: " ", with: "")
        if cleaned.count <= 4 {
            return cleaned
        } else if cleaned.count >= 6 {
            let prefix = String(cleaned.prefix(4))
            let suffix = String(cleaned.dropFirst(4).prefix(2)).lowercased()
            return prefix + suffix
        } else {
            return cleaned
        }
    }
    
    private func validateInputs() -> Bool {
        isValidationError = false
        
        // 验证呼号
        if callsign.isEmpty {
            showValidationError(LocalizedStrings.callsignEmpty.localized)
            return false
        }
        
        let callsignPattern = "^[A-Z0-9/]+$"
        let callsignRegex = try! NSRegularExpression(pattern: callsignPattern)
        let callsignRange = NSRange(location: 0, length: callsign.count)
        if callsignRegex.firstMatch(in: callsign, options: [], range: callsignRange) == nil {
            showValidationError(LocalizedStrings.callsignInvalid.localized)
            return false
        }
        
        // 验证频率
        if !frequency.isEmpty && !isValidFrequency(frequency) {
            showValidationError(LocalizedStrings.frequencyInvalid.localized)
            return false
        }
        
        // 验证网格坐标
        if !gridSquare.isEmpty && !QTHManager.isValidGridSquare(gridSquare) {
            showValidationError(LocalizedStrings.gridSquareInvalid.localized)
            return false
        }
        
        if !ownGridSquare.isEmpty && !QTHManager.isValidGridSquare(ownGridSquare) {
            showValidationError(LocalizedStrings.gridSquareInvalid.localized)
            return false
        }
        
        // 验证CQ Zone
        if !cqZone.isEmpty && !QTHManager.isValidCQZone(cqZone) {
            showValidationError(LocalizedStrings.cqZoneInvalid.localized)
            return false
        }
        
        if !ownCQZone.isEmpty && !QTHManager.isValidCQZone(ownCQZone) {
            showValidationError(LocalizedStrings.cqZoneInvalid.localized)
            return false
        }
        
        // 验证ITU Zone
        if !ituZone.isEmpty && !QTHManager.isValidITUZone(ituZone) {
            showValidationError(LocalizedStrings.ituZoneInvalid.localized)
            return false
        }
        
        if !ownITUZone.isEmpty && !QTHManager.isValidITUZone(ownITUZone) {
            showValidationError(LocalizedStrings.ituZoneInvalid.localized)
            return false
        }
        
        return true
    }
    
    private func showValidationError(_ message: String) {
        isValidationError = true
        alertTitle = LocalizedStrings.validationError.localized
        alertMessage = message
        showingAlert = true
    }
    
    private func isValidFrequency(_ freqString: String) -> Bool {
        guard let freq = Double(freqString) else { return false }
        // 业余无线电频率范围验证 (0.1 MHz to 6000 MHz)
        return freq > 0.1 && freq < 6000
    }
    
    private func updateQSO() {
        // 先保存己方QTH信息
        qthManager.updateOwnQTH(
            location: ownQTH,
            gridSquare: ownGridSquare,
            cqZone: ownCQZone,
            ituZone: ownITUZone,
            coordinate: selectedOwnLocation
        )
        
        record.callsign = callsign
        record.date = date
        record.band = band
        record.mode = mode
        record.frequency = Double(frequency) ?? 0.0
        record.rxFrequency = Double(rxFrequency) ?? 0.0
        record.txPower = txPower.isEmpty ? nil : txPower
        record.rstSent = rstSent
        record.rstReceived = rstReceived
        record.name = name
        record.qth = qth
        record.gridSquare = gridSquare.isEmpty ? nil : gridSquare
        record.cqZone = cqZone.isEmpty ? nil : cqZone
        record.ituZone = ituZone.isEmpty ? nil : ituZone
        record.satellite = satellite.isEmpty ? nil : satellite
        record.remarks = remarks
        
        // 保存坐标信息
        record.setCoordinate(selectedLocation)
        
        do {
            try viewContext.save()
            // 保存成功后显示提示
            alertTitle = LocalizedStrings.saveSuccess.localized
            alertMessage = LocalizedStrings.qsoUpdated.localized
            showingAlert = true
        } catch {
            alertTitle = LocalizedStrings.saveFailed.localized
            alertMessage = String(format: LocalizedStrings.saveFailedMessage.localized, error.localizedDescription)
            showingAlert = true
        }
    }
}
