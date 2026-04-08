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

// MARK: - Floating Label Modifier

struct FloatingLabelModifier: ViewModifier {
    let label: String
    let text: String
    
    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if !text.isEmpty {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.accentColor)
            }
            content
        }
        .animation(.easeInOut(duration: 0.15), value: text.isEmpty)
    }
}

extension View {
    func floatingLabel(_ label: String, text: String) -> some View {
        modifier(FloatingLabelModifier(label: label, text: text))
    }

    /// Floating label with an optional "auto" badge when the field was autofilled.
    func autoFillLabel(_ label: String, text: String, isAutoFilled: Bool) -> some View {
        modifier(AutoFillLabelModifier(label: label, text: text, isAutoFilled: isAutoFilled))
    }
}

// MARK: - AutoFill Label Modifier

struct AutoFillLabelModifier: ViewModifier {
    let label: String
    let text: String
    let isAutoFilled: Bool

    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if !text.isEmpty {
                HStack(spacing: 4) {
                    Text(label)
                        .font(.caption2)
                        .foregroundColor(isAutoFilled ? .orange : .accentColor)
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
            }
            content
        }
        .animation(.easeInOut(duration: 0.15), value: text.isEmpty)
        .animation(.easeInOut(duration: 0.15), value: isAutoFilled)
    }
}

struct ADIFDynamicFieldRows: View {
    @Binding var extendedFields: [String: String]
    let category: ADIFFieldCategory
    @ObservedObject var visibilityManager: FieldVisibilityManager
    @FocusState.Binding var focusedField: String?
    var excludeFieldIds: Set<String> = []
    
    var body: some View {
        let visible = visibilityManager.visibleFields(for: category).filter {
            !excludeFieldIds.contains($0.id)
        }
        
        ForEach(visible) { field in
            TextField(field.displayName, text: bindingFor(field.id))
                .focused($focusedField, equals: field.id)
                .floatingLabel(field.displayName, text: extendedFields[field.id] ?? "")
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
    var excludeFieldIds: Set<String> = []
    
    var body: some View {
        let visible = visibilityManager.visibleFields(for: category).filter {
            !excludeFieldIds.contains($0.id)
        }
        if !visible.isEmpty {
            Section(header: Text(category.displayName)) {
                ADIFDynamicFieldRows(
                    extendedFields: $extendedFields,
                    category: category,
                    visibilityManager: visibilityManager,
                    focusedField: $focusedField,
                    excludeFieldIds: excludeFieldIds
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
                                    .floatingLabel(field.displayName, text: extendedFields[field.id] ?? "")
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
