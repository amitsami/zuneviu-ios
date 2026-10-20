#if DEBUG
import Foundation

enum DebugFixture {
    @MainActor static func makeLibrary() -> LibraryStore {
        // Used only by explicit automated-test launches; never touches the real library.
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Zuneviu-UITest-Library", isDirectory: true)
        try? FileManager.default.removeItem(at: root)
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            guard let source = Bundle.main.url(forResource: "TestTone", withExtension: "wav") else { fatalError("UI test fixture is missing") }
            try FileManager.default.copyItem(at: source, to: root.appendingPathComponent("test.wav"))
            let track = Track(id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!, title: "Test Tone", artist: "Generated test fixture", album: "Validation", audioFile: "test.wav", duration: 8, importedAt: Date(timeIntervalSince1970: 0))
            let snapshot = LibrarySnapshot(tracks: [track])
            try JSONEncoder().encode(snapshot).write(to: root.appendingPathComponent("library.json"))
            UserDefaults.standard.set(true, forKey: "hasSeenPortNotice")
            return LibraryStore(root: root)
        } catch { fatalError("Cannot prepare UI test library: \(error)") }
    }
}
#endif
