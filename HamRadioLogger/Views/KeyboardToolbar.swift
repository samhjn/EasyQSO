/*
 * EasyQSO - 业余无线电通联日志
 * Copyright (C) 2025 ShadowMov
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import SwiftUI
import UIKit

struct KeyboardToolbar: ToolbarContent {
    @FocusState.Binding var focusedField: String?
    let orderedFields: [String]
    
    init(focusedField: FocusState<String?>.Binding, orderedFields: [String]) {
        self._focusedField = focusedField
        self.orderedFields = orderedFields
    }
    
    var body: some ToolbarContent {
        ToolbarItem(placement: .keyboard) {
            HStack {
                Button(LocalizedStrings.previous.localized) {
                    focusPreviousField()
                }
                .disabled(!canFocusPrevious())
                
                Spacer()
                
                Button(LocalizedStrings.next.localized) {
                    focusNextField()
                }
                .disabled(!canFocusNext())
                
                Spacer()
                
                Button(LocalizedStrings.done.localized) {
                    dismissKeyboard()
                }
                .font(.system(size: 17, weight: .bold))
            }
        }
    }
    
    private func dismissKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
    }
    
    private func focusPreviousField() {
        guard let current = focusedField,
              let idx = orderedFields.firstIndex(of: current),
              idx > 0 else { return }
        focusedField = orderedFields[idx - 1]
    }
    
    private func focusNextField() {
        guard let current = focusedField,
              let idx = orderedFields.firstIndex(of: current),
              idx < orderedFields.count - 1 else { return }
        focusedField = orderedFields[idx + 1]
    }
    
    private func canFocusPrevious() -> Bool {
        guard let current = focusedField,
              let idx = orderedFields.firstIndex(of: current) else { return false }
        return idx > 0
    }
    
    private func canFocusNext() -> Bool {
        guard let current = focusedField,
              let idx = orderedFields.firstIndex(of: current) else { return false }
        return idx < orderedFields.count - 1
    }
}
