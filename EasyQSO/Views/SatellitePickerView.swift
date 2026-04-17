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
/// Designed to be pushed via NavigationLink (no own NavigationView).
struct SatellitePickerView: View {
    @Binding var selectedSatellite: String
    @ObservedObject private var satelliteManager = SatelliteManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText = ""

    /// True orphan: not in any known list (deleted custom or imported).
    private var isCurrentSelectionOrphan: Bool {
        PickerOrphanDetector.isOrphan(
            value: selectedSatellite,
            knownItems: satelliteManager.allKnownSatellites
        )
    }

    private var shouldShowOrphanSection: Bool {
        isCurrentSelectionOrphan &&
        PickerOrphanDetector.matchesSearch(value: selectedSatellite, searchText: searchText)
    }

    /// Enabled items plus the current selection if it's known but hidden.
    /// True orphans are NOT appended here — they go in the orphan section.
    private var knownItems: [(name: String, description: String?)] {
        let enabled = satelliteManager.enabledSatellites
        var items: [(name: String, description: String?)] = enabled.map { name in
            (name: name, description: SatelliteManager.description(for: name))
        }

        // Include current value if it's known but hidden (disabled).
        if !selectedSatellite.isEmpty && !isCurrentSelectionOrphan &&
           !items.contains(where: { $0.name.uppercased() == selectedSatellite.uppercased() }) {
            items.insert((name: selectedSatellite, description: SatelliteManager.description(for: selectedSatellite)), at: 0)
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
        List {
            if shouldShowOrphanSection {
                Section {
                    Button(action: {
                        searchText = ""
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(selectedSatellite)
                                    .foregroundColor(.primary)
                                Text("picker_orphan_not_in_list".localized)
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                } header: {
                    Text("picker_current_selection_header".localized)
                }
            }

            Section {
                Button(action: {
                    selectedSatellite = ""
                    searchText = ""
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

                ForEach(knownItems, id: \.name) { item in
                    Button(action: {
                        selectedSatellite = item.name
                        searchText = ""
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
        }
        .searchableCompat(text: $searchText, prompt: "satellite_search_placeholder".localized)
        .navigationTitle("satellite_picker_title".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Inline satellite display row for use in QSO forms.
/// Uses NavigationLink for lightweight push navigation.
///
/// No @ObservedObject here — adding one can cause NavigationLink instability
/// when the parent re-renders during a pushed picker session.
struct SatelliteFieldRow: View {
    @Binding var selectedSatellite: String
    let label: String

    private var isOrphan: Bool {
        PickerOrphanDetector.isOrphan(
            value: selectedSatellite,
            knownItems: SatelliteManager.shared.allKnownSatellites
        )
    }

    var body: some View {
        NavigationLink {
            SatellitePickerView(selectedSatellite: $selectedSatellite)
        } label: {
            HStack {
                Text(label)
                Spacer()
                if selectedSatellite.isEmpty {
                    Text("satellite_not_set".localized)
                        .foregroundColor(.secondary)
                } else {
                    HStack(spacing: 4) {
                        if isOrphan {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                        Text(selectedSatellite)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}
