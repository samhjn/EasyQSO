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

    /// Items sourced from the manager's enabled list. Does NOT include the
    /// orphan current-selection path.
    private var knownItems: [(id: String, description: String?)] {
        let enabled = contestManager.enabledContests
        let items = enabled.map { id in
            (id: id, description: ContestManager.description(for: id))
        }
        if searchText.isEmpty { return items }
        let query = searchText.uppercased()
        return items.filter { item in
            if item.id.uppercased().contains(query) { return true }
            if let desc = item.description, desc.uppercased().contains(query) { return true }
            return false
        }
    }

    /// True when `selectedContest` is set but not in any known list —
    /// either a deleted custom entry or an externally imported value.
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

    var body: some View {
        List {
            // Current orphan selection — pinned at top, clearly labeled.
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
                // Clear selection option
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
struct ContestFieldRow: View {
    @Binding var selectedContest: String
    @ObservedObject private var contestManager = ContestManager.shared
    let label: String

    private var isOrphan: Bool {
        PickerOrphanDetector.isOrphan(
            value: selectedContest,
            knownItems: contestManager.allKnownContests
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
