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
import MapKit
import CoreLocation

enum QTHEditMode {
    case ownQTH        // 编辑己方QTH - 自动获取定位并预填
    case otherQTH      // 编辑对方QTH - 自动获取定位切换地图但不预填
}

struct EnhancedMapLocationPicker: View {
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var locationName: String
    @Binding var gridSquare: String
    let editMode: QTHEditMode
    @Environment(\.presentationMode) var presentationMode
    
    @StateObject private var qthManager = QTHManager()
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var annotations: [MapLocationAnnotation] = []
    @State private var tempLocationName = ""
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var showingSearchResults = false
    @State private var isGettingLocation = false
    @State private var showingLocationAlert = false
    @State private var locationAlertMessage = ""
    
    // 为了支持旧的调用方式，提供默认初始化器
    init(selectedLocation: Binding<CLLocationCoordinate2D?>, 
         locationName: Binding<String>, 
         gridSquare: Binding<String>, 
         editMode: QTHEditMode = .otherQTH) {
        self._selectedLocation = selectedLocation
        self._locationName = locationName
        self._gridSquare = gridSquare
        self.editMode = editMode
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏和定位按钮
                searchAndLocationBar
                
                // 地图视图
                EnhancedInteractiveMapView(
                    selectedLocation: $selectedLocation,
                    region: $region,
                    annotations: $annotations,
                    searchResults: $searchResults,
                    tempLocationName: $tempLocationName,
                    showingSearchResults: $showingSearchResults
                )
                .frame(maxHeight: .infinity)
                
                // 位置信息面板
                if let location = selectedLocation {
                    locationInfoPanel(location: location)
                } else {
                    emptyStatePanel
                }
                
                // 搜索结果列表
                if showingSearchResults && !searchResults.isEmpty {
                    searchResultsList
                }
            }
            .navigationTitle(editMode == .ownQTH ? "设置己方位置" : "选择位置")
            .navigationBarItems(
                leading: Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: HStack {
                    Button("确定") {
                        if let location = selectedLocation {
                            // 使用临时变量避免直接修改绑定
                            DispatchQueue.main.async {
                                locationName = tempLocationName
                                gridSquare = formatGridSquare(QTHManager.calculateGridSquare(from: location))
                            }
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(selectedLocation == nil)
                }
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .alert(isPresented: $showingLocationAlert) {
            Alert(
                title: Text("定位提示"),
                message: Text(locationAlertMessage),
                dismissButton: .default(Text("确定"))
            )
        }
        .onAppear {
            setupInitialState()
            // 根据编辑模式自动获取定位
            handleAutoLocation()
        }
    }
    
    // MARK: - 子视图
    
    private var searchAndLocationBar: some View {
        VStack(spacing: 8) {
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("搜索地点...", text: $searchText)
                        .onSubmit {
                            performSearch()
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchResults.removeAll()
                            showingSearchResults = false
                        }) {
                            Image(systemName: "multiply.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button("搜索") {
                        performSearch()
                    }
                    .disabled(searchText.isEmpty)
                }
            }
            
            // 定位按钮
            HStack {
                Button(action: {
                    getCurrentLocationManually()
                }) {
                    HStack {
                        if isGettingLocation {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("正在定位...")
                        } else {
                            Image(systemName: "location.fill")
                            Text(editMode == .ownQTH ? "获取我的位置" : "定位到我的位置")
                        }
                    }
                    .foregroundColor(.blue)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .disabled(isGettingLocation)
                
                Spacer()
            }
        }
        .padding()
    }
    
    private func locationInfoPanel(location: CLLocationCoordinate2D) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("位置信息")
                .font(.headline)
            
            HStack {
                Text("坐标:")
                Text("\(String(format: "%.4f", location.latitude)), \(String(format: "%.4f", location.longitude))")
                    .foregroundColor(.secondary)
            }
            .font(.caption)
            
            HStack {
                Text("网格:")
                Text(formatGridSquare(QTHManager.calculateGridSquare(from: location)))
                    .foregroundColor(.secondary)
            }
            .font(.caption)
            
            TextField("位置名称", text: $tempLocationName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding()
    }
    
    private var emptyStatePanel: some View {
        VStack {
            Text("点击地图选择位置")
                .foregroundColor(.secondary)
            Text("或使用搜索功能查找地点")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(searchResults, id: \.self) { item in
                    searchResultRow(item: item)
                }
            }
            .padding()
        }
        .frame(maxHeight: 200)
        .background(Color(.systemGray6))
    }
    
    private func searchResultRow(item: MKMapItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.name ?? "未知地点")
                .font(.headline)
            
            if let address = item.placemark.title {
                Text(address)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.clear)
        .onTapGesture {
            selectSearchResult(item)
        }
    }
    
    // MARK: - 功能函数
    
    private func setupInitialState() {
        if let location = selectedLocation {
            // 如果已有选中位置，使用该位置
            region.center = location
            tempLocationName = locationName
            let annotation = MapLocationAnnotation(coordinate: location)
            annotations = [annotation]
        } else if !gridSquare.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // 如果没有选中位置但有网格坐标，从网格坐标计算中心位置
            let cleanedGrid = gridSquare.trimmingCharacters(in: .whitespacesAndNewlines)
            if let gridCoordinate = QTHManager.coordinateFromGridSquare(cleanedGrid) {
                selectedLocation = gridCoordinate
                region.center = gridCoordinate
                region.span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                let annotation = MapLocationAnnotation(coordinate: gridCoordinate)
                annotations = [annotation]
                tempLocationName = locationName
            } else {
                // 网格坐标无效，使用默认位置
                tempLocationName = locationName
            }
        } else {
            // 确保有默认的临时位置名称
            tempLocationName = locationName
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSearching = true
        showingSearchResults = true
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = region
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                isSearching = false
                
                if let response = response {
                    searchResults = response.mapItems
                } else {
                    searchResults = []
                }
            }
        }
    }
    
    private func selectSearchResult(_ item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        selectedLocation = coordinate
        
        // 自动填写位置名称
        if let name = item.name {
            tempLocationName = name
        } else if let thoroughfare = item.placemark.thoroughfare {
            // 如果没有名称，使用街道名
            tempLocationName = thoroughfare
        } else {
            // 如果都没有，使用坐标
            tempLocationName = String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
        }
        
        // 更新地图区域
        region.center = coordinate
        region.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        
        // 添加标注
        annotations.removeAll()
        let annotation = MapLocationAnnotation(coordinate: coordinate)
        annotations.append(annotation)
        
        // 隐藏搜索结果
        showingSearchResults = false
        searchText = ""
        searchResults.removeAll()
    }
    
    private func getCurrentLocationManually() {
        guard qthManager.hasLocationPermission || qthManager.locationAuthorizationStatus == .notDetermined else {
            locationAlertMessage = "请在设置中开启定位权限"
            showingLocationAlert = true
            return
        }
        
        isGettingLocation = true
        
        qthManager.getCurrentLocation { coordinate in
            DispatchQueue.main.async {
                self.isGettingLocation = false
                
                if let coordinate = coordinate {
                    // 根据编辑模式决定行为
                    if self.editMode == .ownQTH {
                        // 己方QTH：预填坐标和位置信息
                        self.selectedLocation = coordinate
                        self.region.center = coordinate
                        self.region.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        
                        // 清除现有标注
                        self.annotations.removeAll()
                        
                        // 添加新标注
                        let annotation = MapLocationAnnotation(coordinate: coordinate)
                        self.annotations.append(annotation)
                        
                        // 反向地理编码获取位置名称
                        self.reverseGeocodeLocation(coordinate) { locationName in
                            DispatchQueue.main.async {
                                self.tempLocationName = locationName
                            }
                        }
                        
                        // 提供触觉反馈，让用户知道定位成功
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                                         } else {
                         // 对方QTH：只切换地图位置，不预填
                         self.region.center = coordinate
                         self.region.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                         
                         // 提供触觉反馈，让用户知道地图已切换到当前位置
                         let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                         impactFeedback.impactOccurred()
                     }
                } else {
                    // 只在无法获取定位时显示错误提示
                    self.locationAlertMessage = "无法获取当前位置，请检查定位权限"
                    self.showingLocationAlert = true
                }
            }
        }
    }
    
    private func handleAutoLocation() {
        // 只有编辑己方QTH时才自动获取定位并预填
        if editMode == .ownQTH {
            // 延迟一下，让界面先显示再获取定位，并且自动获取时不显示按钮加载状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.getCurrentLocationSilently()
            }
        }
    }
    
    private func getCurrentLocationSilently() {
        guard qthManager.hasLocationPermission || qthManager.locationAuthorizationStatus == .notDetermined else {
            return // 静默失败，不显示错误
        }
        
        qthManager.getCurrentLocation { coordinate in
            DispatchQueue.main.async {
                if let coordinate = coordinate {
                    if self.editMode == .ownQTH {
                        // 己方QTH：预填坐标和位置信息
                        self.selectedLocation = coordinate
                        self.region.center = coordinate
                        self.region.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        
                        // 清除现有标注
                        self.annotations.removeAll()
                        
                        // 添加新标注
                        let annotation = MapLocationAnnotation(coordinate: coordinate)
                        self.annotations.append(annotation)
                        
                        // 反向地理编码获取位置名称
                        self.reverseGeocodeLocation(coordinate) { locationName in
                            DispatchQueue.main.async {
                                self.tempLocationName = locationName
                            }
                        }
                    } else {
                        // 对方QTH：只切换地图位置
                        self.region.center = coordinate
                        self.region.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    }
                }
                // 自动获取失败时不显示任何提示
            }
        }
    }
    
    private func reverseGeocodeLocation(_ coordinate: CLLocationCoordinate2D, completion: @escaping (String) -> Void) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            guard let placemark = placemarks?.first, error == nil else {
                completion(String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude))
                return
            }
            
            // 尝试获取最具体的位置名称
            if let name = placemark.name {
                completion(name)
            } else if let thoroughfare = placemark.thoroughfare {
                var locationName = thoroughfare
                if let subThoroughfare = placemark.subThoroughfare {
                    locationName = "\(subThoroughfare) \(thoroughfare)"
                }
                completion(locationName)
            } else if let locality = placemark.locality {
                completion(locality)
            } else {
                completion(String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude))
            }
        }
    }
    
    // 格式化网格坐标：前4位大写，后2位小写
    private func formatGridSquare(_ input: String) -> String {
        let cleaned = input.replacingOccurrences(of: " ", with: "")
        if cleaned.count <= 4 {
            return cleaned.uppercased()
        } else if cleaned.count >= 6 {
            let prefix = String(cleaned.prefix(4)).uppercased()
            let suffix = String(cleaned.dropFirst(4).prefix(2)).lowercased()
            return prefix + suffix
        } else {
            return cleaned.uppercased()
        }
    }
}

// 增强的交互式地图视图
struct EnhancedInteractiveMapView: UIViewRepresentable {
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var region: MKCoordinateRegion
    @Binding var annotations: [MapLocationAnnotation]
    @Binding var searchResults: [MKMapItem]
    @Binding var tempLocationName: String
    @Binding var showingSearchResults: Bool
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        
        // 允许缩放和平移
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true
        
        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.mapTapped(_:)))
        mapView.addGestureRecognizer(tapGesture)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 更新地图区域（仅在有显著变化时）
        let currentCenter = mapView.region.center
        let targetCenter = region.center
        let threshold = 0.001
        
        if abs(currentCenter.latitude - targetCenter.latitude) > threshold ||
           abs(currentCenter.longitude - targetCenter.longitude) > threshold ||
           abs(mapView.region.span.latitudeDelta - region.span.latitudeDelta) > threshold {
            mapView.setRegion(region, animated: true)
        }
        
        // 智能更新用户标注 - 只在标注真正变化时更新
        let existingUserAnnotations = mapView.annotations.filter { annotation in
            if let title = annotation.title as? String, title == "SELECTED" {
                return true
            }
            return false
        }
        
        // 检查是否需要更新标注
        let newAnnotations = annotations.map { annotation in
            let mkAnnotation = MKPointAnnotation()
            mkAnnotation.coordinate = annotation.coordinate
            mkAnnotation.title = "SELECTED"
            return mkAnnotation
        }
        
        // 只在标注数量或位置发生变化时才更新
        let needsUpdate = existingUserAnnotations.count != newAnnotations.count ||
                         !existingUserAnnotations.allSatisfy { existing in
                             newAnnotations.contains { new in
                                 abs(existing.coordinate.latitude - new.coordinate.latitude) < 0.0001 &&
                                 abs(existing.coordinate.longitude - new.coordinate.longitude) < 0.0001
                             }
                         }
        
        if needsUpdate {
            // 移除旧的用户标注
            mapView.removeAnnotations(existingUserAnnotations)
            
            // 添加新的用户标注
            if !newAnnotations.isEmpty {
                mapView.addAnnotations(newAnnotations)
            }
        }
        
        // 智能更新搜索结果标注
        let existingSearchAnnotations = mapView.annotations.filter { annotation in
            if let title = annotation.title as? String, title != "SELECTED" && !title.isEmpty {
                return true
            }
            return false
        }
        
        let newSearchAnnotations = searchResults.map { item in
            let mkAnnotation = MKPointAnnotation()
            mkAnnotation.coordinate = item.placemark.coordinate
            mkAnnotation.title = item.name
            mkAnnotation.subtitle = item.placemark.title
            return mkAnnotation
        }
        
        // 检查搜索结果是否需要更新
        let searchNeedsUpdate = existingSearchAnnotations.count != newSearchAnnotations.count ||
                               !existingSearchAnnotations.allSatisfy { existing in
                                   newSearchAnnotations.contains { new in
                                       existing.title == new.title &&
                                       abs(existing.coordinate.latitude - new.coordinate.latitude) < 0.0001 &&
                                       abs(existing.coordinate.longitude - new.coordinate.longitude) < 0.0001
                                   }
                               }
        
        if searchNeedsUpdate {
            // 移除旧的搜索结果
            mapView.removeAnnotations(existingSearchAnnotations)
            
            // 添加新的搜索结果
            if !newSearchAnnotations.isEmpty {
                mapView.addAnnotations(newSearchAnnotations)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: EnhancedInteractiveMapView
        
        init(_ parent: EnhancedInteractiveMapView) {
            self.parent = parent
        }
        
        @objc func mapTapped(_ gesture: UITapGestureRecognizer) {
            let mapView = gesture.view as! MKMapView
            let touchPoint = gesture.location(in: mapView)
            let coordinate = mapView.convert(touchPoint, toCoordinateFrom: mapView)
            
            // 更新选中位置
            self.parent.selectedLocation = coordinate
            
            // 清除现有用户标注（保留搜索结果）
            self.parent.annotations.removeAll()
            
            // 添加新标注
            let annotation = MapLocationAnnotation(coordinate: coordinate)
            self.parent.annotations.append(annotation)
            
            // 进行反向地理编码获取位置信息
            let geocoder = CLGeocoder()
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                guard let placemark = placemarks?.first, error == nil else { return }
                
                DispatchQueue.main.async {
                    // 尝试获取最具体的位置名称
                    if let name = placemark.name {
                        // 如果有具体的地点名称（如商店、餐厅等）
                        self.parent.tempLocationName = name
                    } else if let thoroughfare = placemark.thoroughfare {
                        // 如果没有具体名称，使用街道名
                        var locationName = thoroughfare
                        if let subThoroughfare = placemark.subThoroughfare {
                            locationName = "\(subThoroughfare) \(thoroughfare)"
                        }
                        self.parent.tempLocationName = locationName
                    } else if let locality = placemark.locality {
                        // 如果没有街道名，使用城市名
                        self.parent.tempLocationName = locality
                    } else {
                        // 如果都没有，使用坐标
                        self.parent.tempLocationName = String(format: "%.4f, %.4f", 
                                                           coordinate.latitude, coordinate.longitude)
                    }
                }
            }
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            self.parent.region = mapView.region
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil
            }
            
            // 区分不同类型的标注使用不同的identifier和视图类型
            if let title = annotation.title, title == "SELECTED" {
                // 用户选中的位置：使用红色大头针（简化实现）
                let identifier = "SelectedLocationPin"
                var pinAnnotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKPinAnnotationView
                
                if pinAnnotationView == nil {
                    pinAnnotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                } else {
                    pinAnnotationView?.annotation = annotation
                }
                
                // 强制设置为鲜明的红色，确保不受重用影响
                pinAnnotationView?.pinTintColor = UIColor.red
                pinAnnotationView?.canShowCallout = false  // 不显示callout避免显示"SELECTED"
                // 只在首次创建时启用掉落动画，重用时不启用
                pinAnnotationView?.animatesDrop = (pinAnnotationView?.tag != 999)
                
                // 延时再次确保红色设置
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    pinAnnotationView?.pinTintColor = UIColor.red
                }
                
                // 只在首次创建时添加脉冲动画，避免地图操作时重复触发
                if pinAnnotationView?.tag != 999 { // 用tag标记已经动画过的视图
                    pinAnnotationView?.tag = 999
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if let view = pinAnnotationView {
                            UIView.animate(withDuration: 0.3, animations: {
                                view.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
                            }) { _ in
                                UIView.animate(withDuration: 0.3, animations: {
                                    view.transform = CGAffineTransform.identity
                                }) { _ in
                                    UIView.animate(withDuration: 0.3, animations: {
                                        view.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
                                    }) { _ in
                                        UIView.animate(withDuration: 0.3) {
                                            view.transform = CGAffineTransform.identity
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                return pinAnnotationView
            } else {
                // 搜索结果：使用蓝色大头针
                let identifier = "SearchResultPin"
                var pinAnnotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKPinAnnotationView
                
                if pinAnnotationView == nil {
                    pinAnnotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                } else {
                    pinAnnotationView?.annotation = annotation
                }
                
                pinAnnotationView?.pinTintColor = .systemBlue
                pinAnnotationView?.canShowCallout = true
                pinAnnotationView?.animatesDrop = false
                
                // 添加右侧按钮来选择这个搜索结果
                let selectButton = UIButton(type: .detailDisclosure)
                selectButton.tintColor = .systemBlue
                pinAnnotationView?.rightCalloutAccessoryView = selectButton
                
                return pinAnnotationView
            }
        }
        
        // 处理callout按钮点击
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            if let annotation = view.annotation,
               let title = annotation.title as? String,
               !title.isEmpty && title != "SELECTED" {
                
                // 选择这个搜索结果
                self.parent.selectedLocation = annotation.coordinate
                
                // 自动填写位置名称
                self.parent.tempLocationName = title
                
                // 清除现有用户标注
                self.parent.annotations.removeAll()
                
                // 添加新标注
                let newAnnotation = MapLocationAnnotation(coordinate: annotation.coordinate)
                self.parent.annotations.append(newAnnotation)
                
                // 清除搜索结果
                self.parent.searchResults.removeAll()
                self.parent.showingSearchResults = false
                
                // 提供触觉反馈
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }
        }
        
        // 处理地图上标注的点击（现在主要用于显示callout）
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            // 搜索结果点击时显示callout，用户选中的位置不响应点击
            // callout的选择通过accessory button处理
        }
    }
}

struct MapLocationAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
} 