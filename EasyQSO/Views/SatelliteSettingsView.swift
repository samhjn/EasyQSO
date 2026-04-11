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

struct SatelliteSettingsView: View {
    @ObservedObject private var satelliteManager = SatelliteManager.shared
    @State private var newSatelliteName = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var searchText = ""

    private func satelliteMatchesSearch(_ name: String) -> Bool {
        if searchText.isEmpty { return true }
        let query = searchText.uppercased()
        if name.uppercased().contains(query) { return true }
        if let desc = SatelliteManager.description(for: name),
           desc.uppercased().contains(query) { return true }
        return false
    }

    private var filteredPresetSatellites: [(name: String, description: String)] {
        if searchText.isEmpty { return SatelliteManager.presetSatellites }
        return SatelliteManager.presetSatellites.filter { satelliteMatchesSearch($0.name) }
    }

    private var filteredCustomSatellites: [String] {
        if searchText.isEmpty { return satelliteManager.customSatellites }
        return satelliteManager.customSatellites.filter { satelliteMatchesSearch($0) }
    }

    var body: some View {
        List {
            // Search bar
            Section {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("satellite_search_placeholder".localized, text: $searchText)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Preset satellites
            if !filteredPresetSatellites.isEmpty {
                Section(header: Text("preset_satellites".localized)) {
                    ForEach(filteredPresetSatellites, id: \.name) { entry in
                        satelliteRow(name: entry.name, description: entry.description, isCustom: false)
                    }
                }
            }

            // Custom satellites
            if searchText.isEmpty || !filteredCustomSatellites.isEmpty {
                Section(header: Text("custom_satellites".localized)) {
                    ForEach(filteredCustomSatellites, id: \.self) { sat in
                        satelliteRow(name: sat, description: nil, isCustom: true)
                    }

                    if searchText.isEmpty {
                        HStack {
                            TextField("new_satellite_placeholder".localized, text: $newSatelliteName)
                                .autocapitalization(.allCharacters)
                                .onChange(of: newSatelliteName) { newValue in
                                    newSatelliteName = newValue.uppercased()
                                }

                            Button {
                                let trimmed = newSatelliteName.trimmingCharacters(in: .whitespaces)
                                if SatelliteManager.allPresetNames.contains(where: { $0.uppercased() == trimmed.uppercased() }) ||
                                   satelliteManager.customSatellites.contains(where: { $0.uppercased() == trimmed.uppercased() }) {
                                    alertMessage = "satellite_already_exists".localized
                                    showingAlert = true
                                    return
                                }
                                withAnimation {
                                    satelliteManager.addCustomSatellite(trimmed)
                                    newSatelliteName = ""
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                            }
                            .buttonStyle(.plain)
                            .disabled(newSatelliteName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
            }

            // Description
            if searchText.isEmpty {
                Section {
                    Text("satellite_settings_desc".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("satellite_settings_title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(LocalizedStrings.validationError.localized),
                message: Text(alertMessage)
            )
        }
    }

    // MARK: - Satellite Row

    @ViewBuilder
    private func satelliteRow(name: String, description: String?, isCustom: Bool) -> some View {
        let isHidden = satelliteManager.isHidden(name)

        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .fontWeight(isHidden ? .regular : .medium)
                    .foregroundColor(isHidden ? .secondary : .primary)
                if let desc = description {
                    Text(desc)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if isCustom {
                Button {
                    withAnimation { satelliteManager.removeCustomSatellite(name) }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            Toggle("", isOn: Binding(
                get: { !isHidden },
                set: { satelliteManager.setHidden(!$0, for: name) }
            ))
            .labelsHidden()
        }
    }
}
