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

/// 当数据库模型不兼容时显示的错误视图
///
/// 该视图替代主界面展示，引导用户了解错误原因并采取正确措施。
/// 不会自动删除数据，确保用户数据安全。
struct StoreIncompatibleView: View {
    let storeState: StoreLoadState
    @State private var showCopiedToast = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 40)

                Image(systemName: iconName)
                    .font(.system(size: 56))
                    .foregroundColor(.orange)

                Text(storeState.title)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(storeState.localizedDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if case .incompatibleSchema(let url) = storeState {
                    storePathSection(url: url)
                }

                safetyNotice

                Spacer()
            }
            .padding()
        }
    }

    private var iconName: String {
        switch storeState {
        case .incompatibleSchema:
            return "exclamationmark.triangle.fill"
        case .storeFileError:
            return "xmark.circle.fill"
        case .loadFailed:
            return "exclamationmark.circle.fill"
        case .ready:
            return "checkmark.circle.fill"
        }
    }

    private func storePathSection(url: URL) -> some View {
        VStack(spacing: 12) {
            Button {
                UIPasteboard.general.string = url.path
                showCopiedToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showCopiedToast = false
                }
            } label: {
                Label(
                    showCopiedToast ? "已复制" : "复制数据库路径",
                    systemImage: showCopiedToast ? "checkmark" : "doc.on.doc"
                )
            }
            .buttonStyle(.bordered)
            .tint(showCopiedToast ? .green : .accentColor)
        }
    }

    private var safetyNotice: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield")
                .foregroundColor(.green)
            Text("您的数据仍安全保存在数据库文件中，不会被删除。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 32)
    }
}
