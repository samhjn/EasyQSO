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

enum ADXHelper {

    // MARK: - Core Tag Set

    static let coreTagsHandledSpecially: Set<String> = [
        "CALL", "QSO_DATE", "TIME_ON", "BAND", "MODE", "SUBMODE",
        "FREQ", "FREQ_RX", "TX_PWR", "RST_SENT", "RST_RCVD",
        "NAME", "QTH", "GRIDSQUARE", "CQZ", "ITUZ",
        "SAT_NAME", "COMMENT", "LAT", "LON"
    ]

    // MARK: - ADX Generation (Export)

    static func generateADX(from records: [QSORecord]) -> Data {
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""

        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        xml += "<ADX>\n"
        xml += "  <HEADER>\n"
        xml += "    <ADIF_VERS>3.1.7</ADIF_VERS>\n"
        xml += "    <PROGRAMID>EasyQSO</PROGRAMID>\n"
        xml += "    <PROGRAMVERSION>\(escape(appVersion))</PROGRAMVERSION>\n"
        xml += "  </HEADER>\n"
        xml += "  <RECORDS>\n"
        for record in records {
            xml += generateRecord(record)
        }
        xml += "  </RECORDS>\n"
        xml += "</ADX>\n"
        return Data(xml.utf8)
    }

    private static func generateRecord(_ record: QSORecord) -> String {
        var xml = "    <RECORD>\n"

        let (dateString, timeString) = TimezoneManager.formatDateForADIF(record.date)
        xml += element("CALL", record.callsign)
        xml += element("QSO_DATE", dateString)
        xml += element("TIME_ON", timeString)
        xml += element("BAND", record.band)
        xml += element("MODE", record.mode)
        if let sub = record.adifFields["SUBMODE"], !sub.isEmpty {
            xml += element("SUBMODE", sub)
        }

        if record.frequencyMHz > 0 {
            xml += element("FREQ", ADIFHelper.formatFreqForADIF(record.frequencyMHz))
        }
        if record.rxFrequencyMHz > 0 {
            xml += element("FREQ_RX", ADIFHelper.formatFreqForADIF(record.rxFrequencyMHz))
        }
        if let txPower = record.txPower, !txPower.isEmpty {
            xml += element("TX_PWR", txPower)
        }
        xml += element("RST_SENT", record.rstSent)
        xml += element("RST_RCVD", record.rstReceived)
        if let name = record.name, !name.isEmpty {
            xml += element("NAME", name)
        }
        if let qth = record.qth, !qth.isEmpty {
            xml += element("QTH", qth)
        }
        if let gridSquare = record.gridSquare, !gridSquare.isEmpty {
            xml += element("GRIDSQUARE", gridSquare)
        }
        if let cqZone = record.cqZone, !cqZone.isEmpty {
            xml += element("CQZ", cqZone)
        }
        if let ituZone = record.ituZone, !ituZone.isEmpty {
            xml += element("ITUZ", ituZone)
        }
        if let satellite = record.satellite, !satellite.isEmpty {
            xml += element("SAT_NAME", satellite)
        }
        if let remarks = record.remarks, !remarks.isEmpty {
            xml += element("COMMENT", remarks)
        }

        for (tag, value) in record.adifFields where !coreTagsHandledSpecially.contains(tag) {
            if !value.isEmpty {
                xml += element(tag, value)
            }
        }

        xml += "    </RECORD>\n"
        return xml
    }

    private static func element(_ tag: String, _ value: String) -> String {
        "      <\(tag)>\(escape(value))</\(tag)>\n"
    }

    private static func escape(_ s: String) -> String {
        var r = s
        r = r.replacingOccurrences(of: "&", with: "&amp;")
        r = r.replacingOccurrences(of: "<", with: "&lt;")
        r = r.replacingOccurrences(of: ">", with: "&gt;")
        r = r.replacingOccurrences(of: "\"", with: "&quot;")
        r = r.replacingOccurrences(of: "'", with: "&apos;")
        return r
    }

    // MARK: - ADX Parsing (Import)

    /// Parse an ADX XML payload into one `[tag: value]` dict per `<RECORD>`.
    /// Returns `nil` if the payload is not well-formed XML or is not an ADX
    /// document (no `<ADX>` root). Returns `[]` for an empty but valid log.
    static func parseADX(_ data: Data) -> [[String: String]]? {
        guard looksLikeADX(data) else { return nil }
        let parser = XMLParser(data: data)
        let delegate = ADXParserDelegate()
        parser.delegate = delegate
        guard parser.parse(), delegate.sawADXRoot else { return nil }
        return delegate.records
    }

    /// Convert an ADX payload to the equivalent ADI text payload so it can be
    /// fed to the existing `importADIF` pipeline. Returns `nil` on parse
    /// failure.
    static func convertADXToADI(_ data: Data) -> Data? {
        guard let records = parseADX(data) else { return nil }

        var adi = "<ADIF_VERS:5>3.1.7"
        adi += "<PROGRAMID:7>EasyQSO"
        adi += "<EOH>\n"

        for fields in records {
            for (tag, value) in fields where !value.isEmpty {
                let byteCount = value.utf8.count
                adi += "<\(tag):\(byteCount)>\(value)"
            }
            adi += "<EOR>\n"
        }
        return Data(adi.utf8)
    }

    private static func looksLikeADX(_ data: Data) -> Bool {
        guard let s = String(data: data.prefix(512), encoding: .utf8) else { return false }
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        return lower.hasPrefix("<?xml") || lower.hasPrefix("<adx")
    }
}

// MARK: - XMLParser Delegate

private final class ADXParserDelegate: NSObject, XMLParserDelegate {
    private(set) var records: [[String: String]] = []
    private(set) var sawADXRoot = false

    private var elementStack: [String] = []
    private var currentRecord: [String: String]?
    private var currentFieldName: String?
    private var currentValue = ""

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        let upper = elementName.uppercased()
        elementStack.append(upper)

        if upper == "ADX" {
            sawADXRoot = true
            return
        }

        // Inside <RECORDS><RECORD>...
        if upper == "RECORD" && elementStack.contains("RECORDS") {
            currentRecord = [:]
            return
        }

        guard currentRecord != nil else { return }

        // <APP> / <USERDEF> with FIELDNAME attribute → use the attribute as the
        // tag name. Falls back gracefully if the attribute is missing.
        if upper == "APP" || upper == "USERDEF" {
            let fieldNameAttr = attributeDict["FIELDNAME"]
                ?? attributeDict["fieldname"]
                ?? attributeDict["FieldName"]
            if let attr = fieldNameAttr, !attr.isEmpty {
                currentFieldName = attr.uppercased()
                currentValue = ""
            }
            return
        }

        currentFieldName = upper
        currentValue = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard currentFieldName != nil else { return }
        currentValue += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard currentFieldName != nil,
              let s = String(data: CDATABlock, encoding: .utf8) else { return }
        currentValue += s
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        defer { _ = elementStack.popLast() }
        let upper = elementName.uppercased()

        if upper == "RECORD" {
            if let rec = currentRecord, !rec.isEmpty {
                records.append(rec)
            }
            currentRecord = nil
            currentFieldName = nil
            currentValue = ""
            return
        }

        guard let field = currentFieldName, currentRecord != nil else { return }
        if field == upper || upper == "APP" || upper == "USERDEF" {
            let trimmed = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                currentRecord?[field] = trimmed
            }
            currentFieldName = nil
            currentValue = ""
        }
    }
}
