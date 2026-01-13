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
import CoreData

// 删除确认的标识结构
struct DeleteConfirmation: Identifiable {
    let id: NSManagedObjectID
    let callsign: String
}

// 自定义搜索栏视图
struct CustomSearchBar: View {
    @Binding var text: String
    var placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField(placeholder, text: $text)
                .disableAutocorrection(true)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "multiply.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

struct LogQueryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \QSORecord.date, ascending: false)],
        animation: nil)
    private var qsoRecords: FetchedResults<QSORecord>
    
    @State private var searchText = ""
    @State private var deleteConfirmation: DeleteConfirmation?
    @State private var selectedRecord: QSORecord?
    
    // 添加一个用于显示一般警告的状态和属性
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    var filteredRecords: [QSORecord] {
        if searchText.isEmpty {
            return Array(qsoRecords)
        } else {
            return qsoRecords.filter { record in
                record.callsign.localizedCaseInsensitiveContains(searchText) ||
                record.band.localizedCaseInsensitiveContains(searchText) ||
                record.mode.localizedCaseInsensitiveContains(searchText) ||
                (record.name ?? "").localizedCaseInsensitiveContains(searchText) ||
                (record.qth ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 自定义搜索栏
            CustomSearchBar(text: $searchText, placeholder: LocalizedStrings.searchPlaceholder.localized)
                .padding(.vertical, 8)
            
            // 列表
            List {
                ForEach(filteredRecords) { record in
                    NavigationLink {
                        EditQSOView(record: record)
                    } label: {
                        QSOLogRow(record: record)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            print("滑动删除按钮: \(record.callsign)")
                            deleteConfirmation = DeleteConfirmation(id: record.objectID, callsign: record.callsign)
                        } label: {
                            Label(LocalizedStrings.delete.localized, systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
            }
            
            Text(String(format: LocalizedStrings.recordCount.localized, filteredRecords.count))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
        }
        .navigationTitle(LocalizedStrings.queryLog.localized)
        // 删除确认对话框
        .alert(item: $deleteConfirmation) { confirmation in
            Alert(
                title: Text(LocalizedStrings.deleteRecord.localized),
                message: Text(String(format: LocalizedStrings.deleteConfirmMessage.localized, confirmation.callsign)),
                primaryButton: .destructive(Text(LocalizedStrings.delete.localized)) {
                    print("确认删除: \(confirmation.callsign)")
                    deleteRecordByID(confirmation.id)
                },
                secondaryButton: .cancel(Text(LocalizedStrings.cancel.localized))
            )
        }
        // 操作结果对话框
        .background(
            EmptyView()
                .alert(isPresented: $showingAlert) {
                    Alert(
                        title: Text(alertTitle),
                        message: Text(alertMessage),
                        dismissButton: .default(Text(LocalizedStrings.confirm.localized))
                    )
                }
        )
    }
    
    private func deleteRecordByID(_ objectID: NSManagedObjectID) {
        print("开始删除记录: \(objectID)")
        
        // 从objectID获取记录对象
        guard let record = try? viewContext.existingObject(with: objectID) as? QSORecord else {
            print("无法找到要删除的记录")
            return
        }
        
        let callsign = record.callsign
        print("准备删除: \(callsign)")
        
        // 从视图上下文中删除记录
        viewContext.delete(record)
        
        // 保存上下文
        do {
            try viewContext.save()
            print("上下文已保存")
            
            // 添加成功删除的反馈
            alertTitle = LocalizedStrings.deleteSuccess.localized
            alertMessage = LocalizedStrings.deleteSuccessMessage.localized
            showingAlert = true
        } catch {
            print("删除记录失败: \(error)")
            // 显示删除失败的警告
            alertTitle = LocalizedStrings.deleteFailed.localized
            alertMessage = String(format: LocalizedStrings.deleteFailedMessage.localized, error.localizedDescription)
            showingAlert = true
        }
    }
}

struct QSOLogRow: View {
    let record: QSORecord
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(record.callsign)
                    .font(.headline)
                Spacer()
                Text(dateFormatter.string(from: record.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("\(record.band) · \(record.mode)")
                    .font(.subheadline)
                if record.frequency > 0 {
                    Text("· \(String(format: "%.3f", record.frequency)) MHz")
                        .font(.subheadline)
                }
            }
            .foregroundColor(.secondary)
            
            if let name = record.name, !name.isEmpty {
                Text("\(LocalizedStrings.operatorLabel.localized): \(name)")
                    .font(.caption)
            }
            
            if let qth = record.qth, !qth.isEmpty {
                Text("\(LocalizedStrings.qth.localized): \(qth)")
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}
