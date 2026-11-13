/*
 * EasyQSO - 业余无线电通联日志
 * Copyright (C) 2026 ShadowMov
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import SwiftUI

struct BandSettingsView: View {
    @ObservedObject private var bandManager = BandManager.shared

    var body: some View {
        List {
            Section(footer: Text("band_settings_desc".localized)) {
                ForEach(BandManager.allBands, id: \.self) { band in
                    Toggle(band, isOn: Binding(
                        get: { bandManager.isCommon(band) },
                        set: { bandManager.setCommon($0, for: band) }
                    ))
                }
            }

            Section {
                Button("band_reset_defaults".localized) {
                    bandManager.resetCommonBands()
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("common_bands".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}
