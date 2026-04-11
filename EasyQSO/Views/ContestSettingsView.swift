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

struct ContestSettingsView: View {
    @ObservedObject private var contestManager = ContestManager.shared
    @State private var newContestId = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var searchText = ""

    private func contestMatchesSearch(_ id: String) -> Bool {
        if searchText.isEmpty { return true }
        let query = searchText.uppercased()
        if id.uppercased().contains(query) { return true }
        if let desc = ContestManager.description(for: id),
           desc.uppercased().contains(query) { return true }
        return false
    }

    private var filteredPresetContests: [(id: String, description: String)] {
        if searchText.isEmpty { return ContestManager.presetContests }
        return ContestManager.presetContests.filter { contestMatchesSearch($0.id) }
    }

    private var filteredCustomContests: [String] {
        if searchText.isEmpty { return contestManager.customContests }
        return contestManager.customContests.filter { contestMatchesSearch($0) }
    }

    var body: some View {
        List {
            // Search bar
            Section {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("contest_search_placeholder".localized, text: $searchText)
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

            // Preset contests
            if !filteredPresetContests.isEmpty {
                Section(header: Text("preset_contests".localized)) {
                    ForEach(filteredPresetContests, id: \.id) { entry in
                        contestRow(id: entry.id, description: entry.description, isCustom: false)
                    }
                }
            }

            // Custom contests
            if searchText.isEmpty || !filteredCustomContests.isEmpty {
                Section(header: Text("custom_contests".localized)) {
                    ForEach(filteredCustomContests, id: \.self) { contest in
                        contestRow(id: contest, description: nil, isCustom: true)
                    }

                    if searchText.isEmpty {
                        HStack {
                            TextField("new_contest_placeholder".localized, text: $newContestId)
                                .autocapitalization(.allCharacters)
                                .onChange(of: newContestId) { newValue in
                                    newContestId = newValue.uppercased()
                                }

                            Button {
                                let trimmed = newContestId.trimmingCharacters(in: .whitespaces)
                                if ContestManager.allPresetIds.contains(where: { $0.uppercased() == trimmed.uppercased() }) ||
                                   contestManager.customContests.contains(where: { $0.uppercased() == trimmed.uppercased() }) {
                                    alertMessage = "contest_already_exists".localized
                                    showingAlert = true
                                    return
                                }
                                withAnimation {
                                    contestManager.addCustomContest(trimmed)
                                    newContestId = ""
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                            }
                            .buttonStyle(.plain)
                            .disabled(newContestId.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
            }

            // Description
            if searchText.isEmpty {
                Section {
                    Text("contest_settings_desc".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("contest_settings_title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(LocalizedStrings.validationError.localized),
                message: Text(alertMessage)
            )
        }
    }

    // MARK: - Contest Row

    @ViewBuilder
    private func contestRow(id: String, description: String?, isCustom: Bool) -> some View {
        let isHidden = contestManager.isHidden(id)

        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(id)
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
                    withAnimation { contestManager.removeCustomContest(id) }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            Toggle("", isOn: Binding(
                get: { !isHidden },
                set: { contestManager.setHidden(!$0, for: id) }
            ))
            .labelsHidden()
        }
    }
}
