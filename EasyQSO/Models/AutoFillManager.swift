/*
 * EasyQSO - 业余无线电通联日志
 * Copyright (C) 2025 ShadowMov
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import Foundation

class AutoFillManager: ObservableObject {
    static let shared = AutoFillManager()

    private let defaults = UserDefaults.standard
    private let freqModeKey = "autoFillFrequencyAndMode"
    private let ownQTHKey = "autoFillOwnQTH"
    private let dxccKey = "autoFillDXCC"

    @Published var autoFillFrequencyAndMode: Bool {
        didSet { defaults.set(autoFillFrequencyAndMode, forKey: freqModeKey) }
    }

    @Published var autoFillOwnQTH: Bool {
        didSet { defaults.set(autoFillOwnQTH, forKey: ownQTHKey) }
    }

    @Published var autoFillDXCC: Bool {
        didSet { defaults.set(autoFillDXCC, forKey: dxccKey) }
    }

    private init() {
        if defaults.object(forKey: freqModeKey) == nil {
            defaults.set(true, forKey: freqModeKey)
        }
        if defaults.object(forKey: ownQTHKey) == nil {
            defaults.set(true, forKey: ownQTHKey)
        }
        if defaults.object(forKey: dxccKey) == nil {
            defaults.set(true, forKey: dxccKey)
        }
        autoFillFrequencyAndMode = defaults.bool(forKey: freqModeKey)
        autoFillOwnQTH = defaults.bool(forKey: ownQTHKey)
        autoFillDXCC = defaults.bool(forKey: dxccKey)
    }

    #if DEBUG
    static func createForTesting(freqMode: Bool = true, ownQTH: Bool = true, dxcc: Bool = true) -> AutoFillManager {
        let manager = AutoFillManager()
        manager.autoFillFrequencyAndMode = freqMode
        manager.autoFillOwnQTH = ownQTH
        manager.autoFillDXCC = dxcc
        return manager
    }
    #endif
}
