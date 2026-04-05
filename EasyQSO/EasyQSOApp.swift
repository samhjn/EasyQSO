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

@main
struct EasyQSOApp: App {
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onAppear {
                    setupAppearance()
                    ModeManager.shared.ensureDefaultVisibility()
                    migrateSubmodeRecordsInBackground()
                }
        }
    }
    
    private func migrateSubmodeRecordsInBackground() {
        let key = "SubmodeMigrationDone_v2"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let container = persistenceController.container
        container.performBackgroundTask { bgContext in
            bgContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

            let request = NSFetchRequest<QSORecord>(entityName: "QSORecord")
            request.fetchBatchSize = 100
            guard let records = try? bgContext.fetch(request) else {
                DispatchQueue.main.async {
                    UserDefaults.standard.set(true, forKey: key)
                }
                return
            }

            var migrated = 0
            for record in records {
                let modeVal = record.mode
                if let parentMode = ModeManager.parentMode(for: modeVal) {
                    var fields = record.adifFields
                    if (fields["SUBMODE"] ?? "").isEmpty {
                        fields["SUBMODE"] = modeVal
                        record.adifFields = fields
                        record.mode = parentMode
                        migrated += 1
                    }
                }
            }

            if migrated > 0 {
                do {
                    try bgContext.save()
                    print("✓ Submode migration: \(migrated) records fixed")
                } catch {
                    print("✗ Submode migration failed: \(error)")
                }
            }

            DispatchQueue.main.async {
                UserDefaults.standard.set(true, forKey: key)
            }
        }
    }

    private func setupAppearance() {
        // 设置导航栏样式
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // 设置Tab Bar样式
        UITabBar.appearance().backgroundColor = UIColor.systemBackground
    }
}

// 为SwiftUI预览提供预览版本
struct EasyQSOApp_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
