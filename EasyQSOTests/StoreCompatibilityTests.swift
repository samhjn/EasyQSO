import XCTest
import CoreData
@testable import EasyQSO

final class StoreCompatibilityTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - checkStoreFileReadable

    func testCheckStoreFileReadable_NoFile_ReturnsNil() {
        let nonexistentURL = tempDir.appendingPathComponent("does_not_exist.sqlite")
        let result = StoreCompatibilityCheck.checkStoreFileReadable(storeURL: nonexistentURL)
        XCTAssertNil(result, "Should return nil when store file doesn't exist (fresh install)")
    }

    func testCheckStoreFileReadable_ValidFile_ReturnsNil() {
        let storeURL = tempDir.appendingPathComponent("valid.sqlite")
        createValidStore(at: storeURL, model: EasyQSOModel.shared)

        let result = StoreCompatibilityCheck.checkStoreFileReadable(storeURL: storeURL)
        XCTAssertNil(result, "Should return nil when store file is readable")
    }

    func testCheckStoreFileReadable_CorruptedFile_ReturnsError() {
        let storeURL = tempDir.appendingPathComponent("corrupted.sqlite")
        try! Data("not a sqlite file".utf8).write(to: storeURL)

        let result = StoreCompatibilityCheck.checkStoreFileReadable(storeURL: storeURL)
        XCTAssertNotNil(result, "Should return error for corrupted store file")

        if case .storeFileError = result! {
            // Expected
        } else {
            XCTFail("Expected storeFileError, got \(result!)")
        }
    }

    // MARK: - diagnoseLoadFailure

    func testDiagnoseLoadFailure_IncompatibleSchema() {
        let storeURL = tempDir.appendingPathComponent("old_schema.sqlite")

        // Create store with an incompatible model (same entity, different attribute type)
        let oldModel = createIncompatibleModel()
        createValidStore(at: storeURL, model: oldModel)

        let dummyError = NSError(domain: "CoreData", code: 134130, userInfo: nil)
        let result = StoreCompatibilityCheck.diagnoseLoadFailure(
            loadError: dummyError,
            model: EasyQSOModel.shared,
            storeURL: storeURL
        )

        if case .incompatibleSchema(let url) = result {
            XCTAssertEqual(url, storeURL)
        } else {
            XCTFail("Expected incompatibleSchema, got \(result)")
        }
    }

    func testDiagnoseLoadFailure_NoStoreFile() {
        let storeURL = tempDir.appendingPathComponent("missing.sqlite")
        let dummyError = NSError(domain: "CoreData", code: 1, userInfo: nil)

        let result = StoreCompatibilityCheck.diagnoseLoadFailure(
            loadError: dummyError,
            model: EasyQSOModel.shared,
            storeURL: storeURL
        )

        if case .loadFailed = result {
            // Expected
        } else {
            XCTFail("Expected loadFailed, got \(result)")
        }
    }

    func testDiagnoseLoadFailure_CompatibleStore() {
        let storeURL = tempDir.appendingPathComponent("compatible.sqlite")
        createValidStore(at: storeURL, model: EasyQSOModel.shared)

        let dummyError = NSError(domain: "CoreData", code: 1, userInfo: nil)
        let result = StoreCompatibilityCheck.diagnoseLoadFailure(
            loadError: dummyError,
            model: EasyQSOModel.shared,
            storeURL: storeURL
        )

        // Store is compatible, so error is generic loadFailed
        if case .loadFailed = result {
            // Expected
        } else {
            XCTFail("Expected loadFailed for compatible store, got \(result)")
        }
    }

    // MARK: - StoreLoadState Properties

    func testStoreLoadState_IsReady() {
        XCTAssertTrue(StoreLoadState.ready.isReady)
        XCTAssertFalse(StoreLoadState.loadFailed("err").isReady)
        XCTAssertFalse(StoreLoadState.storeFileError("err").isReady)

        let url = URL(fileURLWithPath: "/tmp/test.sqlite")
        XCTAssertFalse(StoreLoadState.incompatibleSchema(storeURL: url).isReady)
    }

    func testStoreLoadState_HasMeaningfulDescriptions() {
        let url = URL(fileURLWithPath: "/tmp/test.sqlite")

        let states: [StoreLoadState] = [
            .incompatibleSchema(storeURL: url),
            .storeFileError("test detail"),
            .loadFailed("test detail"),
        ]

        for state in states {
            XCTAssertFalse(state.title.isEmpty, "Title should not be empty for \(state)")
            XCTAssertFalse(state.localizedDescription.isEmpty, "Description should not be empty for \(state)")
        }

        XCTAssertTrue(StoreLoadState.ready.title.isEmpty)
        XCTAssertTrue(StoreLoadState.ready.localizedDescription.isEmpty)
    }

    // MARK: - Integration: Incompatible store should not crash

    func testIncompatibleStoreDoesNotCrash() {
        let storeURL = tempDir.appendingPathComponent("incompat_integration.sqlite")

        // Create a store with an incompatible model:
        // Same entity name "QSORecord" but callsign is Int64 instead of String.
        // Lightweight migration cannot handle attribute type changes,
        // so this guarantees a load failure.
        let oldModel = createIncompatibleModel()
        createValidStore(at: storeURL, model: oldModel)

        // Now try to load with the current model + lightweight migration
        let container = NSPersistentContainer(
            name: "IncompatTest",
            managedObjectModel: EasyQSOModel.shared
        )
        let description = NSPersistentStoreDescription(url: storeURL)
        description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }

        // The load should fail (incompatible schema) but NOT crash
        XCTAssertNotNil(loadError, "Loading incompatible store should produce an error, not crash")

        guard let error = loadError else { return }

        // Diagnose should identify it as incompatible
        let state = StoreCompatibilityCheck.diagnoseLoadFailure(
            loadError: error,
            model: EasyQSOModel.shared,
            storeURL: storeURL
        )

        if case .incompatibleSchema = state {
            // Expected - incompatibility detected and handled gracefully
        } else {
            XCTFail("Expected incompatibleSchema diagnosis, got \(state)")
        }
    }

    // MARK: - Helpers

    /// Creates a valid SQLite store at the given URL using the provided model
    private func createValidStore(at url: URL, model: NSManagedObjectModel) {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        do {
            try coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: url,
                options: nil
            )
        } catch {
            XCTFail("Failed to create test store: \(error)")
        }
    }

    /// Creates a model that is incompatible with the current EasyQSOModel.
    ///
    /// Uses the same entity name "QSORecord" but changes `callsign` from
    /// String to Int64. Lightweight migration cannot handle type changes,
    /// so this guarantees an incompatibility that cannot be auto-resolved.
    private func createIncompatibleModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = "QSORecord"
        entity.managedObjectClassName = NSManagedObject.self.description()

        // callsign as Int64 (real model uses String) — type change is not migratable
        let callsignAttr = NSAttributeDescription()
        callsignAttr.name = "callsign"
        callsignAttr.attributeType = .integer64AttributeType
        callsignAttr.isOptional = false
        callsignAttr.defaultValue = 0

        // date as String (real model uses Date) — another type mismatch
        let dateAttr = NSAttributeDescription()
        dateAttr.name = "date"
        dateAttr.attributeType = .stringAttributeType
        dateAttr.isOptional = false
        dateAttr.defaultValue = ""

        entity.properties = [callsignAttr, dateAttr]
        model.entities = [entity]
        return model
    }
}
