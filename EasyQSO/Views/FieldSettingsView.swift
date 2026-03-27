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

struct FieldSettingsView: View {
    @ObservedObject private var visibilityManager = FieldVisibilityManager.shared
    @State private var searchText = ""
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                summarySection
                searchSection
                
                ForEach(ADIFFields.sortedCategories, id: \.self) { category in
                    let items = settingsItemsForCategory(category)
                    if !items.isEmpty {
                        Section(header: Text(category.displayName)) {
                            ForEach(items) { item in
                                switch item {
                                case .group(let group):
                                    GroupVisibilityRow(
                                        group: group,
                                        visibility: visibilityManager.groupVisibility(for: group.id),
                                        onChange: { newVisibility in
                                            visibilityManager.setGroupVisibility(newVisibility, for: group.id)
                                        }
                                    )
                                case .field(let field):
                                    FieldVisibilityRow(
                                        field: field,
                                        visibility: visibilityManager.visibility(for: field.id),
                                        onChange: { newVisibility in
                                            visibilityManager.setVisibility(newVisibility, for: field.id)
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("adif_field_settings".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("adif_reset_defaults".localized) {
                        visibilityManager.resetToDefaults()
                    }
                    .foregroundColor(.red)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizedStrings.done.localized) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private var summarySection: some View {
        let stats = computeStats()
        return Section {
            HStack {
                Label("\(stats.visible)", systemImage: "eye")
                    .foregroundColor(.green)
                Spacer()
                Label("\(stats.collapsed)", systemImage: "eye.trianglebadge.exclamationmark")
                    .foregroundColor(.orange)
                Spacer()
                Label("\(stats.hidden)", systemImage: "eye.slash")
                    .foregroundColor(.secondary)
            }
            .font(.caption)
        }
        .id(visibilityManager.revision)
    }
    
    private var searchSection: some View {
        Section {
            TextField("adif_search_fields".localized, text: $searchText)
                .disableAutocorrection(true)
        }
    }
    
    // MARK: - Filtering
    
    private func settingsItemsForCategory(_ category: ADIFFieldCategory) -> [ADIFFields.SettingsItem] {
        let items = ADIFFields.orderedSettingsItems(for: category)
        if searchText.isEmpty { return items }
        let search = searchText.lowercased()
        return items.filter { item in
            switch item {
            case .group(let group):
                return group.displayName.lowercased().contains(search) ||
                       group.memberFieldIds.contains { $0.lowercased().contains(search) }
            case .field(let field):
                return field.id.lowercased().contains(search) ||
                       field.displayName.lowercased().contains(search)
            }
        }
    }
    
    private func computeStats() -> (visible: Int, collapsed: Int, hidden: Int) {
        var v = 0, c = 0, h = 0
        for field in ADIFFields.all {
            switch visibilityManager.visibility(for: field.id) {
            case .visible: v += 1
            case .collapsed: c += 1
            case .hidden: h += 1
            }
        }
        return (v, c, h)
    }
}

// MARK: - Row for individual field

struct FieldVisibilityRow: View {
    let field: ADIFFieldDef
    let visibility: ADIFFieldVisibility
    let onChange: (ADIFFieldVisibility) -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(field.displayName)
                        .font(.body)
                    if field.isRequired {
                        Text("adif_required".localized)
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(3)
                    }
                }
                Text(field.id)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if field.isRequired {
                Image(systemName: "eye")
                    .foregroundColor(.green)
            } else {
                visibilityMenu(
                    current: visibility,
                    options: ADIFFieldVisibility.allCases,
                    onChange: onChange
                )
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Row for field group

struct GroupVisibilityRow: View {
    let group: ADIFFieldGroup
    let visibility: ADIFFieldVisibility
    let onChange: (ADIFFieldVisibility) -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "rectangle.3.group")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    Text(group.displayName)
                        .font(.body)
                }
                Text(group.memberFieldIds.joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if group.allowedVisibilities.count <= 1 {
                Image(systemName: "eye")
                    .foregroundColor(.green)
            } else {
                visibilityMenu(
                    current: visibility,
                    options: group.allowedVisibilities,
                    onChange: onChange
                )
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Shared visibility menu

private func visibilityMenu(
    current: ADIFFieldVisibility,
    options: [ADIFFieldVisibility],
    onChange: @escaping (ADIFFieldVisibility) -> Void
) -> some View {
    Menu {
        ForEach(options, id: \.self) { vis in
            Button {
                onChange(vis)
            } label: {
                Label(vis.displayName, systemImage: vis.iconName)
            }
        }
    } label: {
        HStack(spacing: 4) {
            Image(systemName: current.iconName)
            Text(current.displayName)
                .font(.caption)
        }
        .foregroundColor(colorForVisibility(current))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(colorForVisibility(current).opacity(0.1))
        .cornerRadius(6)
    }
}

private func colorForVisibility(_ vis: ADIFFieldVisibility) -> Color {
    switch vis {
    case .visible: return .green
    case .collapsed: return .orange
    case .hidden: return .secondary
    }
}
