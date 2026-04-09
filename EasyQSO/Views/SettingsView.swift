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
import UniformTypeIdentifiers
import CoreData
import MobileCoreServices
import UIKit

struct SettingsView: View {
    @Binding var scrollToGPL: Bool
    
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \QSORecord.date, ascending: false)],
        animation: .default)
    private var qsoRecords: FetchedResults<QSORecord>
    
    @State private var exportFormat = "ADIF"
    @State private var exportTimezone = TimezoneManager.getExportTimezone()
    @State private var importTimezone = TimezoneManager.getImportTimezone()
    @State private var showingImportPicker = false
    @State private var importedData: Data?
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingTimezoneSettings = false
    @State private var timezoneSettingsInitialTab = 0
    @StateObject private var documentPickerDelegate = DocumentPickerDelegate()
    @State private var documentInteractionDelegate = DocumentInteractionDelegate()
    
    // 字段设置
    @State private var showingFieldSettings = false
    @State private var navigateToDXCCData = false
    @ObservedObject private var visibilityManager = FieldVisibilityManager.shared
    @ObservedObject private var modeManager = ModeManager.shared
    @ObservedObject private var autoFillManager = AutoFillManager.shared
    @ObservedObject private var dxccManager = DXCCManager.shared
    @ObservedObject private var fieldVisibility = FieldVisibilityManager.shared
    
    
    // 导入报告相关
    @State private var showingImportReport = false
    @State private var importResult: ImportResult?
    @State private var importHasDetails = false
    
    // 导出筛选相关状态
    @State private var showingExportFilter = false
    @State private var exportFilterCriteria = FilterCriteria()
    @State private var useFilterForExport = false
    
    init(scrollToGPL: Binding<Bool> = .constant(false)) {
        self._scrollToGPL = scrollToGPL
    }
    
    let exportFormats = ["ADIF", "CSV"]
    
    private var isDXCCEnabled: Bool {
        fieldVisibility.visibility(for: "DXCC") != .hidden
    }

    private var isZonesEnabled: Bool {
        fieldVisibility.groupVisibility(for: "group_contacted_qth") != .hidden
    }

    private var anyPrefixLookupFieldEnabled: Bool {
        isDXCCEnabled || isZonesEnabled
    }

    var fieldSettingsSummary: String {
        // Access visibilityManager (an @ObservedObject) so SwiftUI
        // re-renders this view when field visibility changes.
        let _ = visibilityManager.revision
        var visible = 0
        for field in ADIFFields.all {
            if visibilityManager.visibility(for: field.id) == .visible { visible += 1 }
        }
        return "\(visible)/\(ADIFFields.all.count)"
    }
    
    var filteredExportRecords: [QSORecord] {
        let records = Array(qsoRecords)
        if useFilterForExport && exportFilterCriteria.hasActiveFilters {
            return exportFilterCriteria.apply(to: records)
        }
        return records
    }
    
    var availableBands: [String] {
        Array(qsoRecords).uniqueBands()
    }
    
    var availableModes: [String] {
        Array(qsoRecords).uniqueModes()
    }
    
    var body: some View {
        ScrollViewReader { proxy in
        Form {
                // ===== 自动填充 =====
                Section(header: Text("autofill_section".localized)) {
                    Toggle(isOn: $autoFillManager.autoFillFrequencyAndMode) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("autofill_freq_mode".localized)
                            Text("autofill_freq_mode_desc".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Toggle(isOn: $autoFillManager.autoFillOwnQTH) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("autofill_own_qth".localized)
                            Text("autofill_own_qth_desc".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if anyPrefixLookupFieldEnabled {
                        Toggle(isOn: $autoFillManager.autoFillDXCC) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("autofill_dxcc".localized)
                                Text("autofill_dxcc_desc".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if !isDXCCEnabled {
                                    Text("autofill_dxcc_dxcc_disabled".localized)
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                } else if !isZonesEnabled {
                                    Text("autofill_dxcc_zones_disabled".localized)
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                if !dxccManager.isDataAvailable {
                                    Button(action: { navigateToDXCCData = true }) {
                                        Text("autofill_dxcc_no_data".localized)
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .disabled(!dxccManager.isDataAvailable)
                    } else {
                        Button(action: { showingFieldSettings = true }) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text("autofill_dxcc".localized)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text("autofill_dxcc_all_disabled".localized)
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
                
                // ===== ADIF字段设置 =====
                Section(header: Text("adif_field_config".localized)) {
                    Button(action: {
                        showingFieldSettings = true
                    }) {
                        HStack {
                            Image(systemName: "list.bullet.rectangle")
                            Text("adif_field_settings".localized)
                            Spacer()
                            Text(fieldSettingsSummary)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    Text("adif_field_config_desc".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // ===== 列表管理 =====
                Section(header: Text("list_management".localized)) {
                    NavigationLink(destination: ModeSettingsView()) {
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                            Text("mode_settings_title".localized)
                            Spacer()
                            Text("\(modeManager.enabledItemCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    NavigationLink(destination: DXCCDataView(), isActive: $navigateToDXCCData) {
                        HStack {
                            Image(systemName: "globe")
                            Text("dxcc_data_title".localized)
                            Spacer()
                            Text(dxccManager.isDataAvailable ? "\(dxccManager.entities.count)" : "-")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // ===== 导入导出部分 =====
                Section(header: Text(LocalizedStrings.importExport.localized)) {
                    // 导出日志
                    Group {
                        Text(LocalizedStrings.exportLog.localized)
                            .font(.headline)
                            .padding(.top, 8)
                        
                        Picker(LocalizedStrings.exportFormat.localized, selection: $exportFormat) {
                            ForEach(exportFormats, id: \.self) {
                                Text($0)
                            }
                        }
                        
                        // 只有CSV格式才显示时区选择
                        if exportFormat == "CSV" {
                            HStack {
                                Text(LocalizedStrings.exportTimezone.localized)
                                Spacer()
                                Text(exportTimezone.displayName)
                                    .foregroundColor(.secondary)
                            }
                            .onTapGesture {
                                timezoneSettingsInitialTab = 0  // 导出选项卡
                                showingTimezoneSettings = true
                            }
                        }
                        
                        // 对ADIF格式显示UTC说明
                        if exportFormat == "ADIF" {
                            Text(LocalizedStrings.adifUsesUtc.localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // 导出筛选选项
                        Toggle(isOn: $useFilterForExport) {
                            Text(LocalizedStrings.useFilterForExport.localized)
                        }
                        
                        if useFilterForExport {
                            Button(action: {
                                showingExportFilter = true
                            }) {
                                HStack {
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                    Text(LocalizedStrings.configureExportFilter.localized)
                                    Spacer()
                                    if exportFilterCriteria.hasActiveFilters {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            
                            if exportFilterCriteria.hasActiveFilters {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(LocalizedStrings.exportFilterActive.localized)
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    Text(exportFilterCriteria.getDescription())
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            
                            Text(String(format: LocalizedStrings.recordsToExport.localized, filteredExportRecords.count))
                                .font(.caption)
                                .foregroundColor(exportFilterCriteria.hasActiveFilters ? .blue : .secondary)
                        }
                        
                        Button(useFilterForExport && exportFilterCriteria.hasActiveFilters ? 
                               LocalizedStrings.exportFiltered.localized : 
                               LocalizedStrings.exportAll.localized) {
                            exportLogs()
                        }
                        .disabled(qsoRecords.isEmpty || (useFilterForExport && filteredExportRecords.isEmpty))
                    }
                    
                    // 导入日志
                    Group {
                        Text(LocalizedStrings.importLog.localized)
                            .font(.headline)
                            .padding(.top, 16)
                        
                        HStack {
                            Text(LocalizedStrings.importTimezone.localized)
                            Spacer()
                            Text(importTimezone.displayName)
                                .foregroundColor(.secondary)
                        }
                        .onTapGesture {
                            timezoneSettingsInitialTab = 1  // 导入选项卡
                            showingTimezoneSettings = true
                        }
                        
                        Text(LocalizedStrings.csvTimezoneOnly.localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button(LocalizedStrings.importFromADIF.localized) {
                            if #available(iOS 15.0, *) {
                                showingImportPicker = true
                            } else {
                                presentLegacyDocumentPicker(fileType: "adi")
                            }
                        }
                        
                        Button(LocalizedStrings.importFromCSV.localized) {
                            if #available(iOS 15.0, *) {
                                showingImportPicker = true
                            } else {
                                presentLegacyDocumentPicker(fileType: "csv")
                            }
                        }
                    }
                    
                    // 数据管理
                    Group {
                        Text(LocalizedStrings.dataManagement.localized)
                            .font(.headline)
                            .padding(.top, 16)
                        
                        Text(String(format: LocalizedStrings.currentRecordCount.localized, qsoRecords.count))
                            .foregroundColor(.secondary)
                    }
                }
                
                // ===== 关于部分 =====
                Section(header: Text(LocalizedStrings.about.localized)) {
                    // 应用信息
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image("logo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 50, height: 50)
                                .cornerRadius(10)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("EasyQSO")
                                    .font(.headline)
                                Text("\(LocalizedStrings.version.localized) \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if let commitHash = Bundle.main.object(forInfoDictionaryKey: "GitCommitHash") as? String,
                                   !commitHash.isEmpty, commitHash != "unknown" {
                                    let dirty = Bundle.main.object(forInfoDictionaryKey: "GitIsDirty") as? Bool ?? false
                                    let display = dirty ? "\(commitHash)-dirty" : commitHash
                                    if #available(iOS 16.0, *) {
                                        Text("Commit: \(display)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .monospaced()
                                    } else {
                                        Text("Commit: \(display)")
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        
                        Text(LocalizedStrings.softwareDescription.localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 8)
                    
                    // 许可证信息
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(LocalizedStrings.license.localized)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text("GPL v3")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(LocalizedStrings.licenseDescription.localized)
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStrings.licenseFreedomUse.localized)
                            Text(LocalizedStrings.licenseFreedomModify.localized)
                            Text(LocalizedStrings.licenseFreedomDistribute.localized)
                            Text(LocalizedStrings.licenseTermsApply.localized)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    .id("gplLicense")
                    
                    // 版权信息
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStrings.copyright.localized)
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("Copyright © 2025 ShadowMov")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if !"icp_info".localized.isEmpty {
                            Text("icp_info".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    // 操作按钮
                    Button(LocalizedStrings.viewFullLicense.localized) {
                        if let url = URL(string: "https://www.gnu.org/licenses/gpl-3.0.html") {
                            UIApplication.shared.open(url)
                        }
                    }
                    
                    Button(LocalizedStrings.viewSourceCode.localized) {
                        if let url = URL(string: "https://github.com/samhjn/EasyQSO") {
                            UIApplication.shared.open(url)
                        }
                    }
                    
                    Button(LocalizedStrings.reportIssue.localized) {
                        if let url = URL(string: "https://github.com/samhjn/EasyQSO/issues") {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }
            .navigationTitle(LocalizedStrings.settings.localized)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingExportFilter) {
                AdvancedFilterView(
                    filterCriteria: $exportFilterCriteria,
                    availableBands: availableBands,
                    availableModes: availableModes
                )
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [.adifType, .csvType],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    
                    // 获取安全作用域资源的访问权限
                    let accessing = url.startAccessingSecurityScopedResource()
                    defer {
                        if accessing {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    
                    do {
                        let data = try Data(contentsOf: url)
                        importedData = data
                        let ext = url.pathExtension.lowercased()
                        if ext == "csv" {
                            importCSV(data)
                        } else {
                            // adi、adif 以及其他扩展名（含无扩展名）都按 ADIF 尝试解析
                            importADIF(data)
                        }
                    } catch {
                        alertTitle = LocalizedStrings.importFailed.localized
                        alertMessage = error.localizedDescription
                        showingAlert = true
                    }
                case .failure(let error):
                    alertTitle = LocalizedStrings.importFailed.localized
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
            .alert(isPresented: $showingAlert) {
                if importHasDetails {
                    Alert(
                        title: Text(alertTitle),
                        message: Text(alertMessage),
                        primaryButton: .default(Text("查看详情")) {
                            importHasDetails = false
                            showingImportReport = true
                        },
                        secondaryButton: .default(Text(LocalizedStrings.confirm.localized)) {
                            importHasDetails = false
                        }
                    )
                } else {
                    Alert(
                        title: Text(alertTitle),
                        message: Text(alertMessage),
                        dismissButton: .default(Text(LocalizedStrings.confirm.localized))
                    )
                }
            }
            .sheet(isPresented: $showingTimezoneSettings) {
                TimezoneSettingsView(
                    exportTimezone: $exportTimezone,
                    importTimezone: $importTimezone,
                    initialTab: timezoneSettingsInitialTab
                )
            }
            .sheet(isPresented: $showingFieldSettings) {
                FieldSettingsView()
            }
            .sheet(isPresented: $showingImportReport) {
                if let result = importResult {
                    ImportReportView(result: result)
                }
            }
            .onAppear {
                // 设置代理
                documentPickerDelegate.viewContext = viewContext
                documentPickerDelegate.importHandler = { data in
                    if let url = documentPickerDelegate.importedFileURL {
                        let ext = url.pathExtension.lowercased()
                        if ext == "csv" {
                            importCSV(data)
                        } else {
                            importADIF(data)
                        }
                    }
                }
                if scrollToGPL {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation {
                            proxy.scrollTo("gplLicense", anchor: .top)
                        }
                        scrollToGPL = false
                    }
                }
            }
            .onChange(of: scrollToGPL) { newValue in
                if newValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation {
                            proxy.scrollTo("gplLicense", anchor: .top)
                        }
                        scrollToGPL = false
                    }
                }
            }
        }
    }
    
    private func exportLogs() {
        let fileName = "HamLog_\(formattedDate())"
        let fileExtension = exportFormat == "ADIF" ? "adi" : "csv"
        let fileData = exportFormat == "ADIF" ? generateADIF(from: filteredExportRecords) : generateCSV(from: filteredExportRecords)
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("\(fileName).\(fileExtension)")
        
        do {
            try fileData.write(to: fileURL)
            presentShareSheet(for: fileURL)
        } catch {
            alertTitle = LocalizedStrings.exportFailed.localized
            alertMessage = error.localizedDescription
            showingAlert = true
        }
    }
    
    private func presentShareSheet(for url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        activityVC.completionWithItemsHandler = { _, completed, _, error in
            try? FileManager.default.removeItem(at: url)
            if let error = error {
                alertTitle = LocalizedStrings.exportFailed.localized
                alertMessage = error.localizedDescription
                showingAlert = true
            } else if completed {
                alertTitle = LocalizedStrings.exportSuccess.localized
                alertMessage = String(format: LocalizedStrings.exportSuccessMessage.localized, url.lastPathComponent)
                showingAlert = true
            }
        }
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              var topController = windowScene.windows.first?.rootViewController else {
            return
        }
        while let presented = topController.presentedViewController {
            topController = presented
        }
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topController.view
            popover.sourceRect = CGRect(
                x: topController.view.bounds.midX,
                y: topController.view.bounds.midY,
                width: 0, height: 0
            )
            popover.permittedArrowDirections = []
        }
        
        topController.present(activityVC, animated: true)
    }
    
    private func presentLegacyDocumentPicker(fileType: String) {
        DispatchQueue.main.async {
            let contentTypes: [UTType]
            if fileType == "adi" {
                contentTypes = [UTType("com.hamradio.adif") ?? .text, .text]
            } else {
                contentTypes = [.commaSeparatedText, .text]
            }
            
            let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes)
            documentPicker.delegate = documentPickerDelegate
            documentPicker.allowsMultipleSelection = false
            
            // 获取当前的UIViewController
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(documentPicker, animated: true, completion: nil)
            }
        }
    }
    
    private func generateADIF(from records: [QSORecord]) -> Data {
        var adif = "<ADIF_VERS:5>3.1.7"
        adif += "<PROGRAMID:6>EasQSO"
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        adif += "<PROGRAMVERSION:\(appVersion.count)>\(appVersion)"
        adif += "<EOH>\n"
        
        let coreTagsHandledSpecially: Set<String> = [
            "CALL", "QSO_DATE", "TIME_ON", "BAND", "MODE", "SUBMODE",
            "FREQ", "FREQ_RX", "TX_PWR", "RST_SENT", "RST_RCVD",
            "NAME", "QTH", "GRIDSQUARE", "CQZ", "ITUZ",
            "SAT_NAME", "COMMENT", "LAT", "LON"
        ]
        
        for record in records {
            let (dateString, timeString) = TimezoneManager.formatDateForADIF(record.date)
            adif += "<CALL:\(record.callsign.count)>\(record.callsign)"
            adif += "<QSO_DATE:8>\(dateString)"
            adif += "<TIME_ON:\(timeString.count)>\(timeString)"
            adif += "<BAND:\(record.band.count)>\(record.band)"
            adif += "<MODE:\(record.mode.count)>\(record.mode)"
            if let sub = record.adifFields["SUBMODE"], !sub.isEmpty {
                adif += "<SUBMODE:\(sub.utf8.count)>\(sub)"
            }
            
            if record.frequencyMHz > 0 {
                let freqString = formatFreqForADIF(record.frequencyMHz)
                adif += "<FREQ:\(freqString.count)>\(freqString)"
            }
            if record.rxFrequencyMHz > 0 {
                let rxFreqString = formatFreqForADIF(record.rxFrequencyMHz)
                adif += "<FREQ_RX:\(rxFreqString.count)>\(rxFreqString)"
            }
            if let txPower = record.txPower, !txPower.isEmpty {
                adif += "<TX_PWR:\(txPower.count)>\(txPower)"
            }
            adif += "<RST_SENT:\(record.rstSent.count)>\(record.rstSent)"
            adif += "<RST_RCVD:\(record.rstReceived.count)>\(record.rstReceived)"
            if let name = record.name, !name.isEmpty {
                adif += "<NAME:\(name.count)>\(name)"
            }
            if let qth = record.qth, !qth.isEmpty {
                adif += "<QTH:\(qth.count)>\(qth)"
            }
            if let gridSquare = record.gridSquare, !gridSquare.isEmpty {
                adif += "<GRIDSQUARE:\(gridSquare.count)>\(gridSquare)"
            }
            if let cqZone = record.cqZone, !cqZone.isEmpty {
                adif += "<CQZ:\(cqZone.count)>\(cqZone)"
            }
            if let ituZone = record.ituZone, !ituZone.isEmpty {
                adif += "<ITUZ:\(ituZone.count)>\(ituZone)"
            }
            if let satellite = record.satellite, !satellite.isEmpty {
                adif += "<SAT_NAME:\(satellite.count)>\(satellite)"
            }
            if let remarks = record.remarks, !remarks.isEmpty {
                adif += "<COMMENT:\(remarks.count)>\(remarks)"
            }
            
            // Export all extended ADIF fields stored in JSON
            for (tag, value) in record.adifFields where !coreTagsHandledSpecially.contains(tag) {
                if !value.isEmpty {
                    let byteCount = value.utf8.count
                    adif += "<\(tag):\(byteCount)>\(value)"
                }
            }
            
            adif += "<EOR>\n"
        }
        return Data(adif.utf8)
    }
    
    private func formatFreqForADIF(_ mhz: Double) -> String {
        ADIFHelper.formatFreqForADIF(mhz)
    }
    
    private func generateCSV(from records: [QSORecord]) -> Data {
        var csv = "Callsign,Date,Time,Band,Mode,Frequency,RX_Frequency,TX_Power,RST_Sent,RST_Received,Name,QTH,Grid_Square,CQ_Zone,ITU_Zone,Satellite,Remarks\n"
        
        for record in records {
            // 使用选定的导出时区格式化时间
            let (dateString, timeString) = TimezoneManager.formatDateForCSV(record.date, timezone: exportTimezone)
            
            // 使用6位小数保持完整精度（到Hz级别）
            let frequency = record.frequencyMHz > 0 ? String(format: "%.6f", record.frequencyMHz) : ""
            let rxFrequency = record.rxFrequencyMHz > 0 ? String(format: "%.6f", record.rxFrequencyMHz) : ""
            let txPower = record.txPower ?? ""
            let name = record.name ?? ""
            let qth = record.qth ?? ""
            let gridSquare = record.gridSquare ?? ""
            let cqZone = record.cqZone ?? ""
            let ituZone = record.ituZone ?? ""
            let satellite = record.satellite ?? ""
            let remarks = record.remarks ?? ""
            
            // Escape fields that might contain commas
            let escapedTxPower = txPower.contains(",") ? "\"\(txPower)\"" : txPower
            let escapedName = name.contains(",") ? "\"\(name)\"" : name
            let escapedQth = qth.contains(",") ? "\"\(qth)\"" : qth
            let escapedGridSquare = gridSquare.contains(",") ? "\"\(gridSquare)\"" : gridSquare
            let escapedSatellite = satellite.contains(",") ? "\"\(satellite)\"" : satellite
            let escapedRemarks = remarks.contains(",") ? "\"\(remarks)\"" : remarks
            
            csv += "\(record.callsign),\(dateString),\(timeString),\(record.band),\(record.mode),\(frequency),\(rxFrequency),\(escapedTxPower),\(record.rstSent),\(record.rstReceived),\(escapedName),\(escapedQth),\(escapedGridSquare),\(cqZone),\(ituZone),\(escapedSatellite),\(escapedRemarks)\n"
        }
        
        return Data(csv.utf8)
    }
    
    private func importADIF(_ data: Data) {
        guard let adifString = String(data: data, encoding: .utf8) else {
            alertTitle = LocalizedStrings.importFailed.localized
            alertMessage = LocalizedStrings.cannotReadFile.localized
            showingAlert = true
            return
        }
        
        // 创建导入结果记录
        var result = ImportResult()
        
        // 获取所有现有QSO用于去重
        let fetchRequest: NSFetchRequest<QSORecord> = QSORecord.fetchRequest()
        let existingQSOs: [QSORecord]
        do {
            existingQSOs = try viewContext.fetch(fetchRequest)
        } catch {
            alertTitle = LocalizedStrings.importFailed.localized
            alertMessage = LocalizedStrings.cannotGetExistingRecords.localized
            showingAlert = true
            return
        }
        
        // 正确处理ADIF格式：先找到EOH标记，然后分割记录
        var dataString = adifString
        if let eohRange = adifString.range(of: "<EOH>", options: .caseInsensitive) {
            dataString = String(adifString[eohRange.upperBound...])
        }
        
        // 使用多种可能的EOR标记进行分割，并过滤空记录
        let eorPatterns = ["<EOR>", "<eor>"]
        var records: [String] = []
        
        for pattern in eorPatterns {
            if dataString.contains(pattern) {
                records = dataString.components(separatedBy: pattern)
                break
            }
        }
        
        // 如果没有找到EOR标记，尝试按行分割（某些ADIF文件可能每行一个记录）
        if records.isEmpty {
            records = dataString.components(separatedBy: .newlines)
        }
        
        // 处理每条记录
        for record in records {
            let trimmedRecord = record.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 跳过空记录
            if trimmedRecord.isEmpty { continue }
            
            // 检查是否包含呼号字段
            if !trimmedRecord.uppercased().contains("<CALL:") {
                // 非法记录：缺少呼号
                if trimmedRecord.count > 10 { // 只记录有实质内容的
                    result.invalidRecords.append(ImportRecord(
                        callsign: "",
                        dateTime: "",
                        band: "",
                        mode: "",
                        frequency: "",
                        reason: "缺少必填字段：呼号",
                        rawData: String(trimmedRecord.prefix(200))
                    ))
                }
                continue
            }
            
            // 提取呼号
            guard let callsign = extractField(from: trimmedRecord, fieldName: "CALL"), !callsign.isEmpty else {
                result.invalidRecords.append(ImportRecord(
                    callsign: "",
                    dateTime: "",
                    band: "",
                    mode: "",
                    frequency: "",
                    reason: "呼号字段为空",
                    rawData: String(trimmedRecord.prefix(200))
                ))
                continue
            }
            
            // 提取其他字段
            let dateString = extractField(from: trimmedRecord, fieldName: "QSO_DATE") ?? ""
            let timeString = extractField(from: trimmedRecord, fieldName: "TIME_ON") ?? ""
            let band = extractField(from: trimmedRecord, fieldName: "BAND") ?? "20m"
            var mode = extractField(from: trimmedRecord, fieldName: "MODE") ?? "SSB"
            var importedSubmode = extractField(from: trimmedRecord, fieldName: "SUBMODE") ?? ""

            // ADIF fault tolerance: if MODE is actually a known submode and SUBMODE is absent
            if importedSubmode.isEmpty, let parentMode = ModeManager.parentMode(for: mode) {
                importedSubmode = mode
                mode = parentMode
            }

            let freqString = extractField(from: trimmedRecord, fieldName: "FREQ")
            let frequency = freqString != nil ? (Double(freqString!) ?? 0.0) : 0.0
            
            // 解析日期时间
            let qsoDate = TimezoneManager.parseDateFromADIF(dateString: dateString, timeString: timeString)
            
            // 格式化显示用的日期时间
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let displayDateTime = dateFormatter.string(from: qsoDate)
            
            // 检查重复
            let isDuplicate = existingQSOs.contains { exist in
                exist.callsign.uppercased() == callsign.uppercased() &&
                exist.band == band &&
                exist.mode == mode &&
                abs(exist.frequencyMHz - frequency) < 0.001 &&
                Calendar.current.isDate(exist.date, equalTo: qsoDate, toGranularity: .minute)
            }
            
            if isDuplicate {
                // 重复记录
                result.duplicateRecords.append(ImportRecord(
                    callsign: callsign,
                    dateTime: displayDateTime,
                    band: band,
                    mode: mode,
                    frequency: frequency > 0 ? String(format: "%.3f", frequency) : "",
                    reason: "该记录已存在于数据库中"
                ))
                continue
            }
            
            // 创建新记录
            let newQSO = QSORecord(context: viewContext)
            newQSO.callsign = callsign
            newQSO.date = qsoDate
            newQSO.band = band
            newQSO.mode = mode
            newQSO.frequencyMHz = frequency
            newQSO.rxFrequencyMHz = Double(extractField(from: trimmedRecord, fieldName: "FREQ_RX") ?? "") ?? 0.0
            newQSO.txPower = extractField(from: trimmedRecord, fieldName: "TX_PWR")
            newQSO.rstSent = extractField(from: trimmedRecord, fieldName: "RST_SENT") ?? "59"
            newQSO.rstReceived = extractField(from: trimmedRecord, fieldName: "RST_RCVD") ?? "59"
            newQSO.name = extractField(from: trimmedRecord, fieldName: "NAME")
            newQSO.qth = extractField(from: trimmedRecord, fieldName: "QTH")
            newQSO.gridSquare = extractField(from: trimmedRecord, fieldName: "GRIDSQUARE")
            newQSO.cqZone = extractField(from: trimmedRecord, fieldName: "CQZ")
            newQSO.ituZone = extractField(from: trimmedRecord, fieldName: "ITUZ")
            newQSO.satellite = extractField(from: trimmedRecord, fieldName: "SAT_NAME")
            newQSO.remarks = extractField(from: trimmedRecord, fieldName: "COMMENT")
            
            // Import ALL additional ADIF fields losslessly
            let coreImportTags: Set<String> = [
                "CALL", "QSO_DATE", "TIME_ON", "BAND", "MODE", "SUBMODE",
                "FREQ", "FREQ_RX", "TX_PWR", "RST_SENT", "RST_RCVD",
                "NAME", "QTH", "GRIDSQUARE", "CQZ", "ITUZ", "SAT_NAME", "COMMENT"
            ]
            var extFields = [String: String]()
            let allExtracted = extractAllFields(from: trimmedRecord)
            for (tag, value) in allExtracted {
                if !coreImportTags.contains(tag.uppercased()) && !value.isEmpty {
                    extFields[tag.uppercased()] = value
                }
            }
            if !importedSubmode.isEmpty {
                extFields["SUBMODE"] = importedSubmode
            }
            if !extFields.isEmpty {
                newQSO.adifFields = extFields
            }
            
            // 记录成功导入
            result.successRecords.append(ImportRecord(
                callsign: callsign,
                dateTime: displayDateTime,
                band: band,
                mode: mode,
                frequency: frequency > 0 ? String(format: "%.3f", frequency) : ""
            ))
        }
        
        // 保存到数据库
        if !result.successRecords.isEmpty {
            do {
                try viewContext.save()
            } catch {
                alertTitle = LocalizedStrings.importFailed.localized
                alertMessage = String(format: LocalizedStrings.saveFailedMessage.localized, error.localizedDescription)
                showingAlert = true
                return
            }
        }
        
        showImportSummaryAlert(result)
    }
    
    private func importCSV(_ data: Data) {
        guard let csvString = String(data: data, encoding: .utf8) else {
            alertTitle = LocalizedStrings.importFailed.localized
            alertMessage = LocalizedStrings.cannotReadFile.localized
            showingAlert = true
            return
        }
        
        let rows = csvString.components(separatedBy: "\n")
        guard rows.count > 1 else {
            alertTitle = LocalizedStrings.importFailed.localized
            alertMessage = LocalizedStrings.csvFormatIncorrect.localized
            showingAlert = true
            return
        }
        
        // 创建导入结果记录
        var result = ImportResult()
        
        // 获取所有现有QSO用于去重
        let fetchRequest: NSFetchRequest<QSORecord> = QSORecord.fetchRequest()
        let existingQSOs: [QSORecord]
        do {
            existingQSOs = try viewContext.fetch(fetchRequest)
        } catch {
            alertTitle = LocalizedStrings.importFailed.localized
            alertMessage = LocalizedStrings.cannotGetExistingRecords.localized
            showingAlert = true
            return
        }
        
        // 跳过标题行，处理数据行
        for i in 1..<rows.count {
            let row = rows[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if row.isEmpty { continue }
            
            // 简单的CSV解析，不处理引号内的逗号
            let fields = row.components(separatedBy: ",")
            
            // 检查字段数量
            if fields.count < 5 {
                result.invalidRecords.append(ImportRecord(
                    callsign: fields.first ?? "",
                    dateTime: "",
                    band: "",
                    mode: "",
                    frequency: "",
                    reason: "CSV格式错误：字段数量不足（至少需要呼号、日期、时间、波段、模式）",
                    rawData: String(row.prefix(200))
                ))
                continue
            }
            
            let callsign = fields[0].trimmingCharacters(in: .whitespaces)
            if callsign.isEmpty {
                result.invalidRecords.append(ImportRecord(
                    callsign: "",
                    dateTime: fields[1],
                    band: "",
                    mode: "",
                    frequency: "",
                    reason: "呼号为空",
                    rawData: String(row.prefix(200))
                ))
                continue
            }
            
            // 解析日期和时间
            let dateString = fields[1]
            let timeString = fields.count > 2 ? fields[2] : ""
            let qsoDate = TimezoneManager.parseDateFromCSV(
                dateString: dateString,
                timeString: timeString,
                timezone: importTimezone
            )
            
            let band = fields.count > 3 ? fields[3] : "20m"
            let mode = fields.count > 4 ? fields[4] : "SSB"
            let frequency = (fields.count > 5 && !fields[5].isEmpty) ? (Double(fields[5]) ?? 0.0) : 0.0
            
            // 格式化显示用的日期时间
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let displayDateTime = dateFormatter.string(from: qsoDate)
            
            // 检查重复
            let isDuplicate = existingQSOs.contains { exist in
                exist.callsign.uppercased() == callsign.uppercased() &&
                exist.band == band &&
                exist.mode == mode &&
                abs(exist.frequencyMHz - frequency) < 0.001 &&
                Calendar.current.isDate(exist.date, equalTo: qsoDate, toGranularity: .minute)
            }
            
            if isDuplicate {
                result.duplicateRecords.append(ImportRecord(
                    callsign: callsign,
                    dateTime: displayDateTime,
                    band: band,
                    mode: mode,
                    frequency: frequency > 0 ? String(format: "%.3f", frequency) : "",
                    reason: "该记录已存在于数据库中"
                ))
                continue
            }
            
            // 创建新记录
            let newQSO = QSORecord(context: viewContext)
            newQSO.callsign = callsign
            newQSO.date = qsoDate
            newQSO.band = band
            newQSO.mode = mode
            newQSO.frequencyMHz = frequency
            
            if fields.count > 6 && !fields[6].isEmpty {
                newQSO.rxFrequencyMHz = Double(fields[6]) ?? 0.0
            }
            
            if fields.count > 7 { newQSO.txPower = fields[7].isEmpty ? nil : fields[7] }
            if fields.count > 8 { newQSO.rstSent = fields[8] }
            if fields.count > 9 { newQSO.rstReceived = fields[9] }
            if fields.count > 10 { newQSO.name = fields[10].isEmpty ? nil : fields[10] }
            if fields.count > 11 { newQSO.qth = fields[11].isEmpty ? nil : fields[11] }
            if fields.count > 12 { newQSO.gridSquare = fields[12].isEmpty ? nil : fields[12] }
            if fields.count > 13 { newQSO.cqZone = fields[13].isEmpty ? nil : fields[13] }
            if fields.count > 14 { newQSO.ituZone = fields[14].isEmpty ? nil : fields[14] }
            if fields.count > 15 { newQSO.satellite = fields[15].isEmpty ? nil : fields[15] }
            if fields.count > 16 { newQSO.remarks = fields[16].isEmpty ? nil : fields[16] }
            
            // 记录成功导入
            result.successRecords.append(ImportRecord(
                callsign: callsign,
                dateTime: displayDateTime,
                band: band,
                mode: mode,
                frequency: frequency > 0 ? String(format: "%.3f", frequency) : ""
            ))
        }
        
        // 保存到数据库
        if !result.successRecords.isEmpty {
            do {
                try viewContext.save()
            } catch {
                alertTitle = LocalizedStrings.importFailed.localized
                alertMessage = String(format: LocalizedStrings.saveFailedMessage.localized, error.localizedDescription)
                showingAlert = true
                return
            }
        }
        
        showImportSummaryAlert(result)
    }
    
    /// 显示导入摘要 alert，有问题时可点击查看详情
    private func showImportSummaryAlert(_ result: ImportResult) {
        importResult = result
        
        var summary = "成功导入: \(result.successRecords.count)"
        if !result.duplicateRecords.isEmpty {
            summary += "\n重复跳过: \(result.duplicateRecords.count)"
        }
        if !result.invalidRecords.isEmpty {
            summary += "\n非法记录: \(result.invalidRecords.count)"
        }
        
        alertTitle = result.successRecords.isEmpty && result.duplicateRecords.isEmpty && result.invalidRecords.isEmpty
            ? LocalizedStrings.importFailed.localized
            : LocalizedStrings.importSuccess.localized
        alertMessage = summary
        importHasDetails = result.hasIssues
        showingAlert = true
    }
    
    private func extractAllFields(from record: String) -> [String: String] {
        ADIFHelper.extractAllFields(from: record)
    }
    
    private func extractField(from record: String, fieldName: String) -> String? {
        ADIFHelper.extractField(from: record, fieldName: fieldName)
    }
    
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
