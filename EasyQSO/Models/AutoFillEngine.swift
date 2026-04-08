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

// MARK: - Field Source Tracking

/// Tracks how a field's current value was set.
enum FieldSource: Equatable {
    /// Value was set by the autofill engine
    case autofilled
    /// Value was manually edited by the user
    case userEdited
}

// MARK: - AutoFill Rule

/// A single autofill rule in the dependency graph.
///
/// When any field in `inputs` changes, `compute` is called with current form
/// values. The engine only applies results to fields not marked as `.userEdited`.
struct AutoFillRule: Identifiable {
    let id: String
    let inputs: Set<String>
    let outputs: Set<String>
    let compute: (_ currentValues: [String: String], _ context: NSManagedObjectContext) -> [String: String]
}

// MARK: - AutoFill Engine

/// An autofill engine that tracks field sources and respects user edits.
///
/// The rule dependency graph may contain cycles (e.g. FREQ ↔ BAND).
/// The engine uses a reentrancy guard to prevent infinite loops: if a
/// trigger is already being evaluated, re-entrant calls for the same
/// trigger are silently skipped.
///
/// Guarantees:
/// 1. Fields marked `.userEdited` are never overwritten by autofill.
/// 2. Fields set by autofill are marked `.autofilled` and can be overwritten later.
/// 3. Cyclic triggers are safely broken via reentrancy guard.
class AutoFillEngine: ObservableObject {

    /// Current source of each field value.
    @Published var fieldSources: [String: FieldSource] = [:]

    /// All registered rules.
    private(set) var rules: [AutoFillRule] = []

    /// Tracks the last value set by autofill for each field.
    /// Used to distinguish engine-driven changes from user edits in SwiftUI
    /// onChange handlers (which fire asynchronously in the next render cycle,
    /// making a simple boolean flag unreliable).
    private var lastAutoFilledValues: [String: String] = [:]

    /// Reentrancy guard: tracks which triggers are currently being evaluated
    /// to break cycles (e.g. FREQ → BAND → FREQ).
    private var activeTriggers: Set<String> = []

    // MARK: - Rule registration

    func addRule(_ rule: AutoFillRule) {
        rules.append(rule)
    }

    // MARK: - Field source management

    /// Call from SwiftUI `onChange` handlers to track field changes.
    ///
    /// Compares the new value against the last autofilled value for this field.
    /// If they match, the change was engine-driven; otherwise, it's a user edit.
    /// This approach is robust across SwiftUI render cycles.
    func trackFieldChange(_ fieldId: String, newValue: String) {
        if let lastAuto = lastAutoFilledValues[fieldId], lastAuto == newValue {
            return // Value matches what autofill set → not a user edit
        }
        // Value differs from autofill (or was never autofilled) → user edit
        if !newValue.isEmpty || fieldSources[fieldId] == .autofilled {
            fieldSources[fieldId] = .userEdited
        }
    }

    /// Record that a field was autofilled with the given value.
    func recordAutoFill(_ fieldId: String, value: String) {
        lastAutoFilledValues[fieldId] = value
        fieldSources[fieldId] = .autofilled
    }

    /// Whether a field was filled by autofill (and not subsequently user-edited).
    func isAutoFilled(_ fieldId: String) -> Bool {
        fieldSources[fieldId] == .autofilled
    }

    /// Whether autofill is allowed to write to this field.
    func canAutoFill(_ fieldId: String) -> Bool {
        fieldSources[fieldId] != .userEdited
    }

    /// Reset all field sources (e.g., on form reset).
    func resetAllSources() {
        fieldSources.removeAll()
        lastAutoFilledValues.removeAll()
    }

    // MARK: - Rule evaluation

    /// Evaluate all rules triggered by a change to `trigger`.
    ///
    /// Uses a reentrancy guard: if `trigger` is already being evaluated
    /// (e.g. BAND triggers FREQ which tries to re-trigger BAND), the
    /// re-entrant call returns an empty result immediately.
    ///
    /// - Parameters:
    ///   - trigger: The field ID that changed.
    ///   - currentValues: Snapshot of all current form field values.
    ///   - context: Core Data context for history lookups.
    /// - Returns: Dictionary of field ID → new value, only for fields that
    ///   are allowed to be autofilled.
    func evaluate(
        trigger: String,
        currentValues: [String: String],
        context: NSManagedObjectContext
    ) -> [String: String] {
        // Reentrancy guard: break cycles
        guard !activeTriggers.contains(trigger) else { return [:] }
        activeTriggers.insert(trigger)
        defer { activeTriggers.remove(trigger) }

        var results: [String: String] = [:]

        for rule in rules where rule.inputs.contains(trigger) {
            let computed = rule.compute(currentValues, context)
            for (field, value) in computed {
                if canAutoFill(field) {
                    results[field] = value
                    recordAutoFill(field, value: value)
                }
            }
        }

        return results
    }

    // MARK: - Graph analysis

    /// Builds the adjacency list for the rule dependency graph.
    /// Each edge is: input field → output field (through a rule).
    func buildAdjacency() -> [String: Set<String>] {
        var adj: [String: Set<String>] = [:]
        for rule in rules {
            for input in rule.inputs {
                for output in rule.outputs {
                    adj[input, default: []].insert(output)
                }
            }
        }
        return adj
    }

    /// Detects all cycles in the rule dependency graph.
    ///
    /// Returns an array of cycles, where each cycle is an array of field IDs
    /// forming a loop. The dependency graph may legitimately contain cycles
    /// (e.g. FREQ ↔ BAND); the reentrancy guard handles them at runtime.
    func detectCycles() -> [[String]] {
        let adj = buildAdjacency()
        var cycles: [[String]] = []

        enum Color { case white, gray, black }
        var color: [String: Color] = [:]
        var path: [String] = []

        func dfs(_ node: String) {
            color[node] = .gray
            path.append(node)

            for neighbor in adj[node, default: []] {
                switch color[neighbor] ?? .white {
                case .gray:
                    // Found a cycle: extract it from the path
                    if let startIdx = path.firstIndex(of: neighbor) {
                        let cycle = Array(path[startIdx...]) + [neighbor]
                        cycles.append(cycle)
                    }
                case .white:
                    dfs(neighbor)
                case .black:
                    break
                }
            }

            path.removeLast()
            color[node] = .black
        }

        let allNodes = Set(adj.keys).union(adj.values.flatMap { $0 })
        for node in allNodes.sorted() where (color[node] ?? .white) == .white {
            dfs(node)
        }
        return cycles
    }

    /// Validates that the graph is a DAG after removing declared bidirectional
    /// edges. Use this to ensure no *unintended* cycles exist.
    ///
    /// - Parameter allowedCycles: Set of field-pair tuples (A, B) where the
    ///   A→B and B→A edges are expected bidirectional dependencies.
    /// - Returns: `true` if the remaining graph (with allowed edges removed)
    ///   has no cycles.
    func validateAcyclicExcluding(allowedEdges: Set<DirectedEdge>) -> Bool {
        var adj = buildAdjacency()

        // Remove allowed bidirectional edges
        for edge in allowedEdges {
            adj[edge.from]?.remove(edge.to)
        }

        enum Color { case white, gray, black }
        var color: [String: Color] = [:]

        func dfs(_ node: String) -> Bool {
            color[node] = .gray
            for neighbor in adj[node, default: []] {
                switch color[neighbor] ?? .white {
                case .gray:  return false
                case .black: continue
                case .white:
                    if !dfs(neighbor) { return false }
                }
            }
            color[node] = .black
            return true
        }

        let allNodes = Set(adj.keys).union(adj.values.flatMap { $0 })
        for node in allNodes where (color[node] ?? .white) == .white {
            if !dfs(node) { return false }
        }
        return true
    }

    /// All output field IDs across all rules.
    var allOutputFields: Set<String> {
        var result = Set<String>()
        for rule in rules {
            result.formUnion(rule.outputs)
        }
        return result
    }
}

// MARK: - DirectedEdge

/// A directed edge in the dependency graph.
struct DirectedEdge: Hashable {
    let from: String
    let to: String
}

// MARK: - Standard QSO Rules

extension AutoFillEngine {

    /// Creates an engine pre-loaded with the standard EasyQSO autofill rules.
    ///
    /// Dependency graph (note: FREQ ↔ BAND is a known cycle, guarded at runtime):
    /// ```
    ///   FREQ ──→ BAND          (frequency determines band)
    ///   BAND ──→ FREQ          (band loads last-used frequency)
    ///   BAND ──→ { TX_PWR, own-station-keys }
    ///   BAND ──→ { MY_CITY, MY_GRIDSQUARE, MY_CQ_ZONE, MY_ITU_ZONE }
    ///   MODE ──→ { MY_CITY, MY_GRIDSQUARE, MY_CQ_ZONE, MY_ITU_ZONE }
    /// ```
    static func standardEngine() -> AutoFillEngine {
        let engine = AutoFillEngine()

        // Rule: BAND change → autofill frequency from last QSO on that band
        engine.addRule(AutoFillRule(
            id: "band_to_frequency",
            inputs: ["BAND"],
            outputs: ["FREQ"],
            compute: { values, context in
                guard let band = values["BAND"], !band.isEmpty else { return [:] }
                if let lastFreq = QSORecord.lastFrequencyForBand(band, context: context) {
                    return ["FREQ": String(lastFreq)]
                }
                return [:]
            }
        ))

        // Rule: BAND change → autofill TX_PWR and own station keys from same-band history
        let ownStationKeys = [
            "STATION_CALLSIGN", "OPERATOR", "MY_RIG", "MY_ANTENNA",
            "MY_POTA_REF", "MY_SOTA_REF", "MY_WWFF_REF",
            "MY_SIG", "MY_SIG_INFO"
        ]
        engine.addRule(AutoFillRule(
            id: "band_to_station_info",
            inputs: ["BAND"],
            outputs: Set(["TX_PWR"] + ownStationKeys),
            compute: { values, context in
                guard let band = values["BAND"], !band.isEmpty else { return [:] }
                let request = NSFetchRequest<QSORecord>(entityName: "QSORecord")
                request.predicate = NSPredicate(format: "band == %@", band)
                request.sortDescriptors = [NSSortDescriptor(keyPath: \QSORecord.date, ascending: false)]
                request.fetchLimit = 1
                guard let record = try? context.fetch(request).first else { return [:] }

                var result: [String: String] = [:]
                if let tp = record.txPower, !tp.isEmpty {
                    result["TX_PWR"] = tp
                }
                let fields = record.adifFields
                for key in ownStationKeys {
                    if let val = fields[key], !val.isEmpty {
                        result[key] = val
                    }
                }
                return result
            }
        ))

        // Rule: BAND or MODE change → autofill own QTH from history
        let ownQTHOutputs: Set<String> = ["MY_CITY", "MY_GRIDSQUARE", "MY_CQ_ZONE", "MY_ITU_ZONE"]
        engine.addRule(AutoFillRule(
            id: "band_mode_to_own_qth",
            inputs: ["BAND", "MODE"],
            outputs: ownQTHOutputs,
            compute: { values, context in
                let band = values["BAND"] ?? ""
                let mode = values["MODE"] ?? ""
                guard !band.isEmpty else { return [:] }
                guard let qthInfo = QSORecord.lastOwnQTHInfo(band: band, mode: mode, context: context) else {
                    return [:]
                }
                var result: [String: String] = [:]
                if !qthInfo.myCity.isEmpty { result["MY_CITY"] = qthInfo.myCity }
                if !qthInfo.myGridSquare.isEmpty { result["MY_GRIDSQUARE"] = qthInfo.myGridSquare }
                if !qthInfo.myCQZone.isEmpty { result["MY_CQ_ZONE"] = qthInfo.myCQZone }
                if !qthInfo.myITUZone.isEmpty { result["MY_ITU_ZONE"] = qthInfo.myITUZone }
                return result
            }
        ))

        return engine
    }

    /// The known bidirectional edges in the standard QSO rules.
    /// FREQ ↔ BAND: frequency determines band, band loads last-used frequency.
    static var knownBidirectionalEdges: Set<DirectedEdge> {
        [
            DirectedEdge(from: "BAND", to: "FREQ"),
            DirectedEdge(from: "FREQ", to: "BAND"),
        ]
    }
}
