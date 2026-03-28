/*
 * EasyQSO - 业余无线电通联日志
 * Copyright (C) 2025 ShadowMov
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import SwiftUI
import CoreLocation

struct EditQSOView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var qthManager = QTHManager()
    @ObservedObject private var fieldVisibility = FieldVisibilityManager.shared
    @ObservedObject private var modeManager = ModeManager.shared
    @FocusState private var focusedField: String?
    
    let record: QSORecord
    
    // Core fields
    @State private var callsign: String
    @State private var date: Date
    @State private var endDate: Date
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
    
    // ADIF extended fields
    @State private var extendedFields: [String: String]
    
    @State private var isBandChangedByFrequency = false
    
    // 己方QTH
    @State private var ownQTH = ""
    @State private var ownGridSquare = ""
    @State private var ownCQZone = ""
    @State private var ownITUZone = ""
    
    // 地图
    @State private var showingMapPicker = false
    @State private var showingOwnMapPicker = false
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var selectedOwnLocation: CLLocationCoordinate2D?
    @State private var mapPickerID = UUID()
    @State private var ownMapPickerID = UUID()
    @State private var isMapPickerActive = false
    
    @State private var rxBand: String
    @State private var isRxBandChangedByFrequency = false
    
    // Unsaved changes detection
    @State private var savedSnapshot: FormSnapshot
    @State private var showingUnsavedAlert = false
    
    private struct FormSnapshot: Equatable {
        var callsign: String
        var date: Date
        var endDate: Date
        var band: String
        var mode: String
        var frequency: String
        var rxFrequency: String
        var txPower: String
        var rstSent: String
        var rstReceived: String
        var name: String
        var qth: String
        var gridSquare: String
        var cqZone: String
        var ituZone: String
        var satellite: String
        var remarks: String
        var extendedFields: [String: String]
        var rxBand: String
        var ownQTH: String
        var ownGridSquare: String
        var ownCQZone: String
        var ownITUZone: String
    }
    
    private var currentSnapshot: FormSnapshot {
        FormSnapshot(
            callsign: callsign, date: date, endDate: endDate,
            band: band, mode: mode, frequency: frequency,
            rxFrequency: rxFrequency, txPower: txPower,
            rstSent: rstSent, rstReceived: rstReceived,
            name: name, qth: qth, gridSquare: gridSquare,
            cqZone: cqZone, ituZone: ituZone,
            satellite: satellite, remarks: remarks,
            extendedFields: extendedFields, rxBand: rxBand,
            ownQTH: ownQTH, ownGridSquare: ownGridSquare,
            ownCQZone: ownCQZone, ownITUZone: ownITUZone
        )
    }
    
    private var hasUnsavedChanges: Bool {
        currentSnapshot != savedSnapshot
    }
    
    let bands = ["160m", "80m", "40m", "30m", "20m", "17m", "15m", "12m", "10m", "6m", "2m", "70cm"]
    
    private var modes: [String] { modeManager.pickerModes(current: mode) }
    
    private var isVoiceMode: Bool { ["SSB", "FM", "AM"].contains(mode) }
    private var isCWMode: Bool { mode == "CW" }
    
    private var showRxBandPicker: Bool {
        fieldVisibility.isCoreFieldVisible(for: "FREQ_RX") &&
        fieldVisibility.visibility(for: "BAND_RX") == .visible
    }
    
    private var techExcludeIds: Set<String> {
        showRxBandPicker ? ["BAND_RX"] : []
    }
    
    // MARK: - Group visibility
    
    private var dateTimeVis: ADIFFieldVisibility {
        fieldVisibility.groupVisibility(for: "group_datetime")
    }
    
    private var endDateTimeVis: ADIFFieldVisibility {
        fieldVisibility.groupVisibility(for: "group_end_datetime")
    }
    
    private var contactedQTHVis: ADIFFieldVisibility {
        fieldVisibility.groupVisibility(for: "group_contacted_qth")
    }
    
    private var ownQTHVis: ADIFFieldVisibility {
        fieldVisibility.groupVisibility(for: "group_own_qth")
    }
    
    private var showContactedStationSection: Bool {
        contactedQTHVis == .visible || fieldVisibility.hasVisibleFields(for: .contactedStation)
    }
    
    private var showOwnStationSection: Bool {
        ownQTHVis == .visible || fieldVisibility.hasVisibleFields(for: .ownStation)
    }
    
    private var hasCollapsedGroupContent: Bool {
        dateTimeVis == .collapsed || endDateTimeVis == .collapsed ||
        contactedQTHVis == .collapsed || ownQTHVis == .collapsed
    }
    
    // MARK: - Hidden fields with existing data (for edit mode)
    
    private var hiddenExtendedFieldsWithValues: [ADIFFieldDef] {
        ADIFFields.all.filter { field in
            !ADIFFields.groupedFieldIds.contains(field.id) &&
            field.coreProperty == nil &&
            fieldVisibility.visibility(for: field.id) == .hidden &&
            !(extendedFields[field.id] ?? "").isEmpty
        }
    }
    
    private var hasAnyHiddenFieldWithValue: Bool {
        if fieldVisibility.visibility(for: "FREQ") == .hidden && !frequency.isEmpty { return true }
        if fieldVisibility.visibility(for: "FREQ_RX") == .hidden && !rxFrequency.isEmpty { return true }
        if fieldVisibility.visibility(for: "TX_PWR") == .hidden && !txPower.isEmpty { return true }
        if fieldVisibility.visibility(for: "SAT_NAME") == .hidden && !satellite.isEmpty { return true }
        if fieldVisibility.visibility(for: "NAME") == .hidden && !name.isEmpty { return true }
        if fieldVisibility.visibility(for: "COMMENT") == .hidden && !remarks.isEmpty { return true }
        if contactedQTHVis == .hidden &&
           (!qth.isEmpty || !gridSquare.isEmpty || !cqZone.isEmpty || !ituZone.isEmpty) { return true }
        if ownQTHVis == .hidden &&
           (!ownQTH.isEmpty || !ownGridSquare.isEmpty || !ownCQZone.isEmpty || !ownITUZone.isEmpty) { return true }
        if endDateTimeVis == .hidden &&
           (!(extendedFields["TIME_OFF"] ?? "").isEmpty || !(extendedFields["QSO_DATE_OFF"] ?? "").isEmpty) { return true }
        if !hiddenExtendedFieldsWithValues.isEmpty { return true }
        return false
    }
    
    // MARK: - Keyboard ordered fields
    
    private var keyboardOrderedFieldIDs: [String] {
        var ids: [String] = []
        ids.append("CALL")
        if fieldVisibility.isCoreFieldVisible(for: "FREQ") {
            ids.append("FREQ")
        }
        ids.append(contentsOf: fieldVisibility.visibleFields(for: .basic).map(\.id))
        
        ids.append("RST_SENT")
        ids.append("RST_RCVD")
        
        let hasRxFreq = fieldVisibility.isCoreFieldVisible(for: "FREQ_RX")
        let hasTxPwr = fieldVisibility.isCoreFieldVisible(for: "TX_PWR")
        let hasSatName = fieldVisibility.isCoreFieldVisible(for: "SAT_NAME")
        let hasDynTech = fieldVisibility.hasVisibleFields(for: .technical)
        let hasDynSat = fieldVisibility.hasVisibleFields(for: .satellite)
        if hasRxFreq || hasTxPwr || hasSatName || hasDynTech || hasDynSat {
            if hasRxFreq { ids.append("FREQ_RX") }
            if hasTxPwr { ids.append("TX_PWR") }
            if hasSatName { ids.append("SAT_NAME") }
            let excludeSet = techExcludeIds
            ids.append(contentsOf: fieldVisibility.visibleFields(for: .technical)
                .filter { !excludeSet.contains($0.id) }.map(\.id))
            ids.append(contentsOf: fieldVisibility.visibleFields(for: .satellite).map(\.id))
        }
        
        if contactedQTHVis == .visible {
            ids.append(contentsOf: ["QTH", "GRIDSQUARE", "CQZ", "ITUZ"])
        }
        ids.append(contentsOf: fieldVisibility.visibleFields(for: .contactedStation).map(\.id))
        
        if ownQTHVis == .visible {
            ids.append(contentsOf: ["MY_CITY", "MY_GRIDSQUARE", "MY_CQ_ZONE", "MY_ITU_ZONE"])
        }
        ids.append(contentsOf: fieldVisibility.visibleFields(for: .ownStation).map(\.id))
        
        let hasName = fieldVisibility.isCoreFieldVisible(for: "NAME")
        let hasComment = fieldVisibility.isCoreFieldVisible(for: "COMMENT")
        let hasDynOp = fieldVisibility.hasVisibleFields(for: .contactedOp)
        let hasDynNotes = fieldVisibility.hasVisibleFields(for: .notes)
        if hasName || hasComment || hasDynOp || hasDynNotes {
            if hasName { ids.append("NAME") }
            if hasComment { ids.append("COMMENT") }
            ids.append(contentsOf: fieldVisibility.visibleFields(for: .contactedOp).map(\.id))
            ids.append(contentsOf: fieldVisibility.visibleFields(for: .notes).map(\.id))
        }
        
        for cat in dynamicOnlyCategories {
            ids.append(contentsOf: fieldVisibility.visibleFields(for: cat).map(\.id))
        }
        
        if contactedQTHVis == .collapsed {
            ids.append(contentsOf: ["QTH", "GRIDSQUARE", "CQZ", "ITUZ"])
        }
        if ownQTHVis == .collapsed {
            ids.append(contentsOf: ["MY_CITY", "MY_GRIDSQUARE", "MY_CQ_ZONE", "MY_ITU_ZONE"])
        }
        ids.append(contentsOf: fieldVisibility.allCollapsedFields().map(\.id))
        
        return ids
    }
    
    // MARK: - Init
    
    init(record: QSORecord) {
        self.record = record
        
        _callsign = State(initialValue: record.callsign)
        _date = State(initialValue: record.date)
        _band = State(initialValue: record.band)
        _mode = State(initialValue: record.mode)
        _frequency = State(initialValue: record.frequencyMHz > 0 ? String(record.frequencyMHz) : "")
        _rxFrequency = State(initialValue: record.rxFrequencyMHz > 0 ? String(record.rxFrequencyMHz) : "")
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
        _extendedFields = State(initialValue: record.adifFields)
        _rxBand = State(initialValue: record.adifFields["BAND_RX"] ?? "")
        
        let adif = record.adifFields
        let endDateVal: Date
        if let parsed = ADIFDateTimeHelper.adifToDate(dateStr: adif["QSO_DATE_OFF"], timeStr: adif["TIME_OFF"]) {
            endDateVal = parsed
        } else {
            endDateVal = record.date
        }
        _endDate = State(initialValue: endDateVal)
        
        _savedSnapshot = State(initialValue: FormSnapshot(
            callsign: record.callsign, date: record.date, endDate: endDateVal,
            band: record.band, mode: record.mode,
            frequency: record.frequencyMHz > 0 ? String(record.frequencyMHz) : "",
            rxFrequency: record.rxFrequencyMHz > 0 ? String(record.rxFrequencyMHz) : "",
            txPower: record.txPower ?? "",
            rstSent: record.rstSent, rstReceived: record.rstReceived,
            name: record.name ?? "", qth: record.qth ?? "",
            gridSquare: record.gridSquare ?? "",
            cqZone: record.cqZone ?? "", ituZone: record.ituZone ?? "",
            satellite: record.satellite ?? "", remarks: record.remarks ?? "",
            extendedFields: adif, rxBand: adif["BAND_RX"] ?? "",
            ownQTH: "", ownGridSquare: "", ownCQZone: "", ownITUZone: ""
        ))
        
        if let existingCoordinate = record.coordinate {
            _selectedLocation = State(initialValue: existingCoordinate)
        } else if let gridSquare = record.gridSquare, !gridSquare.isEmpty {
            _selectedLocation = State(initialValue: QTHManager.coordinateFromGridSquare(gridSquare))
        } else {
            _selectedLocation = State(initialValue: nil)
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        Form {
            // ═══════════ Basic Info ═══════════
            Section(header: Text(LocalizedStrings.basicInfo.localized)) {
                TextField(LocalizedStrings.callsign.localized, text: $callsign)
                    .autocapitalization(.allCharacters)
                    .focused($focusedField, equals: "CALL")
                    .onChange(of: callsign) { newValue in
                        callsign = newValue.uppercased()
                    }
                    .floatingLabel(LocalizedStrings.callsign.localized, text: callsign)
                
                if dateTimeVis == .visible {
                    DatePicker(LocalizedStrings.dateTime.localized, selection: $date)
                }
                
                if endDateTimeVis == .visible {
                    DatePicker(
                        ADIFFields.fieldGroups.first { $0.id == "group_end_datetime" }?.displayName ?? "end_date".localized,
                        selection: $endDate
                    )
                }
                
                if fieldVisibility.isCoreFieldVisible(for: "FREQ") {
                    TextField(LocalizedStrings.frequency.localized, text: $frequency)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: "FREQ")
                        .onChange(of: frequency) { newValue in
                            if let freq = Double(newValue), let autoBand = QSORecord.bandForFrequency(freq) {
                                if band != autoBand {
                                    isBandChangedByFrequency = true
                                    band = autoBand
                                }
                            }
                        }
                        .floatingLabel(LocalizedStrings.frequency.localized, text: frequency)
                }
                
                Picker(LocalizedStrings.band.localized, selection: $band) {
                    ForEach(bands, id: \.self) { Text($0) }
                }
                .onChange(of: band) { newBand in
                    if isBandChangedByFrequency {
                        isBandChangedByFrequency = false
                    } else {
                        if let lastFreq = QSORecord.lastFrequencyForBand(newBand, context: viewContext) {
                            frequency = String(lastFreq)
                        }
                    }
                }
                
                Picker(LocalizedStrings.mode.localized, selection: $mode) {
                    ForEach(modes, id: \.self) { Text($0) }
                }
                
                ADIFDynamicFieldRows(extendedFields: $extendedFields, category: .basic, visibilityManager: fieldVisibility, focusedField: $focusedField)
            }
            
            // ═══════════ Signal Report ═══════════
            Section(header: Text(LocalizedStrings.signalReport.localized)) {
                HStack {
                    TextField(LocalizedStrings.rstSent.localized, text: $rstSent)
                        .focused($focusedField, equals: "RST_SENT")
                        .onChange(of: rstSent) { newValue in
                            rstSent = newValue.uppercased()
                        }
                        .floatingLabel(LocalizedStrings.rstSent.localized, text: rstSent)
                    rstQuickButtons(for: $rstSent)
                }
                HStack {
                    TextField(LocalizedStrings.rstReceived.localized, text: $rstReceived)
                        .focused($focusedField, equals: "RST_RCVD")
                        .onChange(of: rstReceived) { newValue in
                            rstReceived = newValue.uppercased()
                        }
                        .floatingLabel(LocalizedStrings.rstReceived.localized, text: rstReceived)
                    rstQuickButtons(for: $rstReceived)
                }
            }
            
            // ═══════════ Technical ═══════════
            technicalSection
            
            // ═══════════ Contacted Station ═══════════
            contactedStationSection
            
            // ═══════════ Own Station ═══════════
            ownStationSection
            
            // ═══════════ Additional Info ═══════════
            additionalInfoSection
            
            // ═══════════ Dynamic-only sections ═══════════
            ForEach(dynamicOnlyCategories, id: \.self) { category in
                ADIFDynamicSection(extendedFields: $extendedFields, category: category, visibilityManager: fieldVisibility, focusedField: $focusedField)
            }
            
            // ═══════════ Collapsed (unified at bottom) ═══════════
            collapsedSection
            
            // ═══════════ Hidden fields with existing data ═══════════
            hiddenFieldsWithValuesSection
            
            // ═══════════ Save Button ═══════════
            Section {
                Button(action: {
                    focusedField = nil
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
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    if hasUnsavedChanges {
                        showingUnsavedAlert = true
                    } else {
                        presentationMode.wrappedValue.dismiss()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.backward")
                        Text(LocalizedStrings.queryLog.localized)
                    }
                }
            }
            KeyboardToolbar(focusedField: $focusedField, orderedFields: keyboardOrderedFieldIDs)
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage)
            )
        }
        .alert("edit_unsaved_title".localized, isPresented: $showingUnsavedAlert) {
            Button("edit_unsaved_save".localized) {
                saveAndDismiss()
            }
            Button("edit_unsaved_discard".localized, role: .destructive) {
                presentationMode.wrappedValue.dismiss()
            }
            Button(LocalizedStrings.cancel.localized, role: .cancel) {}
        } message: {
            Text("edit_unsaved_message".localized)
        }
        .fullScreenCover(isPresented: $showingMapPicker) {
            EnhancedMapLocationPicker(
                selectedLocation: $selectedLocation,
                locationName: $qth,
                gridSquare: $gridSquare,
                editMode: .otherQTH
            )
            .id(mapPickerID)
            .onDisappear { isMapPickerActive = false }
        }
        .fullScreenCover(isPresented: $showingOwnMapPicker) {
            EnhancedMapLocationPicker(
                selectedLocation: $selectedOwnLocation,
                locationName: $ownQTH,
                gridSquare: $ownGridSquare,
                editMode: .ownQTH
            )
            .id(ownMapPickerID)
            .onDisappear { isMapPickerActive = false }
        }
        .onAppear {
            DispatchQueue.main.async {
                loadOwnQTHInfo()
                savedSnapshot = currentSnapshot
            }
        }
    }
    
    // MARK: - Contacted Station Section
    
    @ViewBuilder
    private var contactedStationSection: some View {
        if showContactedStationSection {
            Section(header: Text(LocalizedStrings.qthInfo.localized)) {
                if contactedQTHVis == .visible {
                    contactedQTHFields
                }
                ADIFDynamicFieldRows(extendedFields: $extendedFields, category: .contactedStation, visibilityManager: fieldVisibility, focusedField: $focusedField)
            }
        }
    }
    
    @ViewBuilder
    private var contactedQTHFields: some View {
        HStack {
            TextField(LocalizedStrings.qth.localized, text: $qth)
                .focused($focusedField, equals: "QTH")
                .floatingLabel(LocalizedStrings.qth.localized, text: qth)
            
            Button(LocalizedStrings.selectOnMap.localized) {
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
            .focused($focusedField, equals: "GRIDSQUARE")
            .onChange(of: gridSquare) { newValue in
                gridSquare = formatGridSquare(newValue)
            }
            .floatingLabel(LocalizedStrings.gridSquare.localized, text: gridSquare)
        
        TextField(LocalizedStrings.cqZone.localized, text: $cqZone)
            .keyboardType(.numberPad)
            .focused($focusedField, equals: "CQZ")
            .floatingLabel(LocalizedStrings.cqZone.localized, text: cqZone)
        
        TextField(LocalizedStrings.ituZone.localized, text: $ituZone)
            .keyboardType(.numberPad)
            .focused($focusedField, equals: "ITUZ")
            .floatingLabel(LocalizedStrings.ituZone.localized, text: ituZone)
    }
    
    // MARK: - Own Station Section
    
    @ViewBuilder
    private var ownStationSection: some View {
        if showOwnStationSection {
            Section(header: Text(LocalizedStrings.ownQthInfo.localized)) {
                if ownQTHVis == .visible {
                    ownQTHFields
                }
                ADIFDynamicFieldRows(extendedFields: $extendedFields, category: .ownStation, visibilityManager: fieldVisibility, focusedField: $focusedField)
            }
        }
    }
    
    @ViewBuilder
    private var ownQTHFields: some View {
        HStack {
            TextField(LocalizedStrings.ownQth.localized, text: $ownQTH)
                .focused($focusedField, equals: "MY_CITY")
                .floatingLabel(LocalizedStrings.ownQth.localized, text: ownQTH)
            
            Button(LocalizedStrings.selectOnMap.localized) {
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
            .focused($focusedField, equals: "MY_GRIDSQUARE")
            .onChange(of: ownGridSquare) { newValue in
                ownGridSquare = formatGridSquare(newValue)
            }
            .floatingLabel(LocalizedStrings.gridSquare.localized, text: ownGridSquare)
        
        TextField(LocalizedStrings.cqZone.localized, text: $ownCQZone)
            .keyboardType(.numberPad)
            .focused($focusedField, equals: "MY_CQ_ZONE")
            .floatingLabel(LocalizedStrings.cqZone.localized, text: ownCQZone)
        
        TextField(LocalizedStrings.ituZone.localized, text: $ownITUZone)
            .keyboardType(.numberPad)
            .focused($focusedField, equals: "MY_ITU_ZONE")
            .floatingLabel(LocalizedStrings.ituZone.localized, text: ownITUZone)
    }
    
    // MARK: - Technical & Additional Sections
    
    @ViewBuilder
    private var technicalSection: some View {
        let hasRxFreq = fieldVisibility.isCoreFieldVisible(for: "FREQ_RX")
        let hasTxPwr = fieldVisibility.isCoreFieldVisible(for: "TX_PWR")
        let hasSatName = fieldVisibility.isCoreFieldVisible(for: "SAT_NAME")
        let hasDynTech = fieldVisibility.hasVisibleFields(for: .technical)
        let hasDynSat = fieldVisibility.hasVisibleFields(for: .satellite)
        
        if hasRxFreq || hasTxPwr || hasSatName || hasDynTech || hasDynSat {
            Section(header: Text(LocalizedStrings.technicalInfo.localized)) {
                if hasRxFreq {
                    TextField(LocalizedStrings.rxFrequency.localized, text: $rxFrequency)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: "FREQ_RX")
                        .onChange(of: rxFrequency) { newValue in
                            if let freq = Double(newValue), let autoBand = QSORecord.bandForFrequency(freq) {
                                if rxBand != autoBand {
                                    isRxBandChangedByFrequency = true
                                    rxBand = autoBand
                                }
                            }
                        }
                        .floatingLabel(LocalizedStrings.rxFrequency.localized, text: rxFrequency)
                }
                if showRxBandPicker {
                    Picker("rx_band".localized, selection: $rxBand) {
                        Text("").tag("")
                        ForEach(bands, id: \.self) { Text($0) }
                    }
                    .onChange(of: rxBand) { newBand in
                        if isRxBandChangedByFrequency {
                            isRxBandChangedByFrequency = false
                        } else if !newBand.isEmpty {
                            if let lastFreq = QSORecord.lastRxFrequencyForRxBand(newBand, context: viewContext) {
                                rxFrequency = String(lastFreq)
                            }
                        }
                    }
                }
                if hasTxPwr {
                    TextField(LocalizedStrings.txPower.localized, text: $txPower)
                        .focused($focusedField, equals: "TX_PWR")
                        .floatingLabel(LocalizedStrings.txPower.localized, text: txPower)
                }
                if hasSatName {
                    TextField(LocalizedStrings.satellite.localized, text: $satellite)
                        .focused($focusedField, equals: "SAT_NAME")
                        .floatingLabel(LocalizedStrings.satellite.localized, text: satellite)
                }
                ADIFDynamicFieldRows(extendedFields: $extendedFields, category: .technical, visibilityManager: fieldVisibility, focusedField: $focusedField, excludeFieldIds: techExcludeIds)
                ADIFDynamicFieldRows(extendedFields: $extendedFields, category: .satellite, visibilityManager: fieldVisibility, focusedField: $focusedField)
            }
        }
    }
    
    @ViewBuilder
    private var additionalInfoSection: some View {
        let hasName = fieldVisibility.isCoreFieldVisible(for: "NAME")
        let hasComment = fieldVisibility.isCoreFieldVisible(for: "COMMENT")
        let hasDynOp = fieldVisibility.hasVisibleFields(for: .contactedOp)
        let hasDynNotes = fieldVisibility.hasVisibleFields(for: .notes)
        
        if hasName || hasComment || hasDynOp || hasDynNotes {
            Section(header: Text(LocalizedStrings.additionalInfo.localized)) {
                if hasName {
                    TextField(LocalizedStrings.name.localized, text: $name)
                        .focused($focusedField, equals: "NAME")
                        .floatingLabel(LocalizedStrings.name.localized, text: name)
                }
                if hasComment {
                    TextField(LocalizedStrings.remarks.localized, text: $remarks)
                        .focused($focusedField, equals: "COMMENT")
                        .floatingLabel(LocalizedStrings.remarks.localized, text: remarks)
                }
                ADIFDynamicFieldRows(extendedFields: $extendedFields, category: .contactedOp, visibilityManager: fieldVisibility, focusedField: $focusedField)
                ADIFDynamicFieldRows(extendedFields: $extendedFields, category: .notes, visibilityManager: fieldVisibility, focusedField: $focusedField)
            }
        }
    }
    
    // MARK: - Collapsed Section (unified at bottom)
    
    @ViewBuilder
    private var collapsedSection: some View {
        let collapsedFields = fieldVisibility.allCollapsedFields()
        
        if hasCollapsedGroupContent || !collapsedFields.isEmpty {
            Section {
                DisclosureGroup("adif_more_fields".localized) {
                    if dateTimeVis == .collapsed {
                        DatePicker(LocalizedStrings.dateTime.localized, selection: $date)
                    }
                    if endDateTimeVis == .collapsed {
                        DatePicker(
                            ADIFFields.fieldGroups.first { $0.id == "group_end_datetime" }?.displayName ?? "end_date".localized,
                            selection: $endDate
                        )
                    }
                    
                    if contactedQTHVis == .collapsed {
                        Text(ADIFFields.fieldGroups.first { $0.id == "group_contacted_qth" }?.displayName ?? "QTH")
                            .font(.caption).foregroundColor(.secondary)
                        contactedQTHFields
                    }
                    
                    if ownQTHVis == .collapsed {
                        Text(ADIFFields.fieldGroups.first { $0.id == "group_own_qth" }?.displayName ?? "QTH")
                            .font(.caption).foregroundColor(.secondary)
                        ownQTHFields
                    }
                    
                    let grouped = Dictionary(grouping: collapsedFields) { $0.category }
                    let sortedCats = grouped.keys.sorted { $0.sortOrder < $1.sortOrder }
                    
                    ForEach(sortedCats, id: \.self) { category in
                        if let fields = grouped[category] {
                            Text(category.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .listRowSeparator(.hidden)
                            
                            ForEach(fields) { field in
                                TextField(field.displayName, text: bindingForExtended(field.id))
                                    .focused($focusedField, equals: field.id)
                                    .floatingLabel(field.displayName, text: extendedFields[field.id] ?? "")
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Hidden Fields With Values Section
    
    @ViewBuilder
    private var hiddenFieldsWithValuesSection: some View {
        if hasAnyHiddenFieldWithValue {
            Section(header: Text("adif_hidden_with_data".localized)) {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.orange)
                    Text("adif_hidden_field_hint".localized)
                }
                .font(.caption2)
                .foregroundColor(.orange)
                .listRowBackground(Color.orange.opacity(0.06))
                
                if fieldVisibility.visibility(for: "FREQ") == .hidden && !frequency.isEmpty {
                    hiddenFieldRow(LocalizedStrings.frequency.localized, text: $frequency)
                }
                if fieldVisibility.visibility(for: "FREQ_RX") == .hidden && !rxFrequency.isEmpty {
                    hiddenFieldRow(LocalizedStrings.rxFrequency.localized, text: $rxFrequency)
                }
                if fieldVisibility.visibility(for: "TX_PWR") == .hidden && !txPower.isEmpty {
                    hiddenFieldRow(LocalizedStrings.txPower.localized, text: $txPower)
                }
                if fieldVisibility.visibility(for: "SAT_NAME") == .hidden && !satellite.isEmpty {
                    hiddenFieldRow(LocalizedStrings.satellite.localized, text: $satellite)
                }
                if fieldVisibility.visibility(for: "NAME") == .hidden && !name.isEmpty {
                    hiddenFieldRow(LocalizedStrings.name.localized, text: $name)
                }
                if fieldVisibility.visibility(for: "COMMENT") == .hidden && !remarks.isEmpty {
                    hiddenFieldRow(LocalizedStrings.remarks.localized, text: $remarks)
                }
                
                if contactedQTHVis == .hidden &&
                   (!qth.isEmpty || !gridSquare.isEmpty || !cqZone.isEmpty || !ituZone.isEmpty) {
                    hiddenGroupHeader(ADIFFields.fieldGroups.first { $0.id == "group_contacted_qth" }?.displayName ?? "QTH")
                    contactedQTHFields
                }
                
                if ownQTHVis == .hidden &&
                   (!ownQTH.isEmpty || !ownGridSquare.isEmpty || !ownCQZone.isEmpty || !ownITUZone.isEmpty) {
                    hiddenGroupHeader(ADIFFields.fieldGroups.first { $0.id == "group_own_qth" }?.displayName ?? "QTH")
                    ownQTHFields
                }
                
                if endDateTimeVis == .hidden &&
                   (!(extendedFields["TIME_OFF"] ?? "").isEmpty || !(extendedFields["QSO_DATE_OFF"] ?? "").isEmpty) {
                    HStack {
                        Image(systemName: "eye.slash")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        DatePicker(
                            ADIFFields.fieldGroups.first { $0.id == "group_end_datetime" }?.displayName ?? "end_date".localized,
                            selection: $endDate
                        )
                        Button {
                            extendedFields.removeValue(forKey: "TIME_OFF")
                            extendedFields.removeValue(forKey: "QSO_DATE_OFF")
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                ForEach(hiddenExtendedFieldsWithValues) { field in
                    hiddenFieldRow(field.displayName, extended: field.id)
                }
            }
        }
    }
    
    private func hiddenGroupHeader(_ name: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "eye.slash")
                .font(.caption)
                .foregroundColor(.orange)
            Text(name)
                .font(.caption)
                .foregroundColor(.orange)
        }
    }
    
    private func hiddenFieldRow(_ label: String, text: Binding<String>) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "eye.slash")
                .font(.caption2)
                .foregroundColor(.orange)
            TextField(label, text: text)
                .floatingLabel(label, text: text.wrappedValue)
        }
    }
    
    private func hiddenFieldRow(_ label: String, extended fieldId: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "eye.slash")
                .font(.caption2)
                .foregroundColor(.orange)
            TextField(label, text: bindingForExtended(fieldId))
                .focused($focusedField, equals: fieldId)
                .floatingLabel(label, text: extendedFields[fieldId] ?? "")
        }
    }
    
    private func bindingForExtended(_ fieldId: String) -> Binding<String> {
        Binding(
            get: { extendedFields[fieldId] ?? "" },
            set: { newVal in
                if newVal.isEmpty {
                    extendedFields.removeValue(forKey: fieldId)
                } else {
                    extendedFields[fieldId] = newVal
                }
            }
        )
    }
    
    // MARK: - RST Quick Input
    
    @ViewBuilder
    private func rstQuickButtons(for binding: Binding<String>) -> some View {
        if isVoiceMode {
            Button("59") { binding.wrappedValue = "59" }
                .buttonStyle(.borderless)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
        } else if isCWMode {
            HStack(spacing: 4) {
                Button("599") { binding.wrappedValue = "599" }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                Button("5NN") { binding.wrappedValue = "5NN" }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
            }
        } else {
            Button("-10") { binding.wrappedValue = "-10" }
                .buttonStyle(.borderless)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
        }
    }
    
    // MARK: - Data Loading
    
    private func loadOwnQTHInfo() {
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
        let currentCoordinate = selectedOwnLocation
        let savedCoordinate = qthManager.ownQTH.coordinate
        if currentCoordinate?.latitude != savedCoordinate?.latitude ||
           currentCoordinate?.longitude != savedCoordinate?.longitude {
            selectedOwnLocation = qthManager.ownQTH.coordinate
        }
    }
    
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
    
    // MARK: - Validation
    
    private func validateInputs() -> Bool {
        isValidationError = false
        
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
        
        if !frequency.isEmpty && !isValidFrequency(frequency) {
            showValidationError(LocalizedStrings.frequencyInvalid.localized)
            return false
        }
        
        if !gridSquare.isEmpty && !QTHManager.isValidGridSquare(gridSquare) {
            showValidationError(LocalizedStrings.gridSquareInvalid.localized)
            return false
        }
        
        if !ownGridSquare.isEmpty && !QTHManager.isValidGridSquare(ownGridSquare) {
            showValidationError(LocalizedStrings.gridSquareInvalid.localized)
            return false
        }
        
        if !cqZone.isEmpty && !QTHManager.isValidCQZone(cqZone) {
            showValidationError(LocalizedStrings.cqZoneInvalid.localized)
            return false
        }
        
        if !ownCQZone.isEmpty && !QTHManager.isValidCQZone(ownCQZone) {
            showValidationError(LocalizedStrings.cqZoneInvalid.localized)
            return false
        }
        
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
        return freq > 0.1 && freq < 6000
    }
    
    // MARK: - Save
    
    @discardableResult
    private func performSave() -> Bool {
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
        record.frequencyMHz = Double(frequency) ?? 0.0
        record.rxFrequencyMHz = Double(rxFrequency) ?? 0.0
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
        record.setCoordinate(selectedLocation)
        
        var fields = extendedFields
        
        if !rxBand.isEmpty {
            fields["BAND_RX"] = rxBand
        } else {
            fields.removeValue(forKey: "BAND_RX")
        }
        
        let endDateHasData = !(extendedFields["TIME_OFF"] ?? "").isEmpty ||
                             !(extendedFields["QSO_DATE_OFF"] ?? "").isEmpty
        if endDateTimeVis != .hidden || endDateHasData {
            fields["QSO_DATE_OFF"] = ADIFDateTimeHelper.dateToADIFDate(endDate)
            fields["TIME_OFF"] = ADIFDateTimeHelper.dateToADIFTime(endDate)
        }
        
        record.adifFields = fields
        
        do {
            try viewContext.save()
            savedSnapshot = currentSnapshot
            return true
        } catch {
            alertTitle = LocalizedStrings.saveFailed.localized
            alertMessage = String(format: LocalizedStrings.saveFailedMessage.localized, error.localizedDescription)
            showingAlert = true
            return false
        }
    }
    
    private func updateQSO() {
        if performSave() {
            alertTitle = LocalizedStrings.saveSuccess.localized
            alertMessage = LocalizedStrings.qsoUpdated.localized
            showingAlert = true
        }
    }
    
    private func saveAndDismiss() {
        focusedField = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if validateInputs() {
                if performSave() {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}
