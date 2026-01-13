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

struct QSORecordView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var qthManager = QTHManager()
    @FocusState private var focusedField: FormField?
    
    @State private var callsign = ""
    @State private var date = Date()
    @State private var band = "20m"
    @State private var mode = "SSB"
    @State private var frequency = ""
    @State private var rxFrequency = ""
    @State private var txPower = ""
    @State private var rstSent = ""
    @State private var rstReceived = ""
    @State private var name = ""
    @State private var qth = ""
    @State private var gridSquare = ""
    @State private var cqZone = ""
    @State private var ituZone = ""
    @State private var satellite = ""
    @State private var remarks = ""
    @State private var showingAlert = false
    @State private var alertTitle = "QSO已保存"
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
    
    let bands = ["160m", "80m", "40m", "30m", "20m", "17m", "15m", "12m", "10m", "6m", "2m", "70cm"]
    let modes = ["SSB", "CW", "FM", "AM", "RTTY", "PSK", "FT8", "FT4", "JT65"]
    
    var body: some View {
        ZStack {
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
            }
            .safeAreaInset(edge: .bottom) {
                // 为悬浮按钮预留空间
                Color.clear.frame(height: 80)
            }
            
            // 悬浮保存按钮
            VStack {
                Spacer()
                
                Button(action: {
                    // 先关闭键盘
                    focusedField = nil
                    // 延迟一小会儿再执行保存，确保键盘已关闭
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        if validateInputs() {
                            saveQSO()
                        }
                    }
                }) {
                    Text(LocalizedStrings.saveQSO.localized)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .background(
                    // 渐变背景，确保按钮清晰可见
                    LinearGradient(
                        colors: [Color.clear, Color(UIColor.systemBackground).opacity(0.9)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 100)
                )
            }
            // 让悬浮按钮可以响应点击，不被下层视图拦截
            .allowsHitTesting(true)
        }
        .navigationTitle(LocalizedStrings.recordQSO.localized)
        .toolbar {
            KeyboardToolbar(focusedField: $focusedField)
        }
        .background(
            EmptyView()
                .alert(isPresented: $showingAlert) {
                    Alert(
                        title: Text(alertTitle),
                        message: Text(alertMessage)
                    )
                }
        )
        .fullScreenCover(isPresented: $showingMapPicker) {
            EnhancedMapLocationPicker(
                selectedLocation: $selectedLocation,
                locationName: $qth,
                gridSquare: $gridSquare,
                editMode: .otherQTH
            )
            .id(UUID())
        }
        .fullScreenCover(isPresented: $showingOwnMapPicker) {
            EnhancedMapLocationPicker(
                selectedLocation: $selectedOwnLocation,
                locationName: $ownQTH,
                gridSquare: $ownGridSquare,
                editMode: .ownQTH
            )
            .id(UUID())
        }
        .onChange(of: showingAlert) { isShowing in
            if isShowing {
                // 所有弹窗自动关闭
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    showingAlert = false
                    
                    // 只有成功保存QSO后才清除字段
                    if !isValidationError {
                        clearFields()
                    }
                }
            }
        }
        .onAppear {
            // 延迟加载己方QTH信息，避免在视图初始化时触发状态更新
            DispatchQueue.main.async {
                loadOwnQTHInfo()
                loadLatestQSOSettings()
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
    
    private func loadLatestQSOSettings() {
        // 获取最近的QSO记录并设置波段和模式
        if let latestQSO = QSORecord.getLatestQSO(context: viewContext) {
            band = latestQSO.band
            mode = latestQSO.mode
            // 如果最近QSO有频率信息，也可以设置频率
            if latestQSO.frequency > 0 {
                frequency = String(latestQSO.frequency)
            }
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
    
    private func saveQSO() {
        // 先保存己方QTH信息
        qthManager.updateOwnQTH(
            location: ownQTH,
            gridSquare: ownGridSquare,
            cqZone: ownCQZone,
            ituZone: ownITUZone,
            coordinate: selectedOwnLocation
        )
        
        let newQSO = QSORecord(context: viewContext)
        newQSO.callsign = callsign
        newQSO.date = date
        newQSO.band = band
        newQSO.mode = mode
        newQSO.frequency = Double(frequency) ?? 0.0
        newQSO.rxFrequency = Double(rxFrequency) ?? 0.0
        newQSO.txPower = txPower.isEmpty ? nil : txPower
        newQSO.rstSent = rstSent
        newQSO.rstReceived = rstReceived
        newQSO.name = name
        newQSO.qth = qth
        newQSO.gridSquare = gridSquare.isEmpty ? nil : gridSquare
        newQSO.cqZone = cqZone.isEmpty ? nil : cqZone
        newQSO.ituZone = ituZone.isEmpty ? nil : ituZone
        newQSO.satellite = satellite.isEmpty ? nil : satellite
        newQSO.remarks = remarks
        
        // 保存坐标信息
        newQSO.setCoordinate(selectedLocation)
        
        do {
            try viewContext.save()
            alertTitle = LocalizedStrings.qsoSaved.localized
            alertMessage = LocalizedStrings.qsoSavedMessage.localized
            showingAlert = true
        } catch {
            alertTitle = LocalizedStrings.saveFailed.localized
            alertMessage = String(format: LocalizedStrings.saveFailedMessage.localized, error.localizedDescription)
            showingAlert = true
        }
    }
    
    private func clearFields() {
        // 保存当前技术信息值（除了对方QTH详情外，其他字段保持不变）
        let currentFrequency = frequency
        let currentBand = band
        let currentMode = mode
        let currentRxFrequency = rxFrequency
        let currentTxPower = txPower
        let currentSatellite = satellite
        
        callsign = ""
        date = Date()
        // 保留波段不变
        band = currentBand
        // 保留模式不变
        mode = currentMode
        // 保留频率不变
        frequency = currentFrequency
        // 保留RX频率不变
        rxFrequency = currentRxFrequency
        // 保留发射功率不变
        txPower = currentTxPower
        // 保留卫星信息不变
        satellite = currentSatellite
        rstSent = ""
        rstReceived = ""
        name = ""
        qth = ""
        // 清空对方QTH详情
        gridSquare = ""
        cqZone = ""
        ituZone = ""
        selectedLocation = nil
        remarks = ""
        
        // 己方QTH信息保持不变（继承上次记录）
    }
    
    // 格式化网格坐标：前4位大写，后2位小写
    private func formatGridSquare(_ input: String) -> String {
        let cleaned = input.replacingOccurrences(of: " ", with: "")
        if cleaned.count <= 4 {
            return cleaned.uppercased()
        } else if cleaned.count >= 6 {
            let prefix = String(cleaned.prefix(4)).uppercased()
            let suffix = String(cleaned.dropFirst(4).prefix(2)).lowercased()
            return prefix + suffix
        } else {
            return cleaned.uppercased()
        }
    }
}
