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
import CoreData
import CoreLocation

struct QSORecordView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject private var fieldVisibility = FieldVisibilityManager.shared
    @ObservedObject private var modeManager = ModeManager.shared
    @ObservedObject private var autoFillManager = AutoFillManager.shared
    @StateObject private var autoFillEngine = AutoFillEngine.standardEngine()
    @FocusState private var focusedField: String?
    
    // Core fields
    @State private var callsign = ""
    @State private var date = Date()
    @State private var endDate = Date()
    @State private var band = "20m"
    @State private var mode = "SSB"
    @State private var submode = ""
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
    @State private var showingResetAlert = false
    @State private var pullDistance: CGFloat = 0
    @State private var showingPullHint = false
    @State private var formResetToken = UUID()
    @State private var formScrollAtTop = true
    @State private var formScrollInitialY: CGFloat?
    
    // ADIF extended fields
    @State private var extendedFields: [String: String] = [:]
    
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
    
    @State private var rxBand = ""
    @State private var isRxBandChangedByFrequency = false
    
    let bands = ["160m", "80m", "40m", "30m", "20m", "17m", "15m", "12m", "10m", "6m", "2m", "70cm"]
    
    private var modePickerItems: [ModePickerItem] {
        modeManager.pickerItems(currentMode: mode, currentSubmode: submode)
    }

    private var modePickerTag: Binding<String> {
        Binding(
            get: { submode.isEmpty ? mode : submode },
            set: { newValue in
                if let parent = ModeManager.parentMode(for: newValue) {
                    mode = parent
                    submode = newValue
                } else {
                    mode = newValue
                    submode = ""
                }
            }
        )
    }

    private var isVoiceMode: Bool { ModeManager.isVoiceMode(mode: mode, submode: submode.isEmpty ? nil : submode) }
    private var isCWMode: Bool { ModeManager.isCWMode(mode: mode, submode: submode.isEmpty ? nil : submode) }
    private var isDigitalMode: Bool { ModeManager.isDigitalMode(mode: mode, submode: submode.isEmpty ? nil : submode) }
    
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
    
    // MARK: - User input detection
    
    private var hasUserInput: Bool {
        !callsign.isEmpty || !rstSent.isEmpty || !rstReceived.isEmpty ||
        !name.isEmpty || !qth.isEmpty || !gridSquare.isEmpty ||
        !cqZone.isEmpty || !ituZone.isEmpty || !remarks.isEmpty ||
        !extendedFields.isEmpty
    }
    
    private var shouldShowPullHint: Bool {
        pullDistance > 42 && formScrollAtTop
    }
    
    private var pullHintText: String {
        hasUserInput ? "new_qso_pull_reset_hint".localized : "new_qso_pull_refresh_time_hint".localized
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
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            Form {
                // Invisible scroll-position tracker
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: FormScrollOffsetKey.self,
                        value: proxy.frame(in: .named("formContainer")).minY
                    )
                }
                .frame(height: 0)
                .listRowInsets(EdgeInsets())

                // ═══════════ Basic Info ═══════════
                Section(header: Text(LocalizedStrings.basicInfo.localized)) {
                    TextField(LocalizedStrings.callsign.localized, text: $callsign)
                        .autocapitalization(.allCharacters)
                        .focused($focusedField, equals: "CALL")
                        .onChange(of: callsign) { newValue in
                            callsign = newValue.uppercased()
                            applyAutoFillForTrigger("CALL")
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
                                autoFillEngine.trackFieldChange("FREQ", newValue: newValue)
                                if let freq = Double(newValue), let autoBand = QSORecord.bandForFrequency(freq) {
                                    if band != autoBand {
                                        isBandChangedByFrequency = true
                                        band = autoBand
                                    }
                                }
                            }
                            .autoFillLabel(LocalizedStrings.frequency.localized, text: frequency, isAutoFilled: autoFillEngine.isAutoFilled("FREQ"))
                    }
                    
                    Picker(selection: $band) {
                        ForEach(bands, id: \.self) { Text($0) }
                    } label: {
                        AutoFillPickerLabel(title: LocalizedStrings.band.localized, isAutoFilled: autoFillEngine.isAutoFilled("BAND"))
                    }
                    .onChange(of: band) { newBand in
                        autoFillEngine.trackFieldChange("BAND", newValue: newBand)
                        if isBandChangedByFrequency {
                            isBandChangedByFrequency = false
                        } else {
                            applyAutoFillForTrigger("BAND")
                        }
                    }

                    Picker(selection: modePickerTag) {
                        ForEach(modePickerItems) { item in
                            Text(item.displayLabel).tag(item.tagValue)
                        }
                    } label: {
                        AutoFillPickerLabel(title: LocalizedStrings.mode.localized, isAutoFilled: autoFillEngine.isAutoFilled("MODE"))
                    }
                    .onChange(of: mode) { newMode in
                        autoFillEngine.trackFieldChange("MODE", newValue: newMode)
                        applyAutoFillForTrigger("MODE")
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
            }
            .id(formResetToken)
            .onPreferenceChange(FormScrollOffsetKey.self) { value in
                if formScrollInitialY == nil { formScrollInitialY = value }
                formScrollAtTop = value >= (formScrollInitialY ?? value) - 10
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        if value.translation.height <= 0 {
                            pullDistance = 0
                            showingPullHint = false
                            return
                        }
                        pullDistance = value.translation.height
                        withAnimation(.easeOut(duration: 0.12)) {
                            showingPullHint = shouldShowPullHint
                        }
                    }
                    .onEnded { _ in
                        pullDistance = 0
                        withAnimation(.easeOut(duration: 0.12)) {
                            showingPullHint = false
                        }
                    }
            )
            .refreshable {
                pullDistance = 0
                showingPullHint = false
                if hasUserInput {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    showingResetAlert = true
                } else {
                    date = Date()
                    endDate = Date()
                }
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 80)
            }
            
            VStack {
                if showingPullHint {
                    Text(pullHintText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(Capsule())
                        // Keep clear of the native pull-to-refresh spinner.
                        .padding(.top, 56)
                        .transition(.opacity)
                }
                
                Spacer()
            }
            .allowsHitTesting(false)
            
            VStack {
                Spacer()
                
                Button(action: {
                    focusedField = nil
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
                    LinearGradient(
                        colors: [Color.clear, Color(UIColor.systemBackground).opacity(0.9)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 100)
                )
            }
            .allowsHitTesting(true)
        }
        .coordinateSpace(name: "formContainer")
        .navigationTitle(LocalizedStrings.recordQSO.localized)
        .toolbar {
            KeyboardToolbar(focusedField: $focusedField, orderedFields: keyboardOrderedFieldIDs)
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
        .alert("new_qso_reset_title".localized, isPresented: $showingResetAlert) {
            Button("new_qso_reset_confirm".localized, role: .destructive) {
                resetForm()
                formResetToken = UUID()
            }
            Button(LocalizedStrings.cancel.localized, role: .cancel) {
                pullDistance = 0
                showingPullHint = false
                formResetToken = UUID()
            }
        } message: {
            Text("new_qso_reset_message".localized)
        }
        .onChange(of: showingAlert) { isShowing in
            if isShowing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    showingAlert = false
                    if !isValidationError {
                        clearFields()
                    }
                }
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                if autoFillManager.autoFillFrequencyAndMode {
                    loadLatestQSOSettings()
                }
                // Trigger own QTH autofill based on current band/mode
                applyAutoFillForTrigger("BAND")
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
                ADIFDynamicFieldRows(extendedFields: $extendedFields, category: .contactedStation, visibilityManager: fieldVisibility, focusedField: $focusedField, isFieldAutoFilled: { autoFillEngine.isAutoFilled($0) })
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
            .onChange(of: cqZone) { _ in autoFillEngine.trackFieldChange("CQZ", newValue: cqZone) }
            .autoFillLabel(LocalizedStrings.cqZone.localized, text: cqZone, isAutoFilled: autoFillEngine.isAutoFilled("CQZ"))

        TextField(LocalizedStrings.ituZone.localized, text: $ituZone)
            .keyboardType(.numberPad)
            .focused($focusedField, equals: "ITUZ")
            .onChange(of: ituZone) { _ in autoFillEngine.trackFieldChange("ITUZ", newValue: ituZone) }
            .autoFillLabel(LocalizedStrings.ituZone.localized, text: ituZone, isAutoFilled: autoFillEngine.isAutoFilled("ITUZ"))
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
                .onChange(of: ownQTH) { _ in autoFillEngine.trackFieldChange("MY_CITY", newValue: ownQTH) }
                .autoFillLabel(LocalizedStrings.ownQth.localized, text: ownQTH, isAutoFilled: autoFillEngine.isAutoFilled("MY_CITY"))

            Button(LocalizedStrings.selectOnMap.localized) {
                focusedField = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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
                autoFillEngine.trackFieldChange("MY_GRIDSQUARE", newValue: ownGridSquare)
            }
            .autoFillLabel(LocalizedStrings.gridSquare.localized, text: ownGridSquare, isAutoFilled: autoFillEngine.isAutoFilled("MY_GRIDSQUARE"))

        TextField(LocalizedStrings.cqZone.localized, text: $ownCQZone)
            .keyboardType(.numberPad)
            .focused($focusedField, equals: "MY_CQ_ZONE")
            .onChange(of: ownCQZone) { _ in autoFillEngine.trackFieldChange("MY_CQ_ZONE", newValue: ownCQZone) }
            .autoFillLabel(LocalizedStrings.cqZone.localized, text: ownCQZone, isAutoFilled: autoFillEngine.isAutoFilled("MY_CQ_ZONE"))

        TextField(LocalizedStrings.ituZone.localized, text: $ownITUZone)
            .keyboardType(.numberPad)
            .focused($focusedField, equals: "MY_ITU_ZONE")
            .onChange(of: ownITUZone) { _ in autoFillEngine.trackFieldChange("MY_ITU_ZONE", newValue: ownITUZone) }
            .autoFillLabel(LocalizedStrings.ituZone.localized, text: ownITUZone, isAutoFilled: autoFillEngine.isAutoFilled("MY_ITU_ZONE"))
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
                    TextField("adif_field_tx_pwr".localized, text: $txPower)
                        .focused($focusedField, equals: "TX_PWR")
                        .onChange(of: txPower) { _ in autoFillEngine.trackFieldChange("TX_PWR", newValue: txPower) }
                        .autoFillLabel("adif_field_tx_pwr".localized, text: txPower, isAutoFilled: autoFillEngine.isAutoFilled("TX_PWR"))
                }
                if hasSatName {
                    SatelliteFieldRow(selectedSatellite: $satellite, label: LocalizedStrings.satellite.localized)
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
                    // Collapsed datetime groups → DatePicker
                    if dateTimeVis == .collapsed {
                        DatePicker(LocalizedStrings.dateTime.localized, selection: $date)
                    }
                    if endDateTimeVis == .collapsed {
                        DatePicker(
                            ADIFFields.fieldGroups.first { $0.id == "group_end_datetime" }?.displayName ?? "end_date".localized,
                            selection: $endDate
                        )
                    }
                    
                    // Collapsed contacted QTH group
                    if contactedQTHVis == .collapsed {
                        Text(ADIFFields.fieldGroups.first { $0.id == "group_contacted_qth" }?.displayName ?? "QTH")
                            .font(.caption).foregroundColor(.secondary)
                        contactedQTHFields
                    }
                    
                    // Collapsed own QTH group
                    if ownQTHVis == .collapsed {
                        Text(ADIFFields.fieldGroups.first { $0.id == "group_own_qth" }?.displayName ?? "QTH")
                            .font(.caption).foregroundColor(.secondary)
                        ownQTHFields
                    }
                    
                    // Individual collapsed fields
                    let grouped = Dictionary(grouping: collapsedFields) { $0.category }
                    let sortedCats = grouped.keys.sorted { $0.sortOrder < $1.sortOrder }
                    
                    ForEach(sortedCats, id: \.self) { category in
                        if let fields = grouped[category] {
                            Text(category.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .listRowSeparator(.hidden)

                            ForEach(fields) { field in
                                if field.id == "DXCC" || field.id == "MY_DXCC" {
                                    DXCCFieldRow(dxccCode: bindingForExtended(field.id), label: field.displayName, isAutoFilled: autoFillEngine.isAutoFilled(field.id))
                                } else if field.id == "CONTEST_ID" {
                                    ContestFieldRow(selectedContest: bindingForExtended(field.id), label: field.displayName)
                                } else {
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
        } else if isDigitalMode {
            Button("-10") { binding.wrappedValue = "-10" }
                .buttonStyle(.borderless)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
        }
        // Unknown mode: no quick button, user enters RST manually
    }
    
    // MARK: - AutoFill Engine Integration

    /// Trigger autofill evaluation for a field change, respecting enabled settings.
    private func applyAutoFillForTrigger(_ trigger: String) {
        let freqModeEnabled = autoFillManager.autoFillFrequencyAndMode
        let ownQTHEnabled = autoFillManager.autoFillOwnQTH
        let dxccEnabled = autoFillManager.autoFillDXCC

        let results = autoFillEngine.evaluate(
            trigger: trigger,
            currentValues: currentFormValues(),
            context: viewContext
        )

        // Filter results based on which autofill categories are enabled
        let ownQTHKeys: Set<String> = ["MY_CITY", "MY_GRIDSQUARE", "MY_CQ_ZONE", "MY_ITU_ZONE"]
        let freqModeKeys: Set<String> = ["FREQ", "TX_PWR",
            "STATION_CALLSIGN", "OPERATOR", "MY_RIG", "MY_ANTENNA",
            "MY_POTA_REF", "MY_SOTA_REF", "MY_WWFF_REF", "MY_SIG", "MY_SIG_INFO"]
        let dxccKeys: Set<String> = ["CQZ", "ITUZ", "DXCC"]

        var filtered: [String: String] = [:]
        for (key, value) in results {
            if ownQTHKeys.contains(key) && !ownQTHEnabled { continue }
            if freqModeKeys.contains(key) && !freqModeEnabled { continue }
            if dxccKeys.contains(key) && !dxccEnabled { continue }
            filtered[key] = value
        }

        applyAutoFillResults(filtered)
    }

    /// Apply autofill results to form fields.
    private func applyAutoFillResults(_ results: [String: String]) {
        for (field, value) in results {
            switch field {
            case "FREQ":        frequency = value
            case "TX_PWR":      txPower = value
            case "CQZ":         cqZone = value
            case "ITUZ":        ituZone = value
            case "MY_CITY":     ownQTH = value
            case "MY_GRIDSQUARE":
                ownGridSquare = value
                if !value.isEmpty {
                    selectedOwnLocation = QTHManager.coordinateFromGridSquare(value)
                }
            case "MY_CQ_ZONE":  ownCQZone = value
            case "MY_ITU_ZONE": ownITUZone = value
            default:
                // Extended fields (own station keys, DXCC, etc.)
                extendedFields[field] = value
            }
        }
    }


    /// Snapshot of current form field values for the engine.
    private func currentFormValues() -> [String: String] {
        var values: [String: String] = [
            "CALL": callsign,
            "BAND": band,
            "MODE": mode,
            "FREQ": frequency,
            "TX_PWR": txPower,
            "CQZ": cqZone,
            "ITUZ": ituZone,
            "MY_CITY": ownQTH,
            "MY_GRIDSQUARE": ownGridSquare,
            "MY_CQ_ZONE": ownCQZone,
            "MY_ITU_ZONE": ownITUZone,
        ]
        for (key, val) in extendedFields {
            values[key] = val
        }
        return values
    }
    
    private func loadLatestQSOSettings() {
        if let latestQSO = QSORecord.getLatestQSO(context: viewContext) {
            band = latestQSO.band
            autoFillEngine.recordAutoFill("BAND", value: latestQSO.band)
            mode = latestQSO.mode
            autoFillEngine.recordAutoFill("MODE", value: latestQSO.mode)
            submode = latestQSO.adifFields["SUBMODE"] ?? ""
            if latestQSO.frequencyMHz > 0 {
                let freqStr = String(latestQSO.frequencyMHz)
                frequency = freqStr
                autoFillEngine.recordAutoFill("FREQ", value: freqStr)
            }

            let latestFields = latestQSO.adifFields
            if let tp = latestQSO.txPower, !tp.isEmpty {
                txPower = tp
                autoFillEngine.recordAutoFill("TX_PWR", value: tp)
            }

            let ownStationKeys = [
                "STATION_CALLSIGN", "OPERATOR", "MY_RIG", "MY_ANTENNA",
                "MY_POTA_REF", "MY_SOTA_REF", "MY_WWFF_REF",
                "MY_SIG", "MY_SIG_INFO"
            ]
            for key in ownStationKeys {
                if let val = latestFields[key], !val.isEmpty {
                    extendedFields[key] = val
                    autoFillEngine.recordAutoFill(key, value: val)
                }
            }
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
    
    private func saveQSO() {
        let newQSO = QSORecord(context: viewContext)
        newQSO.callsign = callsign
        newQSO.date = date
        newQSO.band = band
        newQSO.mode = mode
        newQSO.frequencyMHz = Double(frequency) ?? 0.0
        newQSO.rxFrequencyMHz = Double(rxFrequency) ?? 0.0
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
        newQSO.setCoordinate(selectedLocation)
        
        if !rxBand.isEmpty {
            extendedFields["BAND_RX"] = rxBand
        }
        
        if !submode.isEmpty {
            extendedFields["SUBMODE"] = submode
        } else {
            extendedFields.removeValue(forKey: "SUBMODE")
        }

        newQSO.adifFields = extendedFields
        
        var fields = newQSO.adifFields
        
        if endDateTimeVis != .hidden {
            fields["QSO_DATE_OFF"] = ADIFDateTimeHelper.dateToADIFDate(endDate)
            fields["TIME_OFF"] = ADIFDateTimeHelper.dateToADIFTime(endDate)
        }
        
        if fields["MY_GRIDSQUARE"] == nil && !ownGridSquare.isEmpty {
            fields["MY_GRIDSQUARE"] = ownGridSquare
        }
        if fields["MY_CQ_ZONE"] == nil && !ownCQZone.isEmpty {
            fields["MY_CQ_ZONE"] = ownCQZone
        }
        if fields["MY_ITU_ZONE"] == nil && !ownITUZone.isEmpty {
            fields["MY_ITU_ZONE"] = ownITUZone
        }
        if fields["MY_CITY"] == nil && !ownQTH.isEmpty {
            fields["MY_CITY"] = ownQTH
        }
        if let ownCoord = selectedOwnLocation {
            if fields["MY_LAT"] == nil {
                fields["MY_LAT"] = formatADIFLocation(latitude: ownCoord.latitude)
            }
            if fields["MY_LON"] == nil {
                fields["MY_LON"] = formatADIFLocation(longitude: ownCoord.longitude)
            }
        }
        newQSO.adifFields = fields
        
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
    
    private func resetForm() {
        autoFillEngine.resetAllSources()
        callsign = ""
        date = Date()
        endDate = Date()
        band = "20m"
        mode = "SSB"
        submode = ""
        frequency = ""
        rxFrequency = ""
        rxBand = ""
        txPower = ""
        rstSent = ""
        rstReceived = ""
        name = ""
        qth = ""
        gridSquare = ""
        cqZone = ""
        ituZone = ""
        satellite = ""
        remarks = ""
        selectedLocation = nil
        extendedFields = [:]
        if autoFillManager.autoFillFrequencyAndMode {
            loadLatestQSOSettings()
        }
        applyAutoFillForTrigger("BAND")
    }
    
    private func clearFields() {
        // Preserve autofill sources for fields we're keeping
        let currentFrequency = frequency
        let currentBand = band
        let currentMode = mode
        let currentSubmode = submode
        let currentRxFrequency = rxFrequency
        let currentTxPower = txPower
        let currentSatellite = satellite

        let ownStationKeys: Set<String> = [
            "STATION_CALLSIGN", "OPERATOR", "MY_RIG", "MY_ANTENNA",
            "MY_POTA_REF", "MY_SOTA_REF", "MY_WWFF_REF",
            "MY_SIG", "MY_SIG_INFO", "MY_CITY", "MY_GRIDSQUARE",
            "MY_CQ_ZONE", "MY_ITU_ZONE", "MY_LAT", "MY_LON"
        ]
        let preservedExtended = extendedFields.filter { ownStationKeys.contains($0.key) }

        callsign = ""
        date = Date()
        endDate = Date()
        band = currentBand
        mode = currentMode
        submode = currentSubmode
        frequency = currentFrequency
        rxFrequency = currentRxFrequency
        txPower = currentTxPower
        satellite = currentSatellite
        rstSent = ""
        rstReceived = ""
        name = ""
        qth = ""
        gridSquare = ""
        cqZone = ""
        ituZone = ""
        selectedLocation = nil
        remarks = ""
        extendedFields = preservedExtended
    }
    
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
    
    private func formatADIFLocation(latitude: Double) -> String {
        let dir = latitude >= 0 ? "N" : "S"
        let abs = abs(latitude)
        let deg = Int(abs)
        let min = (abs - Double(deg)) * 60.0
        return String(format: "%@%03d %05.3f", dir, deg, min)
    }
    
    private func formatADIFLocation(longitude: Double) -> String {
        let dir = longitude >= 0 ? "E" : "W"
        let abs = abs(longitude)
        let deg = Int(abs)
        let min = (abs - Double(deg)) * 60.0
        return String(format: "%@%03d %05.3f", dir, deg, min)
    }
}

// MARK: - ADIF Date/Time Helpers

enum ADIFDateTimeHelper {
    private static let utcTimeZone = TimeZone(identifier: "UTC")!
    
    static func dateToADIFDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        f.timeZone = utcTimeZone
        return f.string(from: date)
    }
    
    static func dateToADIFTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HHmmss"
        f.timeZone = utcTimeZone
        return f.string(from: date)
    }
    
    static func adifToDate(dateStr: String?, timeStr: String?) -> Date? {
        guard let d = dateStr, d.count == 8 else { return nil }
        let t = timeStr ?? "0000"
        let padded = t.count >= 6 ? String(t.prefix(6)) : (t.count >= 4 ? String(t.prefix(4)) + "00" : t)
        let f = DateFormatter()
        f.dateFormat = "yyyyMMddHHmmss"
        f.timeZone = utcTimeZone
        return f.date(from: d + padded)
    }
}

// MARK: - Scroll Offset Tracking

private struct FormScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
