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
    
    var body: some View {
        List {
            Section(header: Text("preset_modes".localized)) {
                ForEach(ModeManager.modeSubmodes, id: \.mode) { entry in
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text(entry.mode)
                                .fontWeight(modeManager.isHidden(entry.mode) ? .regular : .medium)
                                .foregroundColor(modeManager.isHidden(entry.mode) ? .secondary : .primary)
                            if !entry.submodes.isEmpty {
                                Text("(\(entry.submodes.count))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { !modeManager.isHidden(entry.mode) },
                                set: { modeManager.setHidden(!$0, for: entry.mode) }
                            ))
                            .labelsHidden()
                        }
                        if !entry.submodes.isEmpty && !modeManager.isHidden(entry.mode) {
                            Text(entry.submodes.joined(separator: ", "))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            
            Section(header: Text("custom_modes".localized)) {
                ForEach(modeManager.customModes, id: \.self) { mode in
                    HStack {
                        Text(mode)
                            .fontWeight(modeManager.isHidden(mode) ? .regular : .medium)
                            .foregroundColor(modeManager.isHidden(mode) ? .secondary : .primary)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { !modeManager.isHidden(mode) },
                            set: { modeManager.setHidden(!$0, for: mode) }
                        ))
                        .labelsHidden()
                        Button {
                            withAnimation { modeManager.removeCustomMode(mode) }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
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
            
            Section {
                Text("mode_settings_desc".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
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
}
