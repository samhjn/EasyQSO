/*
 * EasyQSO - 业余无线电通联日志
 * Copyright (C) 2026 ShadowMov
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import SwiftUI

/// Shared TX/RX selector for both new and existing QSOs.
struct BandPickerView: View {
    let title: String
    @Binding var selection: String
    var allowsEmpty = false
    var isAutoFilled = false
    @ObservedObject private var bandManager = BandManager.shared

    var body: some View {
        Menu {
            if allowsEmpty {
                bandButton("", label: "band_not_set".localized)
            }

            // Keep imported nonstandard values visible without changing the record.
            if PickerOrphanDetector.isOrphan(value: selection, knownItems: BandManager.allBands) {
                Section(header: Text("picker_current_selection_header".localized)) {
                    bandButton(selection)
                }
            }

            ForEach(bandManager.commonBands, id: \.self) { band in
                bandButton(band)
            }

            if !bandManager.otherBands.isEmpty {
                Menu("other_bands".localized) {
                    ForEach(bandManager.otherBands, id: \.self) { band in
                        bandButton(band)
                    }
                }
            }
        } label: {
            HStack {
                AutoFillPickerLabel(title: title, isAutoFilled: isAutoFilled)
                    .foregroundColor(.primary)
                Spacer()
                Text(selection.isEmpty ? "band_not_set".localized : selection)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
            }
            .contentShape(Rectangle())
        }
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(selection.isEmpty ? "band_not_set".localized : selection))
    }

    private func bandButton(_ band: String, label: String? = nil) -> some View {
        Button {
            selection = band
        } label: {
            if selection.lowercased() == band.lowercased() {
                Label(label ?? band, systemImage: "checkmark")
            } else {
                Text(label ?? band)
            }
        }
    }
}
