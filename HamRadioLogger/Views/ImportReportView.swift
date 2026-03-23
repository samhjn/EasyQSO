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

struct ImportReportView: View {
    @Environment(\.presentationMode) var presentationMode
    let result: ImportResult
    
    var body: some View {
        NavigationView {
            List {
                // 汇总信息
                Section(header: Text("导入汇总")) {
                    HStack {
                        Label("总计", systemImage: "doc.text")
                        Spacer()
                        Text("\(result.totalProcessed)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("成功导入", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Spacer()
                        Text("\(result.successRecords.count)")
                            .foregroundColor(.green)
                            .fontWeight(.bold)
                    }
                    
                    if !result.duplicateRecords.isEmpty {
                        HStack {
                            Label("重复跳过", systemImage: "arrow.triangle.2.circlepath")
                                .foregroundColor(.orange)
                            Spacer()
                            Text("\(result.duplicateRecords.count)")
                                .foregroundColor(.orange)
                                .fontWeight(.bold)
                        }
                    }
                    
                    if !result.invalidRecords.isEmpty {
                        HStack {
                            Label("非法记录", systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Spacer()
                            Text("\(result.invalidRecords.count)")
                                .foregroundColor(.red)
                                .fontWeight(.bold)
                        }
                    }
                }
                
                // 成功导入的记录
                if !result.successRecords.isEmpty {
                    Section(header: HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("成功导入 (\(result.successRecords.count))")
                    }) {
                        ForEach(result.successRecords) { record in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.description)
                                    .font(.body)
                            }
                        }
                    }
                }
                
                // 重复记录
                if !result.duplicateRecords.isEmpty {
                    Section(header: HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.orange)
                        Text("重复记录 (\(result.duplicateRecords.count))")
                    }) {
                        ForEach(result.duplicateRecords) { record in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.description)
                                    .font(.body)
                                if let reason = record.reason {
                                    Text(reason)
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                }
                
                // 非法记录
                if !result.invalidRecords.isEmpty {
                    Section(header: HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("非法记录 (\(result.invalidRecords.count))")
                    }) {
                        ForEach(result.invalidRecords) { record in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.description)
                                    .font(.body)
                                if let reason = record.reason {
                                    Text(reason)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                if let rawData = record.rawData, !rawData.isEmpty {
                                    Text(rawData.prefix(100))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("导入报告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct ImportReportView_Previews: PreviewProvider {
    static var previews: some View {
        ImportReportView(result: ImportResult(
            successRecords: [
                ImportRecord(callsign: "BG1ABC", dateTime: "2025-02-17 14:30", band: "20m", mode: "SSB", frequency: "14.250"),
                ImportRecord(callsign: "BG2DEF", dateTime: "2025-02-17 15:00", band: "40m", mode: "CW", frequency: "7.050")
            ],
            duplicateRecords: [
                ImportRecord(callsign: "BG3GHI", dateTime: "2025-02-16 10:00", band: "20m", mode: "FT8", frequency: "14.074", reason: "该记录已存在于数据库中")
            ],
            invalidRecords: [
                ImportRecord(callsign: "", dateTime: "2025-02-15", band: "", mode: "", frequency: "", reason: "缺少必填字段：呼号", rawData: "<QSO_DATE:8>20250215<EOR>")
            ]
        ))
    }
}
