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

extension View {
    /// 在 Form/ZStack 底部挂一个自绘的键盘工具栏：顶行为 Previous/Next/Done 导航，
    /// 当焦点落在 `digitRowFieldIDs` 中的字段时追加一行贴着键盘的 0-9 数字按钮。
    /// 使用 `.safeAreaInset(edge: .bottom)` 而非 `.toolbar(.keyboard)`，避开
    /// iOS 26 对键盘工具栏的自动 liquid-glass 胶囊化处理。
    func callsignKeyboardBar(
        focusedField: FocusState<String?>.Binding,
        orderedFields: [String],
        digitRowFieldIDs: Set<String> = ["CALL", "GRIDSQUARE", "MY_GRIDSQUARE"]
    ) -> some View {
        modifier(
            CallsignKeyboardBarModifier(
                focusedField: focusedField,
                orderedFields: orderedFields,
                digitRowFieldIDs: digitRowFieldIDs
            )
        )
    }
}

private struct CallsignKeyboardBarModifier: ViewModifier {
    @FocusState.Binding var focusedField: String?
    let orderedFields: [String]
    let digitRowFieldIDs: Set<String>

    func body(content: Content) -> some View {
        let currentFocus = focusedField
        return content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if currentFocus != nil {
                    KeyboardAccessoryBar(
                        currentFocus: currentFocus,
                        focusedField: $focusedField,
                        orderedFields: orderedFields,
                        digitRowFieldIDs: digitRowFieldIDs
                    )
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: focusedField)
    }
}

private struct KeyboardAccessoryBar: View {
    let currentFocus: String?
    @FocusState.Binding var focusedField: String?
    let orderedFields: [String]
    let digitRowFieldIDs: Set<String>

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 24) {
                Button(LocalizedStrings.previous.localized) {
                    focusPreviousField()
                }
                .disabled(!canFocusPrevious())

                Button(LocalizedStrings.next.localized) {
                    focusNextField()
                }
                .disabled(!canFocusNext())

                Button(LocalizedStrings.done.localized) {
                    dismissKeyboard()
                }
                .font(.system(size: 17, weight: .bold))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 2)
            .padding(.top, 4)

            if shouldShowDigitRow {
                HStack(spacing: 6) {
                    ForEach(0..<10, id: \.self) { digit in
                        Button(action: { insertText("\(digit)") }) {
                            Text("\(digit)")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(.tertiarySystemBackground))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var shouldShowDigitRow: Bool {
        guard let current = currentFocus else { return false }
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
