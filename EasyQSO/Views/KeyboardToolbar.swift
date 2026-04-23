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
        digitRowFieldIDs: Set<String> = [
            "CALL", "STATION_CALLSIGN", "OPERATOR", "CONTACTED_OP", "EQ_CALL",
            "GRIDSQUARE", "MY_GRIDSQUARE", "VUCC_GRIDS", "MY_VUCC_GRIDS",
            "RST_SENT", "RST_RCVD"
        ],
        skipFieldIDs: Set<String> = ["SAT_NAME", "DXCC", "MY_DXCC", "CONTEST_ID"]
    ) -> some View {
        modifier(
            CallsignKeyboardBarModifier(
                focusedField: focusedField,
                orderedFields: orderedFields,
                digitRowFieldIDs: digitRowFieldIDs,
                skipFieldIDs: skipFieldIDs
            )
        )
    }
}

private struct CallsignKeyboardBarModifier: ViewModifier {
    @FocusState.Binding var focusedField: String?
    let orderedFields: [String]
    let digitRowFieldIDs: Set<String>
    let skipFieldIDs: Set<String>

    func body(content: Content) -> some View {
        let currentFocus = focusedField
        return content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if currentFocus != nil {
                    KeyboardAccessoryBar(
                        currentFocus: currentFocus,
                        focusedField: $focusedField,
                        orderedFields: orderedFields,
                        digitRowFieldIDs: digitRowFieldIDs,
                        skipFieldIDs: skipFieldIDs
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
    let skipFieldIDs: Set<String>

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
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground).opacity(0.95))
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
        guard let target = neighborFieldID(direction: -1) else { return }
        focusedField = target
    }

    private func focusNextField() {
        guard let target = neighborFieldID(direction: 1) else { return }
        focusedField = target
    }

    private func canFocusPrevious() -> Bool {
        neighborFieldID(direction: -1) != nil
    }

    private func canFocusNext() -> Bool {
        neighborFieldID(direction: 1) != nil
    }

    /// Walk `orderedFields` from the current focus toward `direction` and return
    /// the first field that isn't in `skipFieldIDs`. Pickers / date rows / non-
    /// text rows registered in the ordered list are transparently jumped over
    /// so Previous/Next only lands on places where the keyboard is useful.
    private func neighborFieldID(direction: Int) -> String? {
        guard let current = focusedField,
              let currentIdx = orderedFields.firstIndex(of: current) else { return nil }
        var idx = currentIdx + direction
        while idx >= 0 && idx < orderedFields.count {
            let candidate = orderedFields[idx]
            if !skipFieldIDs.contains(candidate) {
                return candidate
            }
            idx += direction
        }
        return nil
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
