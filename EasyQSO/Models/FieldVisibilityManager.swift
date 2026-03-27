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

class FieldVisibilityManager: ObservableObject {
    static let shared = FieldVisibilityManager()
    
    private static let fieldKey = "ADIFFieldVisibility"
    private static let groupKey = "ADIFGroupVisibility"
    
    @Published private(set) var visibilityMap: [String: ADIFFieldVisibility] = [:]
    @Published private(set) var groupVisibilityMap: [String: ADIFFieldVisibility] = [:]
    
    /// Increments on persisted changes; supports views that need explicit invalidation.
    @Published private(set) var revision: Int = 0
    
    private init() {
        loadSettings()
    }
    
    // MARK: - Individual Field API
    
    func visibility(for fieldId: String) -> ADIFFieldVisibility {
        if let group = ADIFFields.group(for: fieldId) {
            return groupVisibility(for: group.id)
        }
        if let field = ADIFFields.field(for: fieldId), field.isRequired {
            return .visible
        }
        return visibilityMap[fieldId] ?? defaultVisibility(for: fieldId)
    }
    
    func setVisibility(_ visibility: ADIFFieldVisibility, for fieldId: String) {
        if let field = ADIFFields.field(for: fieldId), field.isRequired { return }
        if ADIFFields.groupedFieldIds.contains(fieldId) { return }
        objectWillChange.send()
        visibilityMap[fieldId] = visibility
        saveSettings()
    }
    
    // MARK: - Group API
    
    func groupVisibility(for groupId: String) -> ADIFFieldVisibility {
        guard let group = ADIFFields.fieldGroups.first(where: { $0.id == groupId }) else {
            return .visible
        }
        let defaultVis: ADIFFieldVisibility = group.defaultVisible ? .visible : .hidden
        let stored = groupVisibilityMap[groupId] ?? defaultVis
        if group.allowedVisibilities.contains(stored) {
            return stored
        }
        return defaultVis
    }
    
    func setGroupVisibility(_ visibility: ADIFFieldVisibility, for groupId: String) {
        guard let group = ADIFFields.fieldGroups.first(where: { $0.id == groupId }) else { return }
        guard group.allowedVisibilities.contains(visibility) else { return }
        objectWillChange.send()
        groupVisibilityMap[groupId] = visibility
        saveSettings()
    }
    
    // MARK: - Query helpers
    
    func visibleFields(for category: ADIFFieldCategory) -> [ADIFFieldDef] {
        ADIFFields.fieldsForCategory(category).filter { field in
            !ADIFFields.groupedFieldIds.contains(field.id) &&
            field.coreProperty == nil &&
            visibility(for: field.id) == .visible
        }
    }
    
    func collapsedFields(for category: ADIFFieldCategory) -> [ADIFFieldDef] {
        ADIFFields.fieldsForCategory(category).filter { field in
            !ADIFFields.groupedFieldIds.contains(field.id) &&
            field.coreProperty == nil &&
            visibility(for: field.id) == .collapsed
        }
    }
    
    /// Only returns individual (non-grouped, non-core) collapsed fields.
    /// Groups that are collapsed are handled in-place with DisclosureGroup.
    func allCollapsedFields() -> [ADIFFieldDef] {
        ADIFFields.all.filter { field in
            !ADIFFields.groupedFieldIds.contains(field.id) &&
            field.coreProperty == nil &&
            visibility(for: field.id) == .collapsed
        }
    }
    
    func hasVisibleFields(for category: ADIFFieldCategory) -> Bool {
        ADIFFields.fieldsForCategory(category).contains { field in
            !ADIFFields.groupedFieldIds.contains(field.id) &&
            field.coreProperty == nil &&
            visibility(for: field.id) == .visible
        }
    }
    
    func isCoreFieldVisible(for fieldId: String) -> Bool {
        visibility(for: fieldId) != .hidden
    }
    
    func resetToDefaults() {
        objectWillChange.send()
        visibilityMap = [:]
        groupVisibilityMap = [:]
        saveSettings()
    }
    
    // MARK: - Private
    
    private func defaultVisibility(for fieldId: String) -> ADIFFieldVisibility {
        if let field = ADIFFields.field(for: fieldId) {
            return field.defaultVisible ? .visible : .hidden
        }
        return .hidden
    }
    
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: Self.fieldKey),
           let map = try? JSONDecoder().decode([String: ADIFFieldVisibility].self, from: data) {
            visibilityMap = map
        }
        if let data = UserDefaults.standard.data(forKey: Self.groupKey),
           let map = try? JSONDecoder().decode([String: ADIFFieldVisibility].self, from: data) {
            groupVisibilityMap = map
        }
    }
    
    private func saveSettings() {
        revision += 1
        if let data = try? JSONEncoder().encode(visibilityMap) {
            UserDefaults.standard.set(data, forKey: Self.fieldKey)
        }
        if let data = try? JSONEncoder().encode(groupVisibilityMap) {
            UserDefaults.standard.set(data, forKey: Self.groupKey)
        }
    }
}
