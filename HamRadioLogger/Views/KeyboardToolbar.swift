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

/// 键盘工具栏组件
struct KeyboardToolbar<Field: Hashable & CaseIterable & RawRepresentable>: ToolbarContent where Field.RawValue == Int {
    @FocusState.Binding var focusedField: Field?
    let fields: [Field]
    
    init(focusedField: FocusState<Field?>.Binding) {
        self._focusedField = focusedField
        self.fields = Array(Field.allCases)
    }
    
    var body: some ToolbarContent {
        ToolbarItem(placement: .keyboard) {
            HStack {
                // 上一项按钮
                Button(LocalizedStrings.previous.localized) {
                    focusPreviousField()
                }
                .disabled(!canFocusPrevious())
                
                Spacer()
                
                // 下一项按钮
                Button(LocalizedStrings.next.localized) {
                    focusNextField()
                }
                .disabled(!canFocusNext())
                
                Spacer()
                
                // 完成按钮
                Button(LocalizedStrings.done.localized) {
                    focusedField = nil
                }
                .font(.system(size: 17, weight: .bold))
            }
        }
    }
    
    private func focusPreviousField() {
        guard let currentField = focusedField,
              let currentIndex = fields.firstIndex(of: currentField),
              currentIndex > 0 else { return }
        
        focusedField = fields[currentIndex - 1]
    }
    
    private func focusNextField() {
        guard let currentField = focusedField,
              let currentIndex = fields.firstIndex(of: currentField),
              currentIndex < fields.count - 1 else { return }
        
        focusedField = fields[currentIndex + 1]
    }
    
    private func canFocusPrevious() -> Bool {
        guard let currentField = focusedField,
              let currentIndex = fields.firstIndex(of: currentField) else { return false }
        return currentIndex > 0
    }
    
    private func canFocusNext() -> Bool {
        guard let currentField = focusedField,
              let currentIndex = fields.firstIndex(of: currentField) else { return false }
        return currentIndex < fields.count - 1
    }
}

/// 表单字段枚举
enum FormField: Int, CaseIterable {
    case callsign = 0
    case frequency = 1
    case rstSent = 2
    case rstReceived = 3
    case rxFrequency = 4
    case txPower = 5
    case satellite = 6
    case ownQTH = 7
    case ownGridSquare = 8
    case ownCQZone = 9
    case ownITUZone = 10
    case qth = 11
    case gridSquare = 12
    case cqZone = 13
    case ituZone = 14
    case name = 15
    case remarks = 16
} 