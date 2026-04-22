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
    let digitRowFieldIDs: Set<String>

    init(
        focusedField: FocusState<String?>.Binding,
        orderedFields: [String],
        digitRowFieldIDs: Set<String> = ["CALL", "GRIDSQUARE", "MY_GRIDSQUARE"]
    ) {
        self._focusedField = focusedField
        self.orderedFields = orderedFields
        self.digitRowFieldIDs = digitRowFieldIDs
    }

    var body: some ToolbarContent {
        ToolbarItem(placement: .keyboard) {
            KeyboardToolbarContent(
                focusedField: $focusedField,
                orderedFields: orderedFields,
                digitRowFieldIDs: digitRowFieldIDs
            )
        }
    }
}

private struct KeyboardToolbarContent: View {
    @FocusState.Binding var focusedField: String?
    let orderedFields: [String]
    let digitRowFieldIDs: Set<String>

    var body: some View {
        VStack(spacing: 6) {
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
            if shouldShowDigitRow {
                HStack(spacing: 4) {
                    ForEach(0..<10, id: \.self) { digit in
                        Button("\(digit)") {
                            insertText("\(digit)")
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, minHeight: 36)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var shouldShowDigitRow: Bool {
        guard let current = focusedField else { return false }
        return digitRowFieldIDs.contains(current)
    }

    private func insertText(_ text: String) {
        guard let responder = UIResponder.currentFirstResponder as? UIKeyInput else { return }
        responder.insertText(text)
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
        let target = orderedFields[idx - 1]
        focusedField = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            focusedField = target
        }
    }

    private func focusNextField() {
        guard let current = focusedField,
              let idx = orderedFields.firstIndex(of: current),
              idx < orderedFields.count - 1 else { return }
        let target = orderedFields[idx + 1]
        focusedField = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            focusedField = target
        }
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

private final class FirstResponderBox {
    static let shared = FirstResponderBox()
    weak var responder: UIResponder?
}

extension UIResponder {
    fileprivate static var currentFirstResponder: UIResponder? {
        FirstResponderBox.shared.responder = nil
        UIApplication.shared.sendAction(
            #selector(UIResponder._keyboardToolbarFindFirstResponder(_:)),
            to: nil, from: nil, for: nil
        )
        return FirstResponderBox.shared.responder
    }

    @objc fileprivate func _keyboardToolbarFindFirstResponder(_ sender: Any) {
        FirstResponderBox.shared.responder = self
    }
}
