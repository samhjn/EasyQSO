import XCTest
import Combine
@testable import EasyQSO

final class FieldVisibilityStatsTests: XCTestCase {

    private var cancellables: Set<AnyCancellable> = []

    override func setUp() {
        super.setUp()
        FieldVisibilityManager.shared.resetToDefaults()
    }

    override func tearDown() {
        FieldVisibilityManager.shared.resetToDefaults()
        cancellables.removeAll()
        super.tearDown()
    }

    // MARK: - Revision increment tests

    func testRevisionIncrementsOnSetVisibility() {
        let manager = FieldVisibilityManager.shared
        let initialRevision = manager.revision

        // Find a non-required, non-grouped field to modify
        guard let field = findModifiableField() else {
            XCTFail("No modifiable field found")
            return
        }

        manager.setVisibility(.hidden, for: field.id)
        XCTAssertGreaterThan(manager.revision, initialRevision,
                             "revision should increment after setVisibility")
    }

    func testRevisionIncrementsOnSetGroupVisibility() {
        let manager = FieldVisibilityManager.shared
        let initialRevision = manager.revision

        guard let group = ADIFFields.fieldGroups.first(where: { $0.allowedVisibilities.count > 1 }) else {
            XCTFail("No modifiable group found")
            return
        }

        let newVis = group.allowedVisibilities.first(where: { $0 != manager.groupVisibility(for: group.id) })
            ?? group.allowedVisibilities[0]
        manager.setGroupVisibility(newVis, for: group.id)
        XCTAssertGreaterThan(manager.revision, initialRevision,
                             "revision should increment after setGroupVisibility")
    }

    func testRevisionIncrementsOnResetToDefaults() {
        let manager = FieldVisibilityManager.shared

        // Make a change first so there's something to reset
        if let field = findModifiableField() {
            manager.setVisibility(.hidden, for: field.id)
        }
        let revisionBeforeReset = manager.revision

        manager.resetToDefaults()
        XCTAssertGreaterThan(manager.revision, revisionBeforeReset,
                             "revision should increment after resetToDefaults")
    }

    // MARK: - objectWillChange tests

    func testObjectWillChangeFiresOnSetVisibility() {
        let manager = FieldVisibilityManager.shared
        let expectation = expectation(description: "objectWillChange should fire")

        guard let field = findModifiableField() else {
            XCTFail("No modifiable field found")
            return
        }

        manager.objectWillChange
            .first()
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)

        manager.setVisibility(.hidden, for: field.id)
        waitForExpectations(timeout: 1)
    }

    func testObjectWillChangeFiresOnSetGroupVisibility() {
        let manager = FieldVisibilityManager.shared
        let expectation = expectation(description: "objectWillChange should fire")

        guard let group = ADIFFields.fieldGroups.first(where: { $0.allowedVisibilities.count > 1 }) else {
            XCTFail("No modifiable group found")
            return
        }

        manager.objectWillChange
            .first()
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)

        let newVis = group.allowedVisibilities.first(where: { $0 != manager.groupVisibility(for: group.id) })
            ?? group.allowedVisibilities[0]
        manager.setGroupVisibility(newVis, for: group.id)
        waitForExpectations(timeout: 1)
    }

    func testObjectWillChangeFiresOnResetToDefaults() {
        let manager = FieldVisibilityManager.shared
        let expectation = expectation(description: "objectWillChange should fire")

        manager.objectWillChange
            .first()
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)

        manager.resetToDefaults()
        waitForExpectations(timeout: 1)
    }

    // MARK: - Stats accuracy tests

    func testStatsReflectVisibilityChange() {
        let manager = FieldVisibilityManager.shared

        guard let field = findModifiableField() else {
            XCTFail("No modifiable field found")
            return
        }

        // Record initial stats
        let initialStats = computeStats(using: manager)
        let wasVisible = manager.visibility(for: field.id) == .visible

        // Change field to hidden
        manager.setVisibility(.hidden, for: field.id)
        let statsAfterHide = computeStats(using: manager)

        if wasVisible {
            XCTAssertEqual(statsAfterHide.visible, initialStats.visible - 1,
                           "visible count should decrease by 1")
            XCTAssertEqual(statsAfterHide.hidden, initialStats.hidden + 1,
                           "hidden count should increase by 1")
        }

        // Change field to visible
        manager.setVisibility(.visible, for: field.id)
        let statsAfterShow = computeStats(using: manager)
        XCTAssertEqual(statsAfterShow.visible, statsAfterHide.visible + 1,
                       "visible count should increase by 1 after making visible")
        XCTAssertEqual(statsAfterShow.hidden, statsAfterHide.hidden - 1,
                       "hidden count should decrease by 1 after making visible")
    }

    func testStatsReflectCollapsedChange() {
        let manager = FieldVisibilityManager.shared

        guard let field = findModifiableField() else {
            XCTFail("No modifiable field found")
            return
        }

        manager.setVisibility(.visible, for: field.id)
        let before = computeStats(using: manager)

        manager.setVisibility(.collapsed, for: field.id)
        let after = computeStats(using: manager)

        XCTAssertEqual(after.visible, before.visible - 1)
        XCTAssertEqual(after.collapsed, before.collapsed + 1)
    }

    func testStatsTotalIsConstant() {
        let manager = FieldVisibilityManager.shared
        let total = ADIFFields.all.count

        let stats1 = computeStats(using: manager)
        XCTAssertEqual(stats1.visible + stats1.collapsed + stats1.hidden, total,
                       "total should equal ADIFFields.all.count")

        // Change some fields and verify total stays the same
        if let field = findModifiableField() {
            manager.setVisibility(.hidden, for: field.id)
            let stats2 = computeStats(using: manager)
            XCTAssertEqual(stats2.visible + stats2.collapsed + stats2.hidden, total,
                           "total should remain constant after changes")
        }
    }

    // MARK: - fieldSettingsSummary format test

    func testFieldSettingsSummaryFormat() {
        let manager = FieldVisibilityManager.shared
        let stats = computeStats(using: manager)
        let expected = "\(stats.visible)/\(ADIFFields.all.count)"

        // Replicate the logic from SettingsView.fieldSettingsSummary
        var visible = 0
        for field in ADIFFields.all {
            if manager.visibility(for: field.id) == .visible { visible += 1 }
        }
        let summary = "\(visible)/\(ADIFFields.all.count)"

        XCTAssertEqual(summary, expected)
    }

    // MARK: - Helpers

    private func findModifiableField() -> ADIFFieldDef? {
        ADIFFields.all.first { field in
            !field.isRequired && !ADIFFields.groupedFieldIds.contains(field.id)
        }
    }

    private func computeStats(using manager: FieldVisibilityManager) -> (visible: Int, collapsed: Int, hidden: Int) {
        var v = 0, c = 0, h = 0
        for field in ADIFFields.all {
            switch manager.visibility(for: field.id) {
            case .visible: v += 1
            case .collapsed: c += 1
            case .hidden: h += 1
            }
        }
        return (v, c, h)
    }
}
