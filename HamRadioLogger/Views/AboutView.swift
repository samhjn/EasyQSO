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

struct AboutView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 应用图标和名称
                    VStack(spacing: 16) {
                        Image("logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .cornerRadius(16)
                        
                        Text("EasyQSO")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(LocalizedStrings.softwareIntroduction.localized)
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("\(LocalizedStrings.version.localized) 1.0.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // 软件描述
                    VStack(alignment: .leading, spacing: 12) {
                        Text(LocalizedStrings.softwareIntroduction.localized)
                            .font(.headline)
                        
                        Text(LocalizedStrings.softwareDescription.localized)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // 许可证信息
                    VStack(alignment: .leading, spacing: 12) {
                        Text(LocalizedStrings.openSourceLicense.localized)
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(LocalizedStrings.licenseType.localized)
                                Spacer()
                                Text(LocalizedStrings.gplV3.localized)
                                    .fontWeight(.medium)
                            }
                            
                            Text(LocalizedStrings.licenseDescription.localized)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(LocalizedStrings.licenseFreedomUse.localized)
                                Text(LocalizedStrings.licenseFreedomModify.localized)
                                Text(LocalizedStrings.licenseFreedomDistribute.localized)
                                Text(LocalizedStrings.licenseTermsApply.localized)
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    
                    // 版权信息
                    VStack(alignment: .leading, spacing: 12) {
                        Text(LocalizedStrings.copyright.localized)
                            .font(.headline)
                        
                        Text("Copyright © 2025 ShadowMov")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Text(LocalizedStrings.copyrightNotice.localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // 操作按钮
                    VStack(spacing: 12) {
                        Button(LocalizedStrings.viewFullLicense.localized) {
                            if let url = URL(string: "https://www.gnu.org/licenses/gpl-3.0.html") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button(LocalizedStrings.viewSourceCode.localized) {
                            // 这里可以链接到GitHub仓库
                            if let url = URL(string: "https://github.com/samhjn/EasyQSO") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        Button(LocalizedStrings.reportIssue.localized) {
                            // 这里可以链接到Issues页面
                            if let url = URL(string: "https://github.com/samhjn/EasyQSO/issues") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 20)
                }
            }
            .navigationTitle(LocalizedStrings.about.localized)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}
