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

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showingGPLAlert = false
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                QSORecordView()
                    .tabItem {
                        Label(LocalizedStrings.recordQSO.localized, systemImage: "antenna.radiowaves.left.and.right")
                    }
                    .tag(0)
                
                LogQueryView()
                    .tabItem {
                        Label(LocalizedStrings.queryLog.localized, systemImage: "magnifyingglass")
                    }
                    .tag(1)
                
                LogImportExportView()
                    .tabItem {
                        Label(LocalizedStrings.importExport.localized, systemImage: "arrow.up.arrow.down")
                    }
                    .tag(2)
                
                AboutView()
                    .tabItem {
                        Label(LocalizedStrings.about.localized, systemImage: "info.circle")
                    }
                    .tag(3)
            }
            .accentColor(.blue)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            // 检查是否是首次启动，显示GPL提示
            if !UserDefaults.standard.bool(forKey: "hasShownGPLAlert") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showingGPLAlert = true
                }
            }
        }
        .alert(LocalizedStrings.welcomeTitle.localized, isPresented: $showingGPLAlert) {
            Button(LocalizedStrings.learnGplLicense.localized) {
                selectedTab = 3 // 切换到关于标签页
                UserDefaults.standard.set(true, forKey: "hasShownGPLAlert")
            }
            Button(LocalizedStrings.viewLater.localized) {
                UserDefaults.standard.set(true, forKey: "hasShownGPLAlert")
            }
        } message: {
            Text(LocalizedStrings.welcomeGplNotice.localized)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
