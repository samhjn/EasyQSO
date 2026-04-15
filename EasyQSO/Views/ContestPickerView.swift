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

    private var filteredContests: [(id: String, description: String?)] {
        let enabled = contestManager.enabledContests
        var items: [(id: String, description: String?)] = enabled.map { id in
            (id: id, description: ContestManager.description(for: id))
        }

        // Ensure current value is in the list even if hidden
        if !selectedContest.isEmpty &&
           !items.contains(where: { $0.id.uppercased() == selectedContest.uppercased() }) {
            items.append((id: selectedContest, description: ContestManager.description(for: selectedContest)))
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
            // Clear selection option
            Button(action: {
                selectedContest = ""
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

            ForEach(filteredContests, id: \.id) { item in
                Button(action: {
                    selectedContest = item.id
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
        .searchableCompat(text: $searchText, prompt: "contest_search_placeholder".localized)
        .navigationTitle("contest_picker_title".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Inline contest display row for use in QSO forms.
/// Uses NavigationLink for lightweight push navigation.
struct ContestFieldRow: View {
    @Binding var selectedContest: String
    let label: String

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
                    Text(selectedContest)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
