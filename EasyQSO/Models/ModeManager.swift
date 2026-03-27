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
import Combine

class ModeManager: ObservableObject {
    static let shared = ModeManager()
    
    static let presetModes = ["SSB", "CW", "FM", "AM", "RTTY", "PSK", "FT8", "FT4", "JT65"]
    
    @Published private(set) var revision = 0
    
    private static let customKey = "CustomModes"
    private static let hiddenKey = "HiddenModes"
    
    private init() {}
    
    var customModes: [String] {
        UserDefaults.standard.stringArray(forKey: Self.customKey) ?? []
    }
    
    var hiddenModes: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: Self.hiddenKey) ?? [])
    }
    
    var allKnownModes: [String] {
        Self.presetModes + customModes.filter { !Self.presetModes.contains($0) }
    }
    
    var availableModes: [String] {
        allKnownModes.filter { !hiddenModes.contains($0) }
    }
    
    func pickerModes(current: String) -> [String] {
        var modes = availableModes
        if !current.isEmpty && !modes.contains(current) {
            modes.append(current)
        }
        return modes
    }
    
    func addCustomMode(_ mode: String) {
        let upper = mode.uppercased().trimmingCharacters(in: .whitespaces)
        guard !upper.isEmpty else { return }
        var modes = customModes
        guard !Self.presetModes.contains(upper) && !modes.contains(upper) else { return }
        modes.append(upper)
        UserDefaults.standard.set(modes, forKey: Self.customKey)
        objectWillChange.send()
        revision += 1
    }
    
    func removeCustomMode(_ mode: String) {
        var modes = customModes
        modes.removeAll { $0 == mode }
        UserDefaults.standard.set(modes, forKey: Self.customKey)
        var hidden = hiddenModes
        hidden.remove(mode)
        UserDefaults.standard.set(Array(hidden), forKey: Self.hiddenKey)
        objectWillChange.send()
        revision += 1
    }
    
    func setHidden(_ hidden: Bool, for mode: String) {
        var set = hiddenModes
        if hidden { set.insert(mode) } else { set.remove(mode) }
        UserDefaults.standard.set(Array(set), forKey: Self.hiddenKey)
        objectWillChange.send()
        revision += 1
    }
    
    func isHidden(_ mode: String) -> Bool {
        hiddenModes.contains(mode)
    }
    
    func isCustom(_ mode: String) -> Bool {
        customModes.contains(mode)
    }
}
