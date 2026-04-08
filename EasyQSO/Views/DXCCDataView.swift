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

/// Settings page for managing DXCC prefix data (download, status, etc.)
struct DXCCDataView: View {
    @ObservedObject private var dxccManager = DXCCManager.shared
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    var body: some View {
        Form {
            Section {
                Button(action: {
                    Task {
                        do {
                            try await dxccManager.downloadAndParse()
                            alertTitle = "dxcc_import_success_title".localized
                            alertMessage = String(format: "dxcc_import_success_message".localized, dxccManager.entities.count)
                            showingAlert = true
                        } catch {
                            alertTitle = "dxcc_import_failed_title".localized
                            alertMessage = dxccManager.lastError ?? error.localizedDescription
                            showingAlert = true
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                        if dxccManager.isLoading {
                            ProgressView()
                                .padding(.leading, 4)
                            Text("dxcc_downloading".localized)
                                .foregroundColor(.secondary)
                        } else {
                            Text("dxcc_import_button".localized)
                        }
                        Spacer()
                    }
                }
                .disabled(dxccManager.isLoading)

                Text("dxcc_section_desc".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                HStack {
                    Text("dxcc_entities_count".localized)
                    Spacer()
                    Text(dxccManager.isDataAvailable ? "\(dxccManager.entities.count)" : "-")
                        .foregroundColor(.secondary)
                }

                if let date = dxccManager.lastUpdateDate {
                    HStack {
                        Text("dxcc_last_update".localized)
                        Spacer()
                        Text(date, style: .date)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("dxcc_data_title".localized)
        .alert(isPresented: $showingAlert) {
            Alert(title: Text(alertTitle), message: Text(alertMessage))
        }
    }
}
