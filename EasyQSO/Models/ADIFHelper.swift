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
import CoreData

enum ADIFHelper {
    
    // MARK: - ADIF Field Extraction
    
    static func extractField(from record: String, fieldName: String) -> String? {
        let pattern = "<\(fieldName):(\\d+)>([^<]*)"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        
        let nsRange = NSRange(record.startIndex..<record.endIndex, in: record)
        guard let match = regex.firstMatch(in: record, options: [], range: nsRange) else {
            return nil
        }
        
        guard let lengthRange = Range(match.range(at: 1), in: record),
              let length = Int(record[lengthRange]) else {
            return nil
        }
        
        if length == 0 { return nil }
        
        guard let valueRange = Range(match.range(at: 2), in: record) else {
            return nil
        }
        
        let rawValue = String(record[valueRange])
        if rawValue.count > length {
            return String(rawValue.prefix(length))
        }
        return rawValue.isEmpty ? nil : rawValue
    }
    
    static func extractAllFields(from record: String) -> [String: String] {
        var result = [String: String]()
        let pattern = "<([A-Za-z_][A-Za-z0-9_]*):(\\d+)(?::[A-Za-z])?>([^<]*)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return result
        }
        let nsRange = NSRange(record.startIndex..<record.endIndex, in: record)
        let matches = regex.matches(in: record, options: [], range: nsRange)
        
        for match in matches {
            guard let nameRange = Range(match.range(at: 1), in: record),
                  let lengthRange = Range(match.range(at: 2), in: record),
                  let valueRange = Range(match.range(at: 3), in: record),
                  let length = Int(record[lengthRange]) else { continue }
            
            let fieldName = String(record[nameRange]).uppercased()
            if length == 0 { continue }
            
            let rawValue = String(record[valueRange])
            let value = rawValue.count > length ? String(rawValue.prefix(length)) : rawValue
            if !value.isEmpty {
                result[fieldName] = value
            }
        }
        return result
    }
    
    // MARK: - ADIF Generation
    
    static func formatFreqForADIF(_ mhz: Double) -> String {
        var s = String(format: "%.6f", mhz)
        while s.hasSuffix("0") && s.contains(".") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }
    
    static func generateADIF(from records: [QSORecord]) -> Data {
        var adif = "<ADIF_VERS:5>3.1.7"
        adif += "<PROGRAMID:6>EasQSO"
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        adif += "<PROGRAMVERSION:\(appVersion.count)>\(appVersion)"
        adif += "<EOH>\n"
        
        let coreTagsHandledSpecially: Set<String> = [
            "CALL", "QSO_DATE", "TIME_ON", "BAND", "MODE", "SUBMODE",
            "FREQ", "FREQ_RX", "TX_PWR", "RST_SENT", "RST_RCVD",
            "NAME", "QTH", "GRIDSQUARE", "CQZ", "ITUZ",
            "SAT_NAME", "COMMENT", "LAT", "LON"
        ]
        
        for record in records {
            adif += generateADIFRecord(record, coreTagsHandledSpecially: coreTagsHandledSpecially)
        }
        return Data(adif.utf8)
    }
    
    static func generateADIFRecord(_ record: QSORecord, coreTagsHandledSpecially: Set<String>? = nil) -> String {
        var adif = ""
        let coreTags = coreTagsHandledSpecially ?? [
            "CALL", "QSO_DATE", "TIME_ON", "BAND", "MODE", "SUBMODE",
            "FREQ", "FREQ_RX", "TX_PWR", "RST_SENT", "RST_RCVD",
            "NAME", "QTH", "GRIDSQUARE", "CQZ", "ITUZ",
            "SAT_NAME", "COMMENT", "LAT", "LON"
        ]
        
        let (dateString, timeString) = TimezoneManager.formatDateForADIF(record.date)
        adif += "<CALL:\(record.callsign.count)>\(record.callsign)"
        adif += "<QSO_DATE:8>\(dateString)"
        adif += "<TIME_ON:\(timeString.count)>\(timeString)"
        adif += "<BAND:\(record.band.count)>\(record.band)"
        adif += "<MODE:\(record.mode.count)>\(record.mode)"
        if let sub = record.adifFields["SUBMODE"], !sub.isEmpty {
            adif += "<SUBMODE:\(sub.utf8.count)>\(sub)"
        }
        
        if record.frequencyMHz > 0 {
            let freqString = formatFreqForADIF(record.frequencyMHz)
            adif += "<FREQ:\(freqString.count)>\(freqString)"
        }
        if record.rxFrequencyMHz > 0 {
            let rxFreqString = formatFreqForADIF(record.rxFrequencyMHz)
            adif += "<FREQ_RX:\(rxFreqString.count)>\(rxFreqString)"
        }
        if let txPower = record.txPower, !txPower.isEmpty {
            adif += "<TX_PWR:\(txPower.count)>\(txPower)"
        }
        adif += "<RST_SENT:\(record.rstSent.count)>\(record.rstSent)"
        adif += "<RST_RCVD:\(record.rstReceived.count)>\(record.rstReceived)"
        if let name = record.name, !name.isEmpty {
            adif += "<NAME:\(name.count)>\(name)"
        }
        if let qth = record.qth, !qth.isEmpty {
            adif += "<QTH:\(qth.count)>\(qth)"
        }
        if let gridSquare = record.gridSquare, !gridSquare.isEmpty {
            adif += "<GRIDSQUARE:\(gridSquare.count)>\(gridSquare)"
        }
        if let cqZone = record.cqZone, !cqZone.isEmpty {
            adif += "<CQZ:\(cqZone.count)>\(cqZone)"
        }
        if let ituZone = record.ituZone, !ituZone.isEmpty {
            adif += "<ITUZ:\(ituZone.count)>\(ituZone)"
        }
        if let satellite = record.satellite, !satellite.isEmpty {
            adif += "<SAT_NAME:\(satellite.count)>\(satellite)"
        }
        if let remarks = record.remarks, !remarks.isEmpty {
            adif += "<COMMENT:\(remarks.count)>\(remarks)"
        }
        
        for (tag, value) in record.adifFields where !coreTags.contains(tag) {
            if !value.isEmpty {
                let byteCount = value.utf8.count
                adif += "<\(tag):\(byteCount)>\(value)"
            }
        }
        
        adif += "<EOR>\n"
        return adif
    }
    
    // MARK: - ADIF Parsing
    
    static func parseADIFRecords(_ data: Data) -> [[String: String]] {
        guard let adifString = String(data: data, encoding: .utf8) else { return [] }
        
        var dataString = adifString
        if let eohRange = adifString.range(of: "<EOH>", options: .caseInsensitive) {
            dataString = String(adifString[eohRange.upperBound...])
        }
        
        let eorPatterns = ["<EOR>", "<eor>"]
        var records: [String] = []
        
        for pattern in eorPatterns {
            if dataString.contains(pattern) {
                records = dataString.components(separatedBy: pattern)
                break
            }
        }
        
        if records.isEmpty {
            records = dataString.components(separatedBy: .newlines)
        }
        
        var result: [[String: String]] = []
        for record in records {
            let trimmed = record.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            let fields = extractAllFields(from: trimmed)
            if !fields.isEmpty {
                result.append(fields)
            }
        }
        return result
    }
}
