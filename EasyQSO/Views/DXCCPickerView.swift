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

/// A searchable DXCC entity picker that allows selection by name, prefix or code.
struct DXCCPickerView: View {
    @Binding var selectedCode: String
    @ObservedObject private var dxccManager = DXCCManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText = ""

    private var filteredEntities: [DXCCEntity] {
        dxccManager.searchEntities(searchText)
    }

    var body: some View {
        NavigationView {
            Group {
                if !dxccManager.isDataAvailable {
                    VStack(spacing: 16) {
                        Image(systemName: "globe")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("dxcc_no_data".localized)
                            .font(.headline)
                        Text("dxcc_no_data_hint".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        // Clear selection option
                        Button(action: {
                            selectedCode = ""
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                Text("dxcc_clear_selection".localized)
                                    .foregroundColor(.secondary)
                                Spacer()
                                if selectedCode.isEmpty {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }

                        ForEach(filteredEntities) { entity in
                            Button(action: {
                                selectedCode = String(entity.code)
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entity.name)
                                            .foregroundColor(.primary)
                                        HStack(spacing: 8) {
                                            Text(entity.primaryPrefix)
                                                .font(.caption)
                                                .foregroundColor(.accentColor)
                                            Text("#\(entity.code)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text(entity.continent)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if selectedCode == String(entity.code) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                        }
                    }
                    .searchableCompat(text: $searchText, prompt: "dxcc_search_prompt".localized)
                }
            }
            .navigationTitle("dxcc_picker_title".localized)
            .navigationBarItems(trailing: Button(LocalizedStrings.cancel.localized) {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// MARK: - iOS 15+ searchable compatibility

extension View {
    @ViewBuilder
    func searchableCompat(text: Binding<String>, prompt: String) -> some View {
        if #available(iOS 15.0, *) {
            self.searchable(text: text, prompt: prompt)
        } else {
            VStack(spacing: 0) {
                TextField(prompt, text: text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                self
            }
        }
    }
}

/// Inline DXCC display row for use in QSO forms.
/// Shows entity name and allows tapping to pick a different entity.
struct DXCCFieldRow: View {
    @Binding var dxccCode: String
    @ObservedObject private var dxccManager = DXCCManager.shared
    @State private var showingPicker = false

    let label: String
    var isAutoFilled: Bool = false

    var body: some View {
        Button(action: { showingPicker = true }) {
            HStack {
                HStack(spacing: 4) {
                    Text(label)
                        .foregroundColor(.primary)
                    if isAutoFilled {
                        Text("autofill_badge".localized)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.8))
                            .cornerRadius(3)
                    }
                }
                Spacer()
                if dxccCode.isEmpty {
                    Text("dxcc_not_set".localized)
                        .foregroundColor(.secondary)
                } else if let entity = dxccManager.entity(forCodeString: dxccCode) {
                    Text(entity.displayName)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else if dxccManager.isDataAvailable {
                    // Data loaded but code is invalid
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text(dxccCode)
                            .foregroundColor(.orange)
                    }
                } else {
                    Text("#\(dxccCode)")
                        .foregroundColor(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingPicker) {
            DXCCPickerView(selectedCode: $dxccCode)
        }
    }
}
