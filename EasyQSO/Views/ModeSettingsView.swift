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

struct ModeSettingsView: View {
    @ObservedObject private var modeManager = ModeManager.shared
    @State private var newModeName = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var newSubmodeName: [String: String] = [:]
    @State private var searchText = ""

    /// Check if a mode or any of its submodes match the search text
    private func modeMatchesSearch(_ mode: String, submodes: [String]) -> Bool {
        if searchText.isEmpty { return true }
        let query = searchText.uppercased()
        if mode.uppercased().localizedCaseInsensitiveContains(query) { return true }
        let customSubs = modeManager.customSubmodesForMode(mode)
        let allSubs = submodes + customSubs.filter { sub in !submodes.contains(where: { $0.uppercased() == sub.uppercased() }) }
        return allSubs.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    /// Filter preset submodes that match the search text (returns all if search is empty or mode itself matches)
    private func filteredSubmodes(_ submodes: [String], for mode: String) -> [String] {
        if searchText.isEmpty { return submodes }
        if mode.localizedCaseInsensitiveContains(searchText) { return submodes }
        return submodes.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredPresetModes: [(mode: String, submodes: [String])] {
        if searchText.isEmpty { return ModeManager.modeSubmodes }
        return ModeManager.modeSubmodes.filter { modeMatchesSearch($0.mode, submodes: $0.submodes) }
    }

    private var filteredCustomModes: [String] {
        if searchText.isEmpty { return modeManager.customModes }
        return modeManager.customModes.filter { modeMatchesSearch($0, submodes: []) }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("mode_search_placeholder".localized, text: $searchText)
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

            if !filteredPresetModes.isEmpty {
                Section(header: Text("preset_modes".localized)) {
                    ForEach(filteredPresetModes, id: \.mode) { entry in
                        modeRow(mode: entry.mode, presetSubmodes: filteredSubmodes(entry.submodes, for: entry.mode), isCustomMode: false)
                    }
                }
            }

            if searchText.isEmpty || !filteredCustomModes.isEmpty {
                Section(header: Text("custom_modes".localized)) {
                    ForEach(filteredCustomModes, id: \.self) { mode in
                        modeRow(mode: mode, presetSubmodes: [], isCustomMode: true)
                    }

                    if searchText.isEmpty {
                        HStack {
                            TextField("new_mode_placeholder".localized, text: $newModeName)
                                .autocapitalization(.allCharacters)
                                .onChange(of: newModeName) { newValue in
                                    newModeName = newValue.uppercased()
                                }

                            Button {
                                let trimmed = newModeName.trimmingCharacters(in: .whitespaces)
                                if ModeManager.allAdifModes.contains(where: { $0.uppercased() == trimmed.uppercased() }) ||
                                   modeManager.customModes.contains(trimmed) {
                                    alertMessage = "mode_already_exists".localized
                                    showingAlert = true
                                    return
                                }
                                withAnimation {
                                    modeManager.addCustomMode(trimmed)
                                    newModeName = ""
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                            }
                            .buttonStyle(.plain)
                            .disabled(newModeName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
            }

            if searchText.isEmpty {
                Section {
                    Text("mode_settings_desc".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("mode_settings_title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(LocalizedStrings.validationError.localized),
                message: Text(alertMessage)
            )
        }
    }
    
    // MARK: - Mode Row with expandable submodes
    
    @ViewBuilder
    private func modeRow(mode: String, presetSubmodes: [String], isCustomMode: Bool) -> some View {
        let isHidden = modeManager.isHidden(mode)
        let allSubs = modeManager.allSubmodes(for: mode)
        let customSubs = modeManager.customSubmodesForMode(mode)
        let hasSubmodes = !allSubs.isEmpty
        
        if !hasSubmodes && !isCustomMode {
            HStack {
                Text(mode)
                    .fontWeight(isHidden ? .regular : .medium)
                    .foregroundColor(isHidden ? .secondary : .primary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { !isHidden },
                    set: { modeManager.setHidden(!$0, for: mode) }
                ))
                .labelsHidden()
            }
        } else {
            DisclosureGroup {
                ForEach(presetSubmodes, id: \.self) { sub in
                    submodeRow(sub, parentMode: mode, isCustom: false, isParentHidden: isHidden)
                }
                
                if !customSubs.isEmpty {
                    ForEach(customSubs, id: \.self) { sub in
                        submodeRow(sub, parentMode: mode, isCustom: true, isParentHidden: isHidden)
                    }
                }
                
                addSubmodeRow(parentMode: mode)
            } label: {
                HStack {
                    Text(mode)
                        .fontWeight(isHidden ? .regular : .medium)
                        .foregroundColor(isHidden ? .secondary : .primary)
                    if hasSubmodes {
                        let visibleCount = allSubs.filter { !modeManager.isSubmodeHidden($0) }.count
                        Text("\(visibleCount)/\(allSubs.count)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if isCustomMode {
                        Button {
                            withAnimation { modeManager.removeCustomMode(mode) }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    Toggle("", isOn: Binding(
                        get: { !isHidden },
                        set: { modeManager.setHidden(!$0, for: mode) }
                    ))
                    .labelsHidden()
                }
            }
        }
    }
    
    @ViewBuilder
    private func submodeRow(_ sub: String, parentMode: String, isCustom: Bool, isParentHidden: Bool) -> some View {
        HStack {
            Text(sub)
                .font(.subheadline)
                .foregroundColor(
                    isParentHidden || modeManager.isSubmodeHidden(sub) ? .secondary : .primary
                )
            if isCustom {
                Text("custom_tag".localized)
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .cornerRadius(3)
            }
            Spacer()
            if isCustom {
                Button {
                    withAnimation { modeManager.removeCustomSubmode(sub, from: parentMode) }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
            }
            Toggle("", isOn: Binding(
                get: { !modeManager.isSubmodeHidden(sub) },
                set: { modeManager.setSubmodeHidden(!$0, for: sub) }
            ))
            .labelsHidden()
            .disabled(isParentHidden)
        }
    }
    
    @ViewBuilder
    private func addSubmodeRow(parentMode: String) -> some View {
        let binding = Binding<String>(
            get: { newSubmodeName[parentMode] ?? "" },
            set: { newSubmodeName[parentMode] = $0.uppercased() }
        )
        HStack {
            TextField("new_submode_placeholder".localized, text: binding)
                .font(.subheadline)
                .autocapitalization(.allCharacters)
            
            Button {
                let trimmed = (newSubmodeName[parentMode] ?? "").trimmingCharacters(in: .whitespaces)
                let allSubs = modeManager.allSubmodes(for: parentMode)
                if allSubs.contains(where: { $0.uppercased() == trimmed.uppercased() }) {
                    alertMessage = "submode_already_exists".localized
                    showingAlert = true
                    return
                }
                if ModeManager.presetSubmodeToMode[trimmed.uppercased()] != nil {
                    alertMessage = "submode_exists_under_other".localized
                    showingAlert = true
                    return
                }
                withAnimation {
                    modeManager.addCustomSubmode(trimmed, to: parentMode)
                    newSubmodeName[parentMode] = ""
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.green)
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
            .disabled((newSubmodeName[parentMode] ?? "").trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}
