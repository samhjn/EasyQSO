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

struct ADIFDynamicFieldRows: View {
    @Binding var extendedFields: [String: String]
    let category: ADIFFieldCategory
    @ObservedObject var visibilityManager: FieldVisibilityManager
    @FocusState.Binding var focusedField: String?
    
    var body: some View {
        let visible = visibilityManager.visibleFields(for: category)
        
        ForEach(visible) { field in
            TextField(field.displayName, text: bindingFor(field.id))
                .focused($focusedField, equals: field.id)
        }
    }
    
    private func bindingFor(_ fieldId: String) -> Binding<String> {
        Binding(
            get: { extendedFields[fieldId] ?? "" },
            set: { newVal in
                if newVal.isEmpty {
                    extendedFields.removeValue(forKey: fieldId)
                } else {
                    extendedFields[fieldId] = newVal
                }
            }
        )
    }
}

struct ADIFDynamicSection: View {
    @Binding var extendedFields: [String: String]
    let category: ADIFFieldCategory
    @ObservedObject var visibilityManager: FieldVisibilityManager
    @FocusState.Binding var focusedField: String?
    
    var body: some View {
        if visibilityManager.hasVisibleFields(for: category) {
            Section(header: Text(category.displayName)) {
                ADIFDynamicFieldRows(
                    extendedFields: $extendedFields,
                    category: category,
                    visibilityManager: visibilityManager,
                    focusedField: $focusedField
                )
            }
        }
    }
}

struct ADIFCollapsedFieldsSection: View {
    @Binding var extendedFields: [String: String]
    @ObservedObject var visibilityManager: FieldVisibilityManager
    @FocusState.Binding var focusedField: String?
    
    var body: some View {
        let allCollapsed = visibilityManager.allCollapsedFields()
        
        if !allCollapsed.isEmpty {
            Section {
                DisclosureGroup("adif_more_fields".localized) {
                    let grouped = Dictionary(grouping: allCollapsed) { $0.category }
                    let sortedCats = grouped.keys.sorted { $0.sortOrder < $1.sortOrder }
                    
                    ForEach(sortedCats, id: \.self) { category in
                        if let fields = grouped[category] {
                            Text(category.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .listRowSeparator(.hidden)
                            
                            ForEach(fields) { field in
                                TextField(field.displayName, text: bindingFor(field.id))
                                    .focused($focusedField, equals: field.id)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func bindingFor(_ fieldId: String) -> Binding<String> {
        Binding(
            get: { extendedFields[fieldId] ?? "" },
            set: { newVal in
                if newVal.isEmpty {
                    extendedFields.removeValue(forKey: fieldId)
                } else {
                    extendedFields[fieldId] = newVal
                }
            }
        )
    }
}

let dynamicOnlyCategories: [ADIFFieldCategory] = [
    .contest, .qsl, .onlineServices, .awards, .propagation
]

let coreSectionCategories: Set<ADIFFieldCategory> = [
    .basic, .signal, .technical, .ownStation, .contactedStation, .contactedOp, .satellite, .notes
]
