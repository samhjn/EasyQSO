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

/// A searchable satellite picker that allows selection by name or description.
struct SatellitePickerView: View {
    @Binding var selectedSatellite: String
    @ObservedObject private var satelliteManager = SatelliteManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText = ""

    private var filteredSatellites: [(name: String, description: String?)] {
        let enabled = satelliteManager.enabledSatellites
        var items: [(name: String, description: String?)] = enabled.map { name in
            (name: name, description: SatelliteManager.description(for: name))
        }

        // Ensure current value is in the list even if hidden
        if !selectedSatellite.isEmpty &&
           !items.contains(where: { $0.name.uppercased() == selectedSatellite.uppercased() }) {
            items.append((name: selectedSatellite, description: SatelliteManager.description(for: selectedSatellite)))
        }

        if searchText.isEmpty { return items }

        let query = searchText.uppercased()
        return items.filter { item in
            if item.name.uppercased().contains(query) { return true }
            if let desc = item.description, desc.uppercased().contains(query) { return true }
            return false
        }
    }

    var body: some View {
        NavigationView {
            List {
                // Clear selection option
                Button(action: {
                    selectedSatellite = ""
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Text("dxcc_clear_selection".localized)
                            .foregroundColor(.secondary)
                        Spacer()
                        if selectedSatellite.isEmpty {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }

                ForEach(filteredSatellites, id: \.name) { item in
                    Button(action: {
                        selectedSatellite = item.name
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .foregroundColor(.primary)
                                if let desc = item.description {
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            if item.name.uppercased() == selectedSatellite.uppercased() {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .searchableCompat(text: $searchText, prompt: "satellite_search_placeholder".localized)
            .navigationTitle("satellite_picker_title".localized)
            .navigationBarItems(trailing: Button(LocalizedStrings.cancel.localized) {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

/// Inline satellite display row for use in QSO forms.
/// Shows satellite name/description and allows tapping to pick a different satellite.
struct SatelliteFieldRow: View {
    @Binding var selectedSatellite: String
    @State private var showingPicker = false

    let label: String

    var body: some View {
        Button(action: { showingPicker = true }) {
            HStack {
                Text(label)
                    .foregroundColor(.primary)
                Spacer()
                if selectedSatellite.isEmpty {
                    Text("satellite_not_set".localized)
                        .foregroundColor(.secondary)
                } else {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(selectedSatellite)
                            .foregroundColor(.secondary)
                        if let desc = SatelliteManager.description(for: selectedSatellite) {
                            Text(desc)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .lineLimit(1)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingPicker) {
            SatellitePickerView(selectedSatellite: $selectedSatellite)
        }
    }
}
