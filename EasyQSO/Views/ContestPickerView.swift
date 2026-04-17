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

/// A searchable contest picker that allows selection by contest ID or description.
/// Designed to be pushed via NavigationLink (no own NavigationView).
struct ContestPickerView: View {
    @Binding var selectedContest: String
    @ObservedObject private var contestManager = ContestManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText = ""

    /// True orphan: not in any known list (deleted custom or imported).
    private var isCurrentSelectionOrphan: Bool {
        PickerOrphanDetector.isOrphan(
            value: selectedContest,
            knownItems: contestManager.allKnownContests
        )
    }

    private var shouldShowOrphanSection: Bool {
        isCurrentSelectionOrphan &&
        PickerOrphanDetector.matchesSearch(value: selectedContest, searchText: searchText)
    }

    /// Enabled items plus the current selection if it's known but hidden.
    /// True orphans are NOT appended here — they go in the orphan section.
    private var knownItems: [(id: String, description: String?)] {
        let enabled = contestManager.enabledContests
        var items: [(id: String, description: String?)] = enabled.map { id in
            (id: id, description: ContestManager.description(for: id))
        }

        if PickerOrphanDetector.isHiddenButKnown(
            value: selectedContest,
            enabledItems: enabled,
            allKnownItems: contestManager.allKnownContests
        ) {
            items.insert((id: selectedContest, description: ContestManager.description(for: selectedContest)), at: 0)
        }

        if searchText.isEmpty { return items }
        let query = searchText.uppercased()
        return items.filter { item in
            if item.id.uppercased().contains(query) { return true }
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
                                Text(selectedContest)
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
                    selectedContest = ""
                    searchText = ""
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Text("dxcc_clear_selection".localized)
                            .foregroundColor(.secondary)
                        Spacer()
                        if selectedContest.isEmpty {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }

                ForEach(knownItems, id: \.id) { item in
                    Button(action: {
                        selectedContest = item.id
                        searchText = ""
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.id)
                                    .foregroundColor(.primary)
                                if let desc = item.description {
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            if item.id.uppercased() == selectedContest.uppercased() {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
        }
        .searchableCompat(text: $searchText, prompt: "contest_search_placeholder".localized)
        .navigationTitle("contest_picker_title".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Inline contest display row for use in QSO forms.
/// Uses NavigationLink for lightweight push navigation.
///
/// No @ObservedObject here — adding one can cause NavigationLink instability
/// when the parent re-renders during a pushed picker session.
struct ContestFieldRow: View {
    @Binding var selectedContest: String
    let label: String

    private var isOrphan: Bool {
        PickerOrphanDetector.isOrphan(
            value: selectedContest,
            knownItems: ContestManager.shared.allKnownContests
        )
    }

    var body: some View {
        NavigationLink {
            ContestPickerView(selectedContest: $selectedContest)
        } label: {
            HStack {
                Text(label)
                Spacer()
                if selectedContest.isEmpty {
                    Text("contest_not_set".localized)
                        .foregroundColor(.secondary)
                } else {
                    HStack(spacing: 4) {
                        if isOrphan {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                        Text(selectedContest)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}
