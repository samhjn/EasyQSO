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

struct TimezoneSettingsView: View {
    @Binding var exportTimezone: TimeZone
    @Binding var importTimezone: TimeZone
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedTab: Int = 0
    let initialTab: Int
    
    init(exportTimezone: Binding<TimeZone>, importTimezone: Binding<TimeZone>, initialTab: Int = 0) {
        self._exportTimezone = exportTimezone
        self._importTimezone = importTimezone
        self.initialTab = initialTab
        self._selectedTab = State(initialValue: initialTab)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("", selection: $selectedTab) {
                    Text(LocalizedStrings.exportTab.localized).tag(0)
                    Text(LocalizedStrings.importTab.localized).tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                TabView(selection: $selectedTab) {
                    TimezoneSelectionView(
                        selectedTimezone: $exportTimezone,
                        title: LocalizedStrings.exportTimezone.localized,
                        description: LocalizedStrings.exportTimezoneDesc.localized,
                        onTimezoneChanged: { timezone in
                            TimezoneManager.setExportTimezone(timezone)
                        }
                    ).tag(0)
                    
                    TimezoneSelectionView(
                        selectedTimezone: $importTimezone,
                        title: LocalizedStrings.importTimezone.localized, 
                        description: LocalizedStrings.importTimezoneDesc.localized,
                        onTimezoneChanged: { timezone in
                            TimezoneManager.setImportTimezone(timezone)
                        }
                    ).tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedStrings.notes.localized)
                        .font(.headline)
                    
                    Text(LocalizedStrings.timezoneNoteLocal.localized)
                        .font(.caption)
                    
                    Text(LocalizedStrings.timezoneNoteAdif.localized)
                        .font(.caption)
                    
                    Text(LocalizedStrings.timezoneNoteCsv.localized)
                        .font(.caption)
                    
                    Text(LocalizedStrings.timezoneNoteConversion.localized)
                        .font(.caption)
                    
                    Text(LocalizedStrings.timezoneNoteAdifIgnore.localized)
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                .padding()
            }
            .navigationTitle(LocalizedStrings.timezoneSettings.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizedStrings.done.localized) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct TimezoneSelectionView: View {
    @Binding var selectedTimezone: TimeZone
    let title: String
    let description: String
    let onTimezoneChanged: (TimeZone) -> Void
    
    var body: some View {
        Form {
            Section(header: Text(title)) {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section {
                ForEach(TimezoneManager.utcOffsetTimezones, id: \.timezone.identifier) { item in
                    HStack {
                        Text(item.name)
                        Spacer()
                        if selectedTimezone.identifier == item.timezone.identifier ||
                           (selectedTimezone == TimeZone.current && item.name == LocalizedStrings.localTime.localized) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedTimezone = item.timezone
                        onTimezoneChanged(item.timezone)
                    }
                }
            }
        }
    }
} 