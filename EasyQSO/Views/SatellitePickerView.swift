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

    /// Items sourced from the manager's enabled list. Does NOT include the
    /// orphan current-selection path.
    private var knownItems: [(name: String, description: String?)] {
        let enabled = satelliteManager.enabledSatellites
        let items = enabled.map { name in
            (name: name, description: SatelliteManager.description(for: name))
        }
        if searchText.isEmpty { return items }
        let query = searchText.uppercased()
        return items.filter { item in
            if item.name.uppercased().contains(query) { return true }
            if let desc = item.description, desc.uppercased().contains(query) { return true }
            return false
        }
    }

    /// True when `selectedSatellite` is set but not in any known list —
    /// either a deleted custom entry or an externally imported value.
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

    var body: some View {
        List {
            // Current orphan selection — pinned at top, clearly labeled.
            if shouldShowOrphanSection {
                Section {
                    Button(action: {
                        // Keep the orphan value as-is and return.
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
                // Clear selection option
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
struct SatelliteFieldRow: View {
    @Binding var selectedSatellite: String
    @ObservedObject private var satelliteManager = SatelliteManager.shared
    let label: String

    private var isOrphan: Bool {
        PickerOrphanDetector.isOrphan(
            value: selectedSatellite,
            knownItems: satelliteManager.allKnownSatellites
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
