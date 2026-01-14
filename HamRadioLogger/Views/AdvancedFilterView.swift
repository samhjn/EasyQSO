/*
 * EasyQSO - 业余无线电通联日志
 * Copyright (C) 2026 ShadowMov
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

struct AdvancedFilterView: View {
    @Binding var filterCriteria: FilterCriteria
    @Environment(\.presentationMode) var presentationMode

    let availableBands: [String]
    let availableModes: [String]

    @State private var minFrequencyText: String = ""
    @State private var maxFrequencyText: String = ""

    var body: some View {
        NavigationView {
            Form {
                // 搜索模式选择
                Section(header: Text(LocalizedStrings.searchMode.localized)) {
                    Picker(LocalizedStrings.searchMode.localized, selection: $filterCriteria.searchMode) {
                        Text(LocalizedStrings.fuzzySearch.localized).tag(SearchMode.fuzzy)
                        Text(LocalizedStrings.exactSearch.localized).tag(SearchMode.exact)
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    Text(filterCriteria.searchMode == .fuzzy ?
                         LocalizedStrings.fuzzySearchDesc.localized :
                         LocalizedStrings.exactSearchDesc.localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // 通用搜索
                Section(header: Text(LocalizedStrings.generalSearch.localized)) {
                    TextField(LocalizedStrings.searchPlaceholder.localized, text: $filterCriteria.searchText)
                        .disableAutocorrection(true)
                }

                // 呼号筛选
                Section(header: Text(LocalizedStrings.callsign.localized)) {
                    TextField(LocalizedStrings.enterCallsign.localized, text: $filterCriteria.callsignFilter)
                        .disableAutocorrection(true)
                        .autocapitalization(.allCharacters)
                }

                // 波段筛选
                Section(header: Text(LocalizedStrings.band.localized)) {
                    TextField(LocalizedStrings.enterBand.localized, text: $filterCriteria.bandFilter)
                        .disableAutocorrection(true)

                    if !availableBands.isEmpty {
                        Text(LocalizedStrings.orSelectBands.localized)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ForEach(availableBands, id: \.self) { band in
                            MultipleSelectionRow(
                                title: band,
                                isSelected: filterCriteria.selectedBands.contains(band)
                            ) {
                                if filterCriteria.selectedBands.contains(band) {
                                    filterCriteria.selectedBands.remove(band)
                                } else {
                                    filterCriteria.selectedBands.insert(band)
                                }
                            }
                        }
                    }
                }

                // 模式筛选
                Section(header: Text(LocalizedStrings.mode.localized)) {
                    TextField(LocalizedStrings.enterMode.localized, text: $filterCriteria.modeFilter)
                        .disableAutocorrection(true)

                    if !availableModes.isEmpty {
                        Text(LocalizedStrings.orSelectModes.localized)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ForEach(availableModes, id: \.self) { mode in
                            MultipleSelectionRow(
                                title: mode,
                                isSelected: filterCriteria.selectedModes.contains(mode)
                            ) {
                                if filterCriteria.selectedModes.contains(mode) {
                                    filterCriteria.selectedModes.remove(mode)
                                } else {
                                    filterCriteria.selectedModes.insert(mode)
                                }
                            }
                        }
                    }
                }

                // 时间范围筛选
                Section(header: Text(LocalizedStrings.dateRange.localized)) {
                    DatePicker(
                        LocalizedStrings.startDate.localized,
                        selection: Binding(
                            get: { filterCriteria.startDate ?? Date() },
                            set: { filterCriteria.startDate = $0 }
                        ),
                        displayedComponents: .date
                    )

                    if filterCriteria.startDate != nil {
                        Button(LocalizedStrings.clearStartDate.localized) {
                            filterCriteria.startDate = nil
                        }
                        .foregroundColor(.red)
                    }

                    DatePicker(
                        LocalizedStrings.endDate.localized,
                        selection: Binding(
                            get: { filterCriteria.endDate ?? Date() },
                            set: { filterCriteria.endDate = $0 }
                        ),
                        displayedComponents: .date
                    )

                    if filterCriteria.endDate != nil {
                        Button(LocalizedStrings.clearEndDate.localized) {
                            filterCriteria.endDate = nil
                        }
                        .foregroundColor(.red)
                    }
                }

                // 频率范围筛选
                Section(header: Text(LocalizedStrings.frequencyRange.localized)) {
                    HStack {
                        Text(LocalizedStrings.minFrequency.localized)
                        Spacer()
                        TextField("0.000", text: $minFrequencyText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .onChange(of: minFrequencyText) { newValue in
                                filterCriteria.minFrequency = Double(newValue)
                            }
                        Text("MHz")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text(LocalizedStrings.maxFrequency.localized)
                        Spacer()
                        TextField("0.000", text: $maxFrequencyText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .onChange(of: maxFrequencyText) { newValue in
                                filterCriteria.maxFrequency = Double(newValue)
                            }
                        Text("MHz")
                            .foregroundColor(.secondary)
                    }
                }

                // 其他筛选
                Section(header: Text(LocalizedStrings.otherFilters.localized)) {
                    TextField(LocalizedStrings.name.localized, text: $filterCriteria.nameFilter)
                        .disableAutocorrection(true)

                    TextField(LocalizedStrings.qth.localized, text: $filterCriteria.qthFilter)
                        .disableAutocorrection(true)

                    TextField(LocalizedStrings.gridSquare.localized, text: $filterCriteria.gridSquareFilter)
                        .disableAutocorrection(true)
                        .autocapitalization(.allCharacters)

                    TextField(LocalizedStrings.satellite.localized, text: $filterCriteria.satelliteFilter)
                        .disableAutocorrection(true)
                }

                // 操作按钮
                Section {
                    Button(action: {
                        filterCriteria.reset()
                        minFrequencyText = ""
                        maxFrequencyText = ""
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text(LocalizedStrings.resetFilters.localized)
                        }
                        .foregroundColor(.orange)
                    }

                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text(LocalizedStrings.applyFilters.localized)
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle(LocalizedStrings.advancedFilter.localized)
            .navigationBarItems(
                trailing: Button(LocalizedStrings.done.localized) {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .onAppear {
            // 初始化频率文本框
            if let minFreq = filterCriteria.minFrequency {
                minFrequencyText = String(format: "%.3f", minFreq)
            }
            if let maxFreq = filterCriteria.maxFrequency {
                maxFrequencyText = String(format: "%.3f", maxFreq)
            }
        }
    }
}

// 多选行组件
struct MultipleSelectionRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
    }
}
