/*
 * EasyQSO - 业余无线电通联日志
 * Copyright (C) 2025 ShadowMov
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import Foundation

// MARK: - DXCC Entity

struct DXCCEntity: Identifiable, Codable, Equatable {
    let code: Int
    let name: String
    let cqZone: Int
    let ituZone: Int
    let continent: String
    let latitude: Double
    let longitude: Double
    let timeOffset: Double
    let primaryPrefix: String

    var id: Int { code }

    /// Display string: "name (primaryPrefix)"
    var displayName: String {
        "\(name) (\(primaryPrefix))"
    }
}

// MARK: - DXCC Prefix Entry

struct DXCCPrefixEntry: Codable {
    let prefix: String
    let entityCode: Int
    let exact: Bool
}

// MARK: - DXCC Manager

class DXCCManager: ObservableObject {
    static let shared = DXCCManager()

    private static let entitiesKey = "DXCCEntities"
    private static let prefixesKey = "DXCCPrefixes"
    private static let lastUpdateKey = "DXCCLastUpdate"

    @Published private(set) var entities: [DXCCEntity] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdateDate: Date?
    @Published var lastError: String?

    /// Entity lookup by DXCC code
    private(set) var entityByCode: [Int: DXCCEntity] = [:]

    /// Sorted prefix entries (longest first for matching)
    private(set) var prefixEntries: [DXCCPrefixEntry] = []

    /// Exact-match callsign overrides
    private var exactCallsigns: [String: Int] = [:]

    /// Prefix map for fast lookup
    private var prefixMap: [String: Int] = [:]

    var isDataAvailable: Bool { !entities.isEmpty }

    static let ctyCsvURL = "https://www.country-files.com/bigcty/cty.csv"

    private init() {
        loadFromCache()
    }

    // MARK: - Public API

    /// Download and parse CTY CSV from the internet
    func downloadAndParse() async throws {
        await MainActor.run { isLoading = true; lastError = nil }

        defer {
            Task { @MainActor in self.isLoading = false }
        }

        guard let url = URL(string: Self.ctyCsvURL) else {
            let msg = "dxcc_invalid_url".localized
            await MainActor.run { lastError = msg }
            throw DXCCError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let msg = String(format: "dxcc_download_failed".localized, httpResponse.statusCode)
            await MainActor.run { lastError = msg }
            throw DXCCError.downloadFailed(httpResponse.statusCode)
        }

        guard let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
            let msg = "dxcc_parse_error".localized
            await MainActor.run { lastError = msg }
            throw DXCCError.parseError
        }

        let (parsedEntities, parsedPrefixes) = try parseCTYCsv(content)

        if parsedEntities.isEmpty {
            let msg = "dxcc_parse_error".localized
            await MainActor.run { lastError = msg }
            throw DXCCError.parseError
        }

        await MainActor.run {
            self.entities = parsedEntities
            self.entityByCode = Dictionary(uniqueKeysWithValues: parsedEntities.map { ($0.code, $0) })
            self.prefixEntries = parsedPrefixes
            self.buildLookupStructures()
            self.lastUpdateDate = Date()
            self.saveToCache()
        }
    }

    /// Look up DXCC entity for a callsign
    func lookupCallsign(_ callsign: String) -> DXCCEntity? {
        guard isDataAvailable else { return nil }
        let call = callsign.uppercased()

        // Handle portable callsigns (e.g., W1ABC/VP9 → use VP9 prefix)
        let effectiveCall = extractEffectivePrefix(from: call)

        // Check exact match first
        if let code = exactCallsigns[effectiveCall], let entity = entityByCode[code] {
            return entity
        }

        // Longest prefix match
        var bestMatch: Int?
        var bestLength = 0

        for (prefix, code) in prefixMap {
            if effectiveCall.hasPrefix(prefix) && prefix.count > bestLength {
                bestLength = prefix.count
                bestMatch = code
            }
        }

        if let code = bestMatch {
            return entityByCode[code]
        }

        return nil
    }

    /// Get DXCC entity by code
    func entity(forCode code: Int) -> DXCCEntity? {
        entityByCode[code]
    }

    /// Get DXCC entity by code string
    func entity(forCodeString codeString: String) -> DXCCEntity? {
        guard let code = Int(codeString) else { return nil }
        return entityByCode[code]
    }

    /// Search entities by name or prefix
    func searchEntities(_ query: String) -> [DXCCEntity] {
        guard !query.isEmpty else { return entities }
        let q = query.lowercased()
        return entities.filter {
            $0.name.lowercased().contains(q) ||
            $0.primaryPrefix.lowercased().contains(q) ||
            String($0.code).contains(q)
        }
    }

    #if DEBUG
    /// Load test data directly into the manager for unit testing.
    func loadTestData(entities testEntities: [DXCCEntity], prefixes testPrefixes: [DXCCPrefixEntry]) {
        self.entities = testEntities
        self.entityByCode = Dictionary(uniqueKeysWithValues: testEntities.map { ($0.code, $0) })
        self.prefixEntries = testPrefixes
        self.buildLookupStructures()
    }
    #endif

    // MARK: - CTY CSV Parser

    /// Parse cty.csv format:
    /// PrimaryPrefix,EntityName,DXCCCode,Continent,CQZone,ITUZone,Lat,Lon,TimeOffset,Aliases;
    func parseCTYCsv(_ content: String) throws -> ([DXCCEntity], [DXCCPrefixEntry]) {
        var entities: [DXCCEntity] = []
        var prefixes: [DXCCPrefixEntry] = []
        var seenCodes = Set<Int>()

        let lines = content.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            // Each line ends with ";" — strip it
            let record = trimmed.hasSuffix(";")
                ? String(trimmed.dropLast())
                : trimmed

            // Split into fields: first 9 are comma-separated header, 10th is space-separated aliases
            // Format: prefix,name,code,continent,cqz,ituz,lat,lon,offset,aliases
            guard let firstComma = record.firstIndex(of: ",") else { continue }

            let primaryPrefix = String(record[record.startIndex..<firstComma])
                .trimmingCharacters(in: .whitespaces)

            let afterPrefix = String(record[record.index(after: firstComma)...])

            // The entity name may NOT contain commas in cty.csv, so simple split works
            let fields = splitCsvFields(afterPrefix)
            // fields: [name, code, continent, cqz, ituz, lat, lon, offset, aliases...]
            guard fields.count >= 8 else { continue }

            let entityName = fields[0]
            guard let dxccCode = Int(fields[1]) else { continue }
            let continent = fields[2]
            guard let cqZone = Int(fields[3]),
                  let ituZone = Int(fields[4]) else { continue }
            let latitude = Double(fields[5]) ?? 0
            let longitude = Double(fields[6]) ?? 0
            let timeOffset = Double(fields[7]) ?? 0

            let cleanPrimaryPrefix = primaryPrefix
                .trimmingCharacters(in: CharacterSet(charactersIn: "*"))

            let entity = DXCCEntity(
                code: dxccCode,
                name: entityName,
                cqZone: cqZone,
                ituZone: ituZone,
                continent: continent,
                latitude: latitude,
                longitude: longitude,
                timeOffset: timeOffset,
                primaryPrefix: cleanPrimaryPrefix
            )

            if !seenCodes.contains(dxccCode) {
                entities.append(entity)
                seenCodes.insert(dxccCode)
            }

            // Add primary prefix
            prefixes.append(DXCCPrefixEntry(
                prefix: cleanPrimaryPrefix.uppercased(),
                entityCode: dxccCode,
                exact: false
            ))

            // Parse aliases (field index 8, space-separated)
            if fields.count >= 9 {
                let aliasStr = fields[8]
                let aliases = aliasStr.components(separatedBy: " ")
                for alias in aliases {
                    let pfx = alias.trimmingCharacters(in: .whitespaces)
                    if pfx.isEmpty { continue }

                    let cleanAlias = stripOverrideMarkers(pfx)
                    if cleanAlias.isEmpty { continue }

                    let isExact = cleanAlias.hasPrefix("=")
                    let finalPrefix = isExact ? String(cleanAlias.dropFirst()) : cleanAlias

                    prefixes.append(DXCCPrefixEntry(
                        prefix: finalPrefix.uppercased(),
                        entityCode: dxccCode,
                        exact: isExact
                    ))
                }
            }
        }

        entities.sort { $0.name < $1.name }
        return (entities, prefixes)
    }

    /// Split CSV fields — first 8 fields are comma-separated, 9th field (aliases) is everything after the 8th comma
    private func splitCsvFields(_ str: String) -> [String] {
        var fields: [String] = []
        var current = str.startIndex
        var commaCount = 0

        for i in str.indices {
            if str[i] == "," {
                commaCount += 1
                fields.append(String(str[current..<i]).trimmingCharacters(in: .whitespaces))
                current = str.index(after: i)
                // After 8 commas (9 fields including aliases), treat rest as one field
                if commaCount == 8 {
                    fields.append(String(str[current...]).trimmingCharacters(in: .whitespaces))
                    return fields
                }
            }
        }
        // Last field (no trailing comma)
        if current < str.endIndex {
            fields.append(String(str[current...]).trimmingCharacters(in: .whitespaces))
        }
        return fields
    }

    private func stripOverrideMarkers(_ prefix: String) -> String {
        var result = prefix
        // Remove CQ zone override (xx)
        while let range = result.range(of: #"\(\d+\)"#, options: .regularExpression) {
            result.removeSubrange(range)
        }
        // Remove ITU zone override [xx]
        while let range = result.range(of: #"\[\d+\]"#, options: .regularExpression) {
            result.removeSubrange(range)
        }
        // Remove continent override {xx}
        while let range = result.range(of: #"\{[A-Z]+\}"#, options: .regularExpression) {
            result.removeSubrange(range)
        }
        // Remove time offset override ~xx~
        while let range = result.range(of: #"~[\d.\-]+~"#, options: .regularExpression) {
            result.removeSubrange(range)
        }
        // Remove lat/lon override <xx/xx>
        while let range = result.range(of: #"<[\d.\-/]+>"#, options: .regularExpression) {
            result.removeSubrange(range)
        }
        return result
    }

    // MARK: - Prefix Matching Helpers

    private func buildLookupStructures() {
        prefixMap = [:]
        exactCallsigns = [:]

        for entry in prefixEntries {
            if entry.exact {
                exactCallsigns[entry.prefix] = entry.entityCode
            } else {
                prefixMap[entry.prefix] = entry.entityCode
            }
        }
    }

    /// Extract the effective prefix for lookup from a callsign that may contain "/" separators
    private func extractEffectivePrefix(from callsign: String) -> String {
        let parts = callsign.components(separatedBy: "/")
        guard parts.count > 1 else { return callsign }

        // If the suffix part is short (1-3 chars), it's usually a modifier like /P, /M, /QRP
        if let last = parts.last, last.count <= 3 {
            return parts[0]
        }

        // Shorter part is usually the prefix indicator
        if parts[0].count < parts[1].count {
            return parts[0]
        }

        return parts[0]
    }

    // MARK: - Cache

    private func saveToCache() {
        if let data = try? JSONEncoder().encode(entities) {
            UserDefaults.standard.set(data, forKey: Self.entitiesKey)
        }
        if let data = try? JSONEncoder().encode(prefixEntries) {
            UserDefaults.standard.set(data, forKey: Self.prefixesKey)
        }
        if let date = lastUpdateDate {
            UserDefaults.standard.set(date, forKey: Self.lastUpdateKey)
        }
    }

    private func loadFromCache() {
        if let data = UserDefaults.standard.data(forKey: Self.entitiesKey),
           let cached = try? JSONDecoder().decode([DXCCEntity].self, from: data) {
            entities = cached
            entityByCode = Dictionary(uniqueKeysWithValues: cached.map { ($0.code, $0) })
        }
        if let data = UserDefaults.standard.data(forKey: Self.prefixesKey),
           let cached = try? JSONDecoder().decode([DXCCPrefixEntry].self, from: data) {
            prefixEntries = cached
            buildLookupStructures()
        }
        lastUpdateDate = UserDefaults.standard.object(forKey: Self.lastUpdateKey) as? Date
    }

    // MARK: - Errors

    enum DXCCError: LocalizedError {
        case invalidURL
        case downloadFailed(Int)
        case parseError

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid URL"
            case .downloadFailed(let code): return "Download failed: HTTP \(code)"
            case .parseError: return "Failed to parse DXCC data"
            }
        }
    }
}
